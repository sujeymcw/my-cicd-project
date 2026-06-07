# 1. Start the performance benchmark stopwatch to calculate execution velocity
$pipelineStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$buildTag = "local-" + (Get-Date -Format "yyyyMMdd-HHmmss")

Write-Output "--------------------------------------------------"
$customMessage = Read-Host "Enter your commit/deployment message"
Write-Output "--------------------------------------------------"

if ([string]::IsNullOrWhiteSpace($customMessage)) {
    $customMessage = "style: rapid telemetry interface deployment sync"
}

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

        $stillUsed = Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue
        if ($stillUsed) {
            Write-Host "Port 8000 still busy. Retrying hard kill..." -ForegroundColor Red

            $retryProcessIds = $stillUsed | Select-Object -ExpandProperty OwningProcess -Unique
            foreach ($retryId in $retryProcessIds) {
                if ($retryId -and $retryId -ne $PID) {
                    Stop-Process -Id $retryId -Force -ErrorAction SilentlyContinue
                }
            }

            Start-Sleep -Seconds 2
        }

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

function Show-KubernetesTelemetry {
    param (
        [string]$ImageName,
        [string]$ImageTag
    )

    Write-Host ""
    Write-Host "================ HELM + KUBERNETES LIVE OUTPUT ================" -ForegroundColor Cyan
    Write-Host "Docker Image Generated : ${ImageName}:${ImageTag}" -ForegroundColor Green
    Write-Host "Helm Release           : expo-web-release" -ForegroundColor Green
    Write-Host "Namespace              : default" -ForegroundColor Green
    Write-Host "===============================================================" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "HELM RELEASE STATUS:" -ForegroundColor Yellow
    helm status expo-web-release --namespace default

    Write-Host ""
    Write-Host "HELM VALUES IMAGE CONFIG:" -ForegroundColor Yellow
    helm get values expo-web-release --namespace default

    Write-Host ""
    Write-Host "DEPLOYED DOCKER IMAGE INSIDE KUBERNETES:" -ForegroundColor Yellow
    kubectl get deployment expo-web-deployment --namespace default -o=jsonpath="{.spec.template.spec.containers[*].image}"
    Write-Host ""

    Write-Host ""
    Write-Host "KUBERNETES DEPLOYMENT STATUS:" -ForegroundColor Yellow
    kubectl get deployment expo-web-deployment --namespace default -o wide

    Write-Host ""
    Write-Host "PODS CURRENTLY USED:" -ForegroundColor Yellow
    kubectl get pods --namespace default -o wide

    Write-Host ""
    Write-Host "NUMBER OF RUNNING PODS:" -ForegroundColor Yellow
    $runningPods = kubectl get pods --namespace default --no-headers 2>$null | Select-String "Running"
    $podCount = @($runningPods).Count
    Write-Host "Running Pods: $podCount" -ForegroundColor Green

    Write-Host ""
    Write-Host "SERVICE DETAILS:" -ForegroundColor Yellow
    kubectl get svc --namespace default -o wide

    Write-Host ""
    Write-Host "CPU AND MEMORY USAGE:" -ForegroundColor Yellow
    kubectl top pods --namespace default

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "kubectl top pods not available. Metrics server may not be enabled." -ForegroundColor Red
        Write-Host "Showing pod resource requests and limits instead:" -ForegroundColor Yellow
        kubectl describe deployment expo-web-deployment --namespace default | Select-String "Limits|Requests|cpu|memory"
    }

    Write-Host ""
    Write-Host "NODE MEMORY AND CPU USAGE:" -ForegroundColor Yellow
    kubectl top nodes

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "kubectl top nodes not available. Enable metrics-server using:" -ForegroundColor Yellow
        Write-Host "minikube addons enable metrics-server" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor Cyan
}

Write-Output "PERFORMING HARD SCRUB ON PORT 8000 AND LAUNCHING BACKEND..."
Clear-Port8000

Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "Clear-Host; Set-Location '$PSScriptRoot'; Write-Host 'LAUNCHING CONTROL PLANE BACKEND BRIDGE ENGINE...' -ForegroundColor Cyan; python dashboard_backend.py"

Write-Output "Waiting 5 seconds for backend API server to bind cleanly to port 8000..."
Start-Sleep -Seconds 5

Write-Output "STARTING INSTANT GITOPS PIPELINE ROLLOUT..."

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
    Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "Clear-Host; Set-Location '$PSScriptRoot\src'; Write-Host 'LAUNCHING EXPO MOBILE FRONTEND INTERFACE ON PORT $expoPort...' -ForegroundColor Blue; npx expo start -w --port $expoPort --non-interactive"
    Exit
}

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
    Send-SlackFailure "STAGE 1 (Git Sync)" "Repository push rejected or upstream remote server unavailable."
}

Write-Output "STAGE 2 OF 5: Baking Docker Image layers directly into local cluster nodes..."
try {
    $disruptCheck = Invoke-RestMethod -Uri "http://127.0.0.1:8000/api/metrics" -Method Get -TimeoutSec 2
    if ($disruptCheck.chaosSimulationActive -eq $true -or $disruptCheck.disrupted -eq $true) {
        Write-Host ""
        Write-Host "!!! CHAOS INTERACTION DETECTED: Simulating Broken Docker Compilation !!!" -ForegroundColor Red
        Send-SlackFailure "STAGE 2 (Docker Build)" "Compilation failed inside the Dockerfile environment layers due to an armed infrastructure disruption."
    }
} catch {
    Write-Host "Metrics API bridge offline, proceeding with standard verification loop..." -ForegroundColor Yellow
}

$dockerImage = "sujeymcw/expo-web-app"

docker build -f ./Dockerfile -t "${dockerImage}:$buildTag" . --quiet
if ($LASTEXITCODE -ne 0) {
    Send-SlackFailure "STAGE 2 (Docker Build)" "Compilation failed inside the Dockerfile environment layers."
}

Write-Host "Docker Image Generated Successfully: ${dockerImage}:$buildTag" -ForegroundColor Green

Write-Output "STAGE 3 OF 5: Deploying Helm Chart and showing Kubernetes output..."

helm upgrade --install expo-web-release ./charts/my-web-app `
    --set image.repository="$dockerImage" `
    --set image.tag="$buildTag" `
    --set image.imagePullPolicy="IfNotPresent" `
    --set service.type="LoadBalancer" `
    --set service.port=80 `
    --namespace default

if ($LASTEXITCODE -ne 0) {
    Send-SlackFailure "STAGE 3 (Helm Upgrade)" "Helm manifest configuration parsing rejected by the target cluster."
}

Write-Output "STAGE 4 OF 5: Triggering instantaneous rolling update on cluster pods..."
kubectl rollout restart deployment/expo-web-deployment --namespace default
if ($LASTEXITCODE -ne 0) {
    Send-SlackFailure "STAGE 4 (Kubectl Rollout)" "Deployment target missing or pod template scheduling initialization failed."
}

kubectl rollout status deployment/expo-web-deployment --namespace default --timeout=120s

Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "Clear-Host; Set-Location '$PSScriptRoot'; Write-Host 'LIVE HELM + KUBERNETES DEPLOYMENT OUTPUT' -ForegroundColor Cyan; Write-Host 'Docker Image: ${dockerImage}:$buildTag' -ForegroundColor Green; Write-Host ''; helm status expo-web-release --namespace default; Write-Host ''; Write-Host 'DEPLOYED IMAGE:' -ForegroundColor Yellow; kubectl get deployment expo-web-deployment --namespace default -o=jsonpath='{.spec.template.spec.containers[*].image}'; Write-Host ''; Write-Host ''; Write-Host 'PODS:' -ForegroundColor Yellow; kubectl get pods --namespace default -o wide; Write-Host ''; Write-Host 'POD COUNT:' -ForegroundColor Yellow; kubectl get pods --namespace default --no-headers | find /c /v ''; Write-Host ''; Write-Host 'SERVICES:' -ForegroundColor Yellow; kubectl get svc --namespace default -o wide; Write-Host ''; Write-Host 'MEMORY AND CPU USAGE:' -ForegroundColor Yellow; kubectl top pods --namespace default; Write-Host ''; Write-Host 'NODE MEMORY:' -ForegroundColor Yellow; kubectl top nodes; Write-Host ''; Write-Host 'If memory is unavailable, run: minikube addons enable metrics-server'"

Show-KubernetesTelemetry -ImageName $dockerImage -ImageTag $buildTag

Write-Output "RUNNING OPERATIONAL ENVIRONMENT HEALTH CHECK..."
Start-Sleep -Seconds 3

$portCheck = Test-NetConnection -ComputerName "localhost" -Port 80 -WarningAction SilentlyContinue
if ($portCheck.TcpTestSucceeded) {
    $healthStatus = "PASSED (Port 80 responding cleanly)"
} else {
    $healthStatus = "WARNING (Port 80 not responding yet)"
}

$runningPods = kubectl get pods --namespace default --no-headers 2>$null | Select-String "Running"
$podCount = @($runningPods).Count

$pipelineStopwatch.Stop()
$executionDuration = [math]::Round($pipelineStopwatch.Elapsed.TotalSeconds, 2)
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

Write-Output "STAGE 5 OF 5: Dispatching instant telemetry alert to Slack..."

$textPayload = "*=== KUBERNETES DEPLOYMENT ROLLOUT SUCCESSFUL ===*" + "`n`n" +
               "*Deployment Status:* Active & Rolling" + "`n" +
               "*Docker Image Generated:* " + "${dockerImage}:$buildTag" + "`n" +
               "*Cluster Health Check:* " + $healthStatus + "`n" +
               "*Running Pods:* " + $podCount + "`n" +
               "*Memory/CPU Usage:* Check Helm telemetry terminal" + "`n" +
               "*Total Processing Velocity:* " + $executionDuration + " seconds" + "`n" +
               "*Local Endpoint URL:* http://localhost" + "`n" +
               "*Expo Frontend Port:* " + $expoPort + "`n`n" +
               "--------------------------------------------------" + "`n" +
               "*PIPELINE METRICS LOGS*" + "`n" +
               "> *Operator:* Sujey Hariprasad" + "`n" +
               "> *Cluster Environment:* Local Desktop Node (default)" + "`n" +
               "> *Helm Chart Release:* expo-web-release" + "`n" +
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
Write-Output "SUCCESS: Local server is updated. Total pipeline execution velocity: $executionDuration seconds."
Write-Output "Docker Image Generated: ${dockerImage}:$buildTag"
Write-Output "Running Pods: $podCount"
Write-Output "--------------------------------------------------"

Write-Output "LAUNCHING EXPO MOBILE INTERFACE CONSOLE IN SEPARATE POWERSHELL..."
Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "Clear-Host; Set-Location '$PSScriptRoot\src'; Write-Host 'LAUNCHING FRONTEND INTERFACE ON PORT $expoPort...' -ForegroundColor Blue; npx expo start -w --port $expoPort --non-interactive"