# 1. Start the performance benchmark stopwatch
$pipelineStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$buildTag = "local-" + (Get-Date -Format "yyyyMMdd-HHmmss")

Write-Output "--------------------------------------------------"
$customMessage = Read-Host "Enter your commit/deployment message"
Write-Output "--------------------------------------------------"

if ([string]::IsNullOrWhiteSpace($customMessage)) {
    $customMessage = "ci: instant docker helm kubernetes rollout"
}

$dockerImage = "sujeymcw/expo-web-app"
$helmRelease = "expo-web-release"
$helmChartPath = "./charts/my-web-app"
$namespace = "default"
$helmReportFile = "./helm-deployment-report.txt"
$renderedManifestFile = "./rendered-manifest.yaml"

function Send-SlackMessage([string]$messageText) {
    if (Test-Path "./webhook.json") {
        $settings = Get-Content "./webhook.json" | ConvertFrom-Json
        $slackWebhookUrl = $settings.SLACK_WEBHOOK_URL.Trim()

        $bodyObject = @{
            text = $messageText
        }

        $jsonBody = $bodyObject | ConvertTo-Json -Compress

        Invoke-RestMethod `
            -Uri $slackWebhookUrl `
            -Method Post `
            -Body $jsonBody `
            -ContentType "application/json; charset=utf-8"
    }
}

function Clear-Port8000 {
    Write-Output "PERFORMING HARD SCRUB ON PORT 8000..."

    try {
        $connections = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue

        if ($connections) {
            $processIds = $connections | Select-Object -ExpandProperty OwningProcess -Unique

            foreach ($processId in $processIds) {
                if ($processId -and $processId -ne $PID) {
                    Write-Host "Killing process using port 8000: PID $processId" -ForegroundColor Yellow
                    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
                }
            }
        }

        Start-Sleep -Seconds 2
        Write-Host "Port 8000 cleanup completed." -ForegroundColor Green
    } catch {
        Write-Host "Socket release sweep finished..." -ForegroundColor Yellow
    }
}

function Get-FreeExpoPort {
    $preferredPorts = @(8081, 8082, 8083, 8084, 8085, 8090, 8091, 8092, 19000, 19001, 19002)

    foreach ($expoPort in $preferredPorts) {
        $portUsed = Get-NetTCPConnection -LocalPort $expoPort -ErrorAction SilentlyContinue
        if (-not $portUsed) {
            return $expoPort
        }
    }

    return 8099
}

$expoPort = Get-FreeExpoPort

function Send-SlackFailure([string]$stageName, [string]$errorDetails) {
    $failPayload = "*=== KUBERNETES DEPLOYMENT CRITICAL FAILURE ===*" + "`n`n" +
                   "*Broken Stage:* " + $stageName + "`n" +
                   "*Error Context:* " + $errorDetails + "`n" +
                   "--------------------------------------------------" + "`n" +
                   "_Execution halted instantly to protect active cluster node stability._"

    try {
        Send-SlackMessage $failPayload
    } catch {
        Write-Host "Slack failure alert could not be sent: $_" -ForegroundColor Yellow
    }

    Write-Error "CRITICAL: Pipeline halted during execution at $stageName."

    Write-Output "LAUNCHING EXPO MOBILE INTERFACE CONSOLE IN SEPARATE POWERSHELL..."
    Start-Process powershell.exe -ArgumentList @(
        "-NoExit",
        "-Command",
        "Clear-Host; Set-Location '$PSScriptRoot\src'; Write-Host 'LAUNCHING EXPO MOBILE FRONTEND INTERFACE ON PORT $expoPort...' -ForegroundColor Blue; npx expo start -w --port $expoPort --non-interactive"
    )

    Exit
}

function Ensure-MetricsServer {
    Write-Host ""
    Write-Host "PRE-FLIGHT: ENABLING KUBERNETES METRICS SERVER FIRST..." -ForegroundColor Cyan

    kubectl top nodes *> $null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Metrics Server already active." -ForegroundColor Green
        return
    }

    Write-Host "Metrics Server not detected. Enabling automatically..." -ForegroundColor Yellow
    minikube addons enable metrics-server

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to enable metrics-server addon. Continuing deployment." -ForegroundColor Red
        return
    }

    Write-Host "Waiting for Metrics Server rollout..." -ForegroundColor Yellow
    kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s *> $null

    for ($i = 1; $i -le 30; $i++) {
        kubectl top nodes *> $null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Metrics Server successfully activated." -ForegroundColor Green
            return
        }

        Write-Host "Waiting for Metrics API... ($i/30)" -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }

    Write-Host "Metrics Server enabled, but API is still warming up." -ForegroundColor Yellow
}

function Write-DevOpsHelmReport {
    param (
        [string]$ImageName,
        [string]$ImageTag
    )

    Write-Host ""
    Write-Host "GENERATING REAL DEVOPS HELM REPORT..." -ForegroundColor Cyan

    helm template $helmRelease $helmChartPath `
        --set image.repository="$ImageName" `
        --set image.tag="$ImageTag" `
        --set image.imagePullPolicy="IfNotPresent" `
        --set service.type="LoadBalancer" `
        --set service.port=80 `
        --namespace $namespace > $renderedManifestFile

@"
============================================================
REAL DEVOPS HELM DEPLOYMENT REPORT
============================================================

Generated At       : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Namespace          : $namespace
Helm Release       : $helmRelease
Helm Chart Path    : $helmChartPath
Docker Image       : ${ImageName}:${ImageTag}
Rendered Manifest  : $renderedManifestFile

============================================================
WORKFLOW
============================================================

Git Push
   ↓
Build Image
   ↓
Push Registry
   ↓
Helm Upgrade
   ↓
Kubernetes Deployment

============================================================
HELM LIST
============================================================

"@ | Set-Content $helmReportFile -Encoding UTF8

    helm list --namespace $namespace | Out-File $helmReportFile -Append -Encoding UTF8

@"

============================================================
HELM STATUS
============================================================

"@ | Out-File $helmReportFile -Append -Encoding UTF8

    helm status $helmRelease --namespace $namespace | Out-File $helmReportFile -Append -Encoding UTF8

@"

============================================================
HELM VALUES
============================================================

"@ | Out-File $helmReportFile -Append -Encoding UTF8

    helm get values $helmRelease --namespace $namespace | Out-File $helmReportFile -Append -Encoding UTF8

@"

============================================================
HELM MANIFEST
============================================================

"@ | Out-File $helmReportFile -Append -Encoding UTF8

    helm get manifest $helmRelease --namespace $namespace | Out-File $helmReportFile -Append -Encoding UTF8

@"

============================================================
HELM ALL
============================================================

"@ | Out-File $helmReportFile -Append -Encoding UTF8

    helm get all $helmRelease --namespace $namespace | Out-File $helmReportFile -Append -Encoding UTF8

@"

============================================================
KUBERNETES DEPLOYMENT
============================================================

"@ | Out-File $helmReportFile -Append -Encoding UTF8

    kubectl get deployment expo-web-deployment --namespace $namespace -o wide | Out-File $helmReportFile -Append -Encoding UTF8

@"

============================================================
KUBERNETES PODS
============================================================

"@ | Out-File $helmReportFile -Append -Encoding UTF8

    kubectl get pods --namespace $namespace -o wide | Out-File $helmReportFile -Append -Encoding UTF8

@"

============================================================
KUBERNETES SERVICES
============================================================

"@ | Out-File $helmReportFile -Append -Encoding UTF8

    kubectl get svc --namespace $namespace -o wide | Out-File $helmReportFile -Append -Encoding UTF8

@"

============================================================
KUBERNETES ROLLOUT STATUS
============================================================

"@ | Out-File $helmReportFile -Append -Encoding UTF8

    kubectl rollout status deployment/expo-web-deployment --namespace $namespace | Out-File $helmReportFile -Append -Encoding UTF8

@"

============================================================
POD CPU AND MEMORY METRICS
============================================================

"@ | Out-File $helmReportFile -Append -Encoding UTF8

    kubectl top pods --namespace $namespace | Out-File $helmReportFile -Append -Encoding UTF8

@"

============================================================
NODE CPU AND MEMORY METRICS
============================================================

"@ | Out-File $helmReportFile -Append -Encoding UTF8

    kubectl top nodes | Out-File $helmReportFile -Append -Encoding UTF8

    Write-Host "DevOps Helm report generated successfully:" -ForegroundColor Green
    Write-Host $helmReportFile -ForegroundColor Cyan

    Write-Host "Rendered Kubernetes manifest generated:" -ForegroundColor Green
    Write-Host $renderedManifestFile -ForegroundColor Cyan
}

function Show-DevOpsHelmOutput {
    param (
        [string]$ImageName,
        [string]$ImageTag
    )

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "REAL DEVOPS HELM CHART DEPLOYMENT OUTPUT" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "Docker Image       : ${ImageName}:${ImageTag}" -ForegroundColor Green
    Write-Host "Helm Release       : $helmRelease" -ForegroundColor Green
    Write-Host "Namespace          : $namespace" -ForegroundColor Green
    Write-Host "Helm Report File   : $helmReportFile" -ForegroundColor Green
    Write-Host "Rendered Manifest  : $renderedManifestFile" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "HELM LIST:" -ForegroundColor Yellow
    helm list --namespace $namespace

    Write-Host ""
    Write-Host "HELM STATUS:" -ForegroundColor Yellow
    helm status $helmRelease --namespace $namespace

    Write-Host ""
    Write-Host "HELM VALUES:" -ForegroundColor Yellow
    helm get values $helmRelease --namespace $namespace

    Write-Host ""
    Write-Host "KUBERNETES DEPLOYMENT:" -ForegroundColor Yellow
    kubectl get deployment expo-web-deployment --namespace $namespace -o wide

    Write-Host ""
    Write-Host "KUBERNETES PODS:" -ForegroundColor Yellow
    kubectl get pods --namespace $namespace -o wide

    Write-Host ""
    Write-Host "KUBERNETES SERVICES:" -ForegroundColor Yellow
    kubectl get svc --namespace $namespace -o wide

    Write-Host ""
    Write-Host "KUBERNETES ROLLOUT STATUS:" -ForegroundColor Yellow
    kubectl rollout status deployment/expo-web-deployment --namespace $namespace

    Write-Host ""
    Write-Host "POD CPU AND MEMORY METRICS:" -ForegroundColor Yellow
    kubectl top pods --namespace $namespace

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "Metrics still warming up. Showing deployment resource requests and limits:" -ForegroundColor Yellow
        kubectl describe deployment expo-web-deployment --namespace $namespace | Select-String "Limits|Requests|cpu|memory"
    }

    Write-Host ""
    Write-Host "NODE CPU AND MEMORY METRICS:" -ForegroundColor Yellow
    kubectl top nodes

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
}

Write-Output "PERFORMING HARD SCRUB ON PORT 8000 AND LAUNCHING BACKEND..."
Clear-Port8000

Start-Process powershell.exe -ArgumentList @(
    "-NoExit",
    "-Command",
    "Clear-Host; Set-Location '$PSScriptRoot'; Write-Host 'LAUNCHING CONTROL PLANE BACKEND BRIDGE ENGINE...' -ForegroundColor Cyan; python dashboard_backend.py"
)

Write-Output "Waiting 5 seconds for backend API server to bind cleanly to port 8000..."
Start-Sleep -Seconds 5

Write-Output ""
Write-Output "STARTING INSTANT GITOPS PIPELINE ROLLOUT..."
Write-Output "PRE-FLIGHT: Metrics Server will be enabled before final output."
Ensure-MetricsServer

Write-Output ""
Write-Output "WORKFLOW:"
Write-Output "Git Push"
Write-Output "   ↓"
Write-Output "Build Image"
Write-Output "   ↓"
Write-Output "Push Registry"
Write-Output "   ↓"
Write-Output "Helm Upgrade"
Write-Output "   ↓"
Write-Output "Kubernetes Deployment"
Write-Output ""

Write-Output "STAGE 1 OF 5: Syncing source files with Git Repository..."
git add .

git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "No new source changes detected. Skipping git commit..." -ForegroundColor Yellow
} else {
    git commit -m "$customMessage" --quiet

    if ($LASTEXITCODE -ne 0) {
        Send-SlackFailure "STAGE 1 (Git Commit)" "Git commit failed."
    }
}

git push origin main --quiet

if ($LASTEXITCODE -ne 0) {
    Send-SlackFailure "STAGE 1 (Git Push)" "Repository push rejected or upstream remote server unavailable."
}

Write-Output "STAGE 2 OF 5: Building Docker image immediately with cache acceleration..."

try {
    $disruptCheck = Invoke-RestMethod -Uri "http://127.0.0.1:8000/api/metrics" -Method Get -TimeoutSec 2

    if ($disruptCheck.chaosSimulationActive -eq $true -or $disruptCheck.disrupted -eq $true) {
        Write-Host ""
        Write-Host "!!! CHAOS INTERACTION DETECTED: Simulating Broken Docker Compilation !!!" -ForegroundColor Red
        Send-SlackFailure "STAGE 2 (Docker Build)" "Compilation failed inside the Dockerfile environment layers due to an armed infrastructure disruption."
    }
} catch {
    Write-Host "Metrics API bridge offline, proceeding with standard Docker verification loop..." -ForegroundColor Yellow
}

docker build `
    -f ./Dockerfile `
    -t "${dockerImage}:$buildTag" `
    --pull=false `
    --quiet `
    .

if ($LASTEXITCODE -ne 0) {
    Send-SlackFailure "STAGE 2 (Docker Build)" "Docker image build failed."
}

Write-Host "Docker Image Generated Successfully: ${dockerImage}:$buildTag" -ForegroundColor Green

Write-Output "STAGE 3 OF 5: Pushing Docker image to registry..."
docker push "${dockerImage}:$buildTag"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker registry push failed. Loading image into Minikube as fallback..." -ForegroundColor Yellow
    minikube image load "${dockerImage}:$buildTag"

    if ($LASTEXITCODE -ne 0) {
        Send-SlackFailure "STAGE 3 (Docker Push / Minikube Load)" "Image push failed and Minikube fallback load also failed."
    }
}

Write-Output "STAGE 4 OF 5: Running Helm Upgrade and Kubernetes deployment..."

helm upgrade --install $helmRelease $helmChartPath `
    --set image.repository="$dockerImage" `
    --set image.tag="$buildTag" `
    --set image.imagePullPolicy="IfNotPresent" `
    --set service.type="LoadBalancer" `
    --set service.port=80 `
    --namespace $namespace `
    --create-namespace

if ($LASTEXITCODE -ne 0) {
    Send-SlackFailure "STAGE 4 (Helm Upgrade)" "Helm manifest configuration parsing rejected by the target cluster."
}

kubectl rollout restart deployment/expo-web-deployment --namespace $namespace

if ($LASTEXITCODE -ne 0) {
    Write-Host "Rollout restart skipped. Helm upgrade may have already triggered a pod update." -ForegroundColor Yellow
}

kubectl rollout status deployment/expo-web-deployment --namespace $namespace --timeout=180s

if ($LASTEXITCODE -ne 0) {
    Send-SlackFailure "STAGE 4 (Kubernetes Rollout)" "Deployment did not become ready within timeout."
}

Write-Output "STAGE 5 OF 5: Showing real DevOps Helm chart output..."

Write-DevOpsHelmReport -ImageName $dockerImage -ImageTag $buildTag
Show-DevOpsHelmOutput -ImageName $dockerImage -ImageTag $buildTag

Start-Process powershell.exe -ArgumentList @(
    "-NoExit",
    "-Command",
    "Clear-Host; Set-Location '$PSScriptRoot'; Write-Host 'REAL DEVOPS HELM DEPLOYMENT OUTPUT' -ForegroundColor Cyan; Write-Host ''; Write-Host 'HELM LIST:' -ForegroundColor Yellow; helm list --namespace $namespace; Write-Host ''; Write-Host 'HELM STATUS:' -ForegroundColor Yellow; helm status $helmRelease --namespace $namespace; Write-Host ''; Write-Host 'HELM VALUES:' -ForegroundColor Yellow; helm get values $helmRelease --namespace $namespace; Write-Host ''; Write-Host 'KUBERNETES PODS:' -ForegroundColor Yellow; kubectl get pods --namespace $namespace -o wide; Write-Host ''; Write-Host 'KUBERNETES SERVICES:' -ForegroundColor Yellow; kubectl get svc --namespace $namespace -o wide; Write-Host ''; Write-Host 'POD CPU AND MEMORY METRICS:' -ForegroundColor Yellow; kubectl top pods --namespace $namespace; Write-Host ''; Write-Host 'NODE CPU AND MEMORY METRICS:' -ForegroundColor Yellow; kubectl top nodes; Write-Host ''; Write-Host 'FULL HELM REPORT FILE:' -ForegroundColor Green; Write-Host '$helmReportFile'; Write-Host ''; Write-Host 'RENDERED MANIFEST FILE:' -ForegroundColor Green; Write-Host '$renderedManifestFile'"
)

Write-Output "RUNNING OPERATIONAL ENVIRONMENT HEALTH CHECK..."
Start-Sleep -Seconds 3

$portCheck = Test-NetConnection -ComputerName "localhost" -Port 80 -WarningAction SilentlyContinue

if ($portCheck.TcpTestSucceeded) {
    $healthStatus = "PASSED (Port 80 responding cleanly)"
} else {
    $healthStatus = "WARNING (Port 80 not responding yet)"
}

$runningPods = kubectl get pods --namespace $namespace --no-headers 2>$null | Select-String "Running"
$podCount = @($runningPods).Count

$pipelineStopwatch.Stop()
$executionDuration = [math]::Round($pipelineStopwatch.Elapsed.TotalSeconds, 2)
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

Write-Output "DISPATCHING INSTANT TELEMETRY ALERT TO SLACK..."

$textPayload = "*=== KUBERNETES DEPLOYMENT ROLLOUT SUCCESSFUL ===*" + "`n`n" +
               "*Deployment Status:* Active & Rolling" + "`n" +
               "*Docker Image Generated:* " + "${dockerImage}:$buildTag" + "`n" +
               "*Cluster Health Check:* " + $healthStatus + "`n" +
               "*Running Pods:* " + $podCount + "`n" +
               "*Helm Report File:* " + $helmReportFile + "`n" +
               "*Rendered Manifest File:* " + $renderedManifestFile + "`n" +
               "*Memory/CPU Usage:* Check DevOps Helm terminal" + "`n" +
               "*Total Processing Velocity:* " + $executionDuration + " seconds" + "`n" +
               "*Local Endpoint URL:* http://localhost" + "`n" +
               "*Expo Frontend Port:* " + $expoPort + "`n`n" +
               "--------------------------------------------------" + "`n" +
               "*PIPELINE METRICS LOGS*" + "`n" +
               "> *Operator:* Sujey Hariprasad" + "`n" +
               "> *Cluster Environment:* Local Desktop Node (default)" + "`n" +
               "> *Helm Chart Release:* " + $helmRelease + "`n" +
               "> *Unique Build Tag:* " + $buildTag + "`n" +
               "> *Git Sync Message:* " + $customMessage + "`n" +
               "--------------------------------------------------" + "`n`n" +
               "_Telemetry Sync Complete: " + $timestamp + "_"

try {
    Send-SlackMessage $textPayload
} catch {
    Write-Error "Slack API failed: $_"
}

Write-Output ""
Write-Output "SUCCESS: Git push completed, Docker image created, registry/minikube image updated, Helm upgraded, and Kubernetes deployed."
Write-Output "Docker Image Generated: ${dockerImage}:$buildTag"
Write-Output "Running Pods: $podCount"
Write-Output "Full Helm Report: $helmReportFile"
Write-Output "Rendered Manifest: $renderedManifestFile"
Write-Output "Total pipeline execution velocity: $executionDuration seconds."
Write-Output "--------------------------------------------------"

Write-Output "LAUNCHING EXPO MOBILE INTERFACE CONSOLE IN SEPARATE POWERSHELL..."

Start-Process powershell.exe -ArgumentList @(
    "-NoExit",
    "-Command",
    "Clear-Host; Set-Location '$PSScriptRoot\src'; Write-Host 'LAUNCHING FRONTEND INTERFACE ON PORT $expoPort...' -ForegroundColor Blue; npx expo start -w --port $expoPort --non-interactive"
)