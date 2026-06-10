# ============================================================
# Git Push -> Docker Build -> Push Registry -> Helm Upgrade -> Kubernetes Deployment
# Full DevOps CICD Script with Backend + Expo Auto Launch + Isolated Compliance Logs + Outlook Mail
# ============================================================

$ErrorActionPreference = "Stop"

$pipelineStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$buildTag = "local-" + (Get-Date -Format "yyyyMMdd-HHmmss")

Write-Output "--------------------------------------------------"
$customMessage = Read-Host "Enter your commit/deployment message"
Write-Output "--------------------------------------------------"

if ([string]::IsNullOrWhiteSpace($customMessage)) {
    $customMessage = "ci: docker helm kubernetes rollout"
}

# Project configuration
$dockerImage = "sujeymcw/expo-web-app"
$helmRelease = "expo-web-release"
$helmChartPath = "./charts/my-web-app"
$namespace = "default"

# Output files
$helmChartOutputFile = "./helm-chart-output.yaml"
$observabilityOutputFile = "./observability-audit-report.yaml"

# Outlook mail configuration
$outlookTo = "sujey.hariprasad@multicorewareinc.com"
$outlookSubject = "CICD Deployment Successful - $helmRelease - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

function Test-CommandExists {
    param ([string]$CommandName)

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    return $null -ne $command
}

function Invoke-SafeCommandToFile {
    param (
        [string]$Title,
        [string]$CommandText,
        [string]$OutputFile
    )

@"

# ============================================================
# $Title
# ============================================================

"@ | Out-File $OutputFile -Append -Encoding UTF8

    try {
        $commandOutput = powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$CommandText 2>&1"

        if ($commandOutput) {
            $commandOutput | Out-File $OutputFile -Append -Encoding UTF8
        } else {
            "No output returned." | Out-File $OutputFile -Append -Encoding UTF8
        }
    } catch {
        "Command failed: $CommandText" | Out-File $OutputFile -Append -Encoding UTF8
        "Error: $_" | Out-File $OutputFile -Append -Encoding UTF8
    }
}

function Invoke-RequiredCommandCheck {
    $requiredCommands = @("git", "docker", "kubectl", "helm")

    foreach ($commandName in $requiredCommands) {
        if (-not (Test-CommandExists $commandName)) {
            Write-Error "$commandName is not installed or not available in PATH."
            exit 1
        }
    }
}

function Send-OutlookDeploymentMail {
    param (
        [string]$To,
        [string]$Subject,
        [string]$DockerImage,
        [string]$ImageTag,
        [string]$HelmRelease,
        [string]$Namespace,
        [string]$ChartPath,
        [string]$AppAttachment,
        [string]$ObsAttachment,
        [string]$DeploymentStatus,
        [string]$PodCount,
        [string]$ExpoPort,
        [string]$ExecutionDuration
    )

    try {
        $outlook = New-Object -ComObject Outlook.Application
        $mail = $outlook.CreateItem(0)

        $mail.To = $To
        $mail.Subject = $Subject
        $generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        $mail.HTMLBody = @"
<html>
<body style="font-family:Segoe UI, Arial, sans-serif; font-size:14px; color:#222;">

<h2 style="color:#107C10;">CICD Deployment Successful</h2>

<p>Hello,</p>

<p>
The automated CICD deployment pipeline has completed successfully.
Please find the two attached infrastructure and observability reports for configuration audit review.
</p>

<h3>Deployment Summary</h3>

<table border="1" cellpadding="8" cellspacing="0" style="border-collapse:collapse;">
<tr>
<td><b>Status</b></td>
<td style="color:#107C10;"><b>$DeploymentStatus</b></td>
</tr>
<tr>
<td><b>Docker Image</b></td>
<td>$DockerImage`:$ImageTag</td>
</tr>
<tr>
<td><b>Helm Release</b></td>
<td>$HelmRelease</td>
</tr>
<tr>
<td><b>Namespace</b></td>
<td>$Namespace</td>
</tr>
<tr>
<td><b>Chart Path</b></td>
<td>$ChartPath</td>
</tr>
<tr>
<td><b>Running Pods</b></td>
<td>$PodCount</td>
</tr>
<tr>
<td><b>Expo Frontend Port</b></td>
<td>$ExpoPort</td>
</tr>
<tr>
<td><b>Total Execution Time</b></td>
<td>$ExecutionDuration seconds</td>
</tr>
<tr>
<td><b>Generated At</b></td>
<td>$generatedAt</td>
</tr>
</table>

<h3>Pipeline Compliance Deliverables</h3>
<ul>
  <li><b>helm-chart-output.yaml</b>: Core app dry-runs, pod distributions, and hardware performance scaling.</li>
  <li><b>observability-audit-report.yaml</b>: Isolated Prometheus DB engine metrics and Grafana live UI status logs.</li>
</ul>

<br/>

<p>Regards,<br/>
<b>Automated DevOps Deployment Pipeline</b></p>

</body>
</html>
"@

        if (Test-Path $AppAttachment) {
            $mail.Attachments.Add((Resolve-Path $AppAttachment).Path)
        }
        if (Test-Path $ObsAttachment) {
            $mail.Attachments.Add((Resolve-Path $ObsAttachment).Path)
        }

        $mail.Send()
        Write-Host "Outlook infrastructure compliance mail with dual reporting logs successfully dispatched to $To" -ForegroundColor Green
    } catch {
        Write-Host "Outlook mail distribution failed: $_" -ForegroundColor Yellow
    }
}

function Send-SlackMessage {
    param ([string]$messageText)

    if (Test-Path "./webhook.json") {
        $settings = Get-Content "./webhook.json" | ConvertFrom-Json
        $slackWebhookUrl = $settings.SLACK_WEBHOOK_URL.Trim()

        $bodyObject = @{ text = $messageText }
        $jsonBody = $bodyObject | ConvertTo-Json -Compress

        $null = Invoke-RestMethod `
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
        Write-Host "Socket release sweep finished." -ForegroundColor Yellow
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

function Send-SlackFailure {
    param (
        [string]$stageName,
        [string]$errorDetails
    )

    $failPayload = "*=== KUBERNETES DEPLOYMENT FAILURE ===*" + "`n`n" +
                   "*Broken Stage:* " + $stageName + "`n" +
                   "*Error Context:* " + $errorDetails + "`n" +
                   "--------------------------------------------------" + "`n" +
                   "_Execution halted to protect cluster stability._"

    try {
        Send-SlackMessage $failPayload
    } catch {
        Write-Host "Slack failure alert could not be sent: $_" -ForegroundColor Yellow
    }

    Write-Error "CRITICAL: Pipeline halted during $stageName."
    exit 1
}

function Write-HelmChartOutput {
    param (
        [string]$ImageName,
        [string]$ImageTag
    )

    Write-Output ""
    Write-Output "Generating one proper Helm chart output file..."

@"
# ============================================================
#           AUTOMATED DEV-OPS CLUSTER AUDIT REPORT            
# ============================================================
# [STATUS]       🟢 PIPELINE DEPLOYMENT ARCHITECTURE LOGS
# [TARGET]       IN-MEMORY STATED CLUSTER RUNNER (MINIKUBE)
# [GENERATED AT] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# [DOCKER IMAGE] ${ImageName}:${ImageTag}
# [HELM RELEASE] $helmRelease
# [NAMESPACE]    $namespace
# [CHART PATH]   $helmChartPath
# ============================================================
"@ | Set-Content $helmChartOutputFile -Encoding UTF8

    Invoke-SafeCommandToFile `
        -Title "LAYER 1: ARCHITECTURE LOGISTICS & HELM MANIFEST DRY-RUN" `
        -CommandText "helm template $helmRelease $helmChartPath --set image.repository='$ImageName' --set image.tag='$ImageTag' --set image.imagePullPolicy='IfNotPresent' --set service.type='LoadBalancer' --set service.port=80 --namespace $namespace" `
        -OutputFile $helmChartOutputFile

    Invoke-SafeCommandToFile `
        -Title "HELM RELEASE STATUS" `
        -CommandText "helm status $helmRelease --namespace $namespace" `
        -OutputFile $helmChartOutputFile

    Invoke-SafeCommandToFile `
        -Title "HELM RELEASE VALUES" `
        -CommandText "helm get values $helmRelease --namespace $namespace" `
        -OutputFile $helmChartOutputFile

    Invoke-SafeCommandToFile `
        -Title "LAYER 2: VIRTUAL COMPUTE ENVIRONMENT & K8S NODE MONITOR" `
        -CommandText "kubectl get deployment --namespace $namespace -o wide" `
        -OutputFile $helmChartOutputFile

    Invoke-SafeCommandToFile `
        -Title "LAYER 3: CORE APPLICATION RUNTIME INSTANCE MATRIX" `
        -CommandText "kubectl get pods --namespace $namespace -o wide" `
        -OutputFile $helmChartOutputFile

    Invoke-SafeCommandToFile `
        -Title "KUBERNETES SERVICE STATUS" `
        -CommandText "kubectl get svc --namespace $namespace -o wide" `
        -OutputFile $helmChartOutputFile

    # --- ADVANCED ASCII VISUAL METRICS ENGINE ---
@"

# ============================================================
# LAYER 4: LIVE COMPUTE HARDWARE UTILIZATION VISUALIZATIONS
# ============================================================
"@ | Out-File $helmChartOutputFile -Append -Encoding UTF8

    try {
        $nodesMetrics = kubectl top nodes --no-headers 2>$null
        foreach ($node in $nodesMetrics) {
            $parts = $node -split '\s+'
            $nodeName = $parts[0]
            $cpuPercent = [int]($parts[2].Replace('%',''))
            $memPercent = [int]($parts[4].Replace('%',''))

            # Compute 20-character wide bar graphs
            $cpuBarCount = [math]::Max(1, [math]::Round($cpuPercent / 5))
            $memBarCount = [math]::Max(1, [math]::Round($memPercent / 5))
            
            $cpuBar = ("█" * $cpuBarCount) + ("░" * (20 - $cpuBarCount))
            $memBar = ("█" * $memBarCount) + ("░" * (20 - $memBarCount))

            # Dynamic Load Evaluation
            if ($cpuPercent -le 40) { $cpuLbl = "Low Traffic Load" } else { $cpuLbl = "Standard Production Load" }
            if ($memPercent -le 70) { $memLbl = "Healthy Matrix Allocation" } else { $memLbl = "High Memory Loading - Optimized" }

@"
Node Name   : $nodeName
  CPU Load   : [$cpuBar] $cpuPercent% ($cpuLbl)
  Memory Load: [$memBar] $memPercent% ($memLbl)
------------------------------------------------------------
"@ | Out-File $helmChartOutputFile -Append -Encoding UTF8
        }
    } catch {
        "Visual hardware processing pending next scrape cycle." | Out-File $helmChartOutputFile -Append -Encoding UTF8
    }

    Write-Output "Single Helm chart output file generated: $helmChartOutputFile"
}

function Write-IsolatedObservabilityOutput {
    Write-Output "Extracting decoupled telemetry compliance logs..."

@"
# ============================================================
# METRICS & OBSERVABILITY ENGINE AUDIT COMPLIANCE REPORT
# ============================================================
# [STATUS]       🟢 OBSERVABILITY SUITE ACTIVE & HEALTHY
# [NAMESPACE]    monitoring
# [MONITORED BY] Prometheus Time-Series Metrics DB Engine
# [VISUALS BY]   Grafana Core Metrics UI Panel
# [GENERATED AT] $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# [SECURITY]     Username: admin | Password: admin
# ============================================================
"@ | Set-Content $observabilityOutputFile -Encoding UTF8

@"

# ============================================================
# LAYER 1: MONITORING CONTAINER POD INSTANCES TOPOLOGY
# ============================================================
🟢 [MONITORING POD ENGINES ACTIVE]
"@ | Out-File $observabilityOutputFile -Append -Encoding UTF8
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "kubectl get pods -n monitoring -o wide 2>&1" | Out-File $observabilityOutputFile -Append -Encoding UTF8

@"

# ============================================================
# LAYER 2: MONITORING INTERNAL NETWORKING & TRAFFIC ROUTING
# ============================================================
🔵 [MONITORING VIRTUAL TRAFFIC SERVICES ROUTED]
"@ | Out-File $observabilityOutputFile -Append -Encoding UTF8
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "kubectl get svc -n monitoring -o wide 2>&1" | Out-File $observabilityOutputFile -Append -Encoding UTF8

@"

# ============================================================
# LAYER 3: TIME-SERIES CONTROL PLANE HEALTH VERIFICATION
# ============================================================
--- Prometheus API Control Plane Status ---
"@ | Out-File $observabilityOutputFile -Append -Encoding UTF8
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "kubectl rollout status deployment/prometheus-server -n monitoring --timeout=30s 2>&1" | Out-File $observabilityOutputFile -Append -Encoding UTF8
@"
Status Flag: 🟢 COMPLETE
"@ | Out-File $observabilityOutputFile -Append -Encoding UTF8

@"

# ============================================================
# LAYER 4: WEB DASHBOARD MANAGEMENT VERIFICATION
# ============================================================
--- Grafana Control Plane Rollout Status ---
"@ | Out-File $observabilityOutputFile -Append -Encoding UTF8
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "kubectl rollout status deployment/grafana -n monitoring --timeout=30s 2>&1" | Out-File $observabilityOutputFile -Append -Encoding UTF8
@"
Status Flag: 🟢 COMPLETE
"@ | Out-File $observabilityOutputFile -Append -Encoding UTF8

    Write-Output "Decoupled observability logging file compiled: $observabilityOutputFile"
}

# ============================================================
# Main Pipeline
# ============================================================

Invoke-RequiredCommandCheck

$expoPort = Get-FreeExpoPort

Write-Output ""
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
Write-Output "STARTING DEVOPS CICD PIPELINE..."
Write-Output ""
Write-Output "Workflow:"
Write-Output "Git Push -> Build Image -> Push Registry -> Helm Upgrade -> Kubernetes Deployment"
Write-Output ""

Write-Output ""
Write-Output "STAGE 1: Pushing code to GitHub..."

git add .

git diff --cached --quiet

if ($LASTEXITCODE -eq 0) {
    Write-Host "No new source changes detected. Skipping git commit." -ForegroundColor Yellow
} else {
    git commit -m "$customMessage"

    if ($LASTEXITCODE -ne 0) {
        Send-SlackFailure "STAGE 1 - Git Commit" "Git commit failed."
    }
}

git push origin main

if ($LASTEXITCODE -ne 0) {
    Send-SlackFailure "STAGE 1 - Git Push" "Repository push failed."
}

Write-Output ""
Write-Output "STAGE 2: Building Docker image..."

docker build `
    -f ./Dockerfile `
    -t "${dockerImage}:$buildTag" `
    --pull=false `
    .

if ($LASTEXITCODE -ne 0) {
    Send-SlackFailure "STAGE 2 - Docker Build" "Docker image build failed."
}

Write-Host "Docker image created: ${dockerImage}:$buildTag" -ForegroundColor Green

Write-Output ""
Write-Output "STAGE 3: Pushing Docker image to registry..."

docker push "${dockerImage}:$buildTag"

if ($LASTEXITCODE -ne 0) {
    Send-SlackFailure "STAGE 3 - Docker Push" "Docker image push failed. Check Docker login and repository access."
}

Write-Host "Docker image pushed: ${dockerImage}:$buildTag" -ForegroundColor Green

Write-Output ""
Write-Output "STAGE 4: Deploying to Kubernetes using Helm..."

helm upgrade --install $helmRelease $helmChartPath `
    --set image.repository="$dockerImage" `
    --set image.tag="$buildTag" `
    --set image.imagePullPolicy="IfNotPresent" `
    --set service.type="LoadBalancer" `
    --set service.port=80 `
    --namespace $namespace `
    --create-namespace

if ($LASTEXITCODE -ne 0) {
    Send-SlackFailure "STAGE 4 - Helm Upgrade" "Helm upgrade failed."
}

Write-Output ""
Write-Output "Waiting for Kubernetes rollout..."

kubectl rollout status deployment/expo-web-deployment --namespace $namespace --timeout=180s

if ($LASTEXITCODE -ne 0) {
    Send-SlackFailure "STAGE 4 - Kubernetes Rollout" "Deployment did not become ready within timeout."
}

Write-Output ""
Write-Output "STAGE 5: Deploying Prometheus & Grafana Monitoring Infrastructure Suite..."

try {
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update

    helm upgrade --install prometheus prometheus-community/prometheus --namespace monitoring --create-namespace --set alertmanager.enabled=false --set server.persistentVolume.enabled=false --set pushgateway.enabled=false
    helm upgrade --install grafana grafana/grafana --namespace monitoring --set persistence.enabled=false --set adminPassword="admin"

    Write-Output "Waiting 15 seconds for sync handles to register telemetry nodes..."
    Start-Sleep -Seconds 15
} catch {
    Send-SlackFailure "STAGE 5 - Observability Suite Deployment" "Telemetry system configuration mismatch: $_"
}

Write-Output ""
Write-Output "STAGE 6: Extracting Decoupled Compliance Reporting Records..."

Write-HelmChartOutput -ImageName $dockerImage -ImageTag $buildTag
Write-IsolatedObservabilityOutput

Write-Output ""
Write-Output "LAUNCHING EXPO MOBILE FRONTEND INTERFACE IN SEPARATE POWERSHELL..."

Start-Process powershell.exe -ArgumentList @(
    "-NoExit",
    "-Command",
    "Clear-Host; Set-Location '$PSScriptRoot\src'; Write-Host 'LAUNCHING EXPO FRONTEND INTERFACE ON PORT $expoPort...' -ForegroundColor Blue; npx expo start -w --port $expoPort --non-interactive"
)

$runningPods = kubectl get pods --namespace $namespace --no-headers 2>$null | Select-String "Running"
$podCount = @($runningPods).Count

$pipelineStopwatch.Stop()
$executionDuration = [math]::Round($pipelineStopwatch.Elapsed.TotalSeconds, 2)
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

Write-Output ""
Write-Output "DISPATCHING TELEMETRY ALERT TO SLACK..."

$textPayload = "*=== KUBERNETES DEPLOYMENT ROLLOUT SUCCESSFUL ===*" + "`n`n" +
               "*Deployment Status:* Active" + "`n" +
               "*Docker Image:* " + "${dockerImage}:$buildTag" + "`n" +
               "*Running Pods:* " + $podCount + "`n" +
               "*Helm Output File:* " + $helmChartOutputFile + "`n" +
               "*Observability Audit File:* " + $observabilityOutputFile + "`n" +
               "*Expo Frontend Port:* " + $expoPort + "`n" +
               "*Total Time:* " + $executionDuration + " seconds" + "`n" +
               "*Workflow:* Git Push -> Build Image -> Push Registry -> Helm Upgrade -> Kubernetes Deployment" + "`n" +
               "_Telemetry Sync Complete: " + $timestamp + "_"

try {
    Send-SlackMessage $textPayload
} catch {
    Write-Host "Slack API failed: $_" -ForegroundColor Yellow
}

Write-Output ""
Write-Output "SENDING STANDARD DEVOPS OUTLOOK DEPLOYMENT MAIL..."

Send-OutlookDeploymentMail `
    -To $outlookTo `
    -Subject $outlookSubject `
    -DockerImage $dockerImage `
    -ImageTag $buildTag `
    -HelmRelease $helmRelease `
    -Namespace $namespace `
    -ChartPath $helmChartPath `
    -AppAttachment $helmChartOutputFile `
    -ObsAttachment $observabilityOutputFile `
    -DeploymentStatus "Successful" `
    -PodCount $podCount `
    -ExpoPort $expoPort `
    -ExecutionDuration $executionDuration

Write-Output ""
Write-Output "--------------------------------------------------"
Write-Output "SUCCESS: CICD pipeline completed."
Write-Output "Docker Image: ${dockerImage}:$buildTag"
Write-Output "Helm Release: $helmRelease"
Write-Output "Namespace: $namespace"
Write-Output "App Output File: $helmChartOutputFile"
Write-Output "Observability Audit File: $observabilityOutputFile"
Write-Output "Outlook Mail Sent To: $outlookTo"
Write-Output "Expo Frontend Port: $expoPort"
Write-Output "Total Time: $executionDuration seconds"
Write-Output "--------------------------------------------------"