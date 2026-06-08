# ============================================================
# Git Push -> Docker Build -> Push Registry -> Helm Upgrade -> Kubernetes Deployment
# Full DevOps CICD Script with Backend + Expo Auto Launch + Clean Helm Output + Outlook Mail
# Optimized + Metrics Server Retry Fix
# ============================================================

$ErrorActionPreference = "Stop"
$env:DOCKER_BUILDKIT = "1"

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

# Output file
$helmChartOutputFile = "./helm-chart-output.yaml"

# Outlook mail configuration
$outlookTo = "sujey.hariprasad@multicorewareinc.com"
$outlookSubject = "CICD Deployment Successful - $helmRelease - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

function Test-CommandExists {
    param ([string]$CommandName)

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    return $null -ne $command
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

function Add-SectionToFile {
    param (
        [string]$Title,
        [string]$OutputFile
    )

@"

# ============================================================
# $Title
# ============================================================

"@ | Out-File $OutputFile -Append -Encoding UTF8
}

function Invoke-SafeCommandToFile {
    param (
        [string]$Title,
        [string]$CommandText,
        [string]$OutputFile
    )

    Add-SectionToFile -Title $Title -OutputFile $OutputFile

    try {
        $commandOutput = Invoke-Expression "$CommandText 2>&1"

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

function Enable-MetricsServerIfPossible {
    Write-Output "Checking Metrics Server..."

    try {
        kubectl get deployment metrics-server -n kube-system 1>$null 2>$null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "Metrics Server deployment already exists." -ForegroundColor Green
            return
        }
    } catch {}

    if (Test-CommandExists "minikube") {
        Write-Host "Metrics Server not found. Enabling Minikube metrics-server addon..." -ForegroundColor Yellow

        try {
            minikube addons enable metrics-server
        } catch {
            Write-Host "Minikube metrics-server addon enable failed: $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Minikube not detected. Metrics Server auto-enable skipped for non-Minikube cluster." -ForegroundColor Yellow
    }
}

function Wait-ForMetricsServer {
    param (
        [int]$MaxAttempts = 20,
        [int]$SleepSeconds = 6
    )

    Write-Output "Waiting for Metrics Server API to become available..."

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            $metricsCheck = kubectl top nodes 2>&1

            if ($LASTEXITCODE -eq 0 -and $metricsCheck -and ($metricsCheck -notmatch "metrics not available yet") -and ($metricsCheck -notmatch "Metrics API not available")) {
                Write-Host "Metrics Server is ready." -ForegroundColor Green
                return $true
            }

            Write-Host "Metrics not ready yet. Attempt $attempt of $MaxAttempts..." -ForegroundColor Yellow
            Start-Sleep -Seconds $SleepSeconds
        } catch {
            Write-Host "Metrics check attempt $attempt failed. Retrying..." -ForegroundColor Yellow
            Start-Sleep -Seconds $SleepSeconds
        }
    }

    Write-Host "Metrics Server is installed but metrics are still warming up." -ForegroundColor Yellow
    return $false
}

function Write-MetricsToFile {
    param (
        [string]$OutputFile,
        [string]$Namespace
    )

    Enable-MetricsServerIfPossible
    $metricsReady = Wait-ForMetricsServer -MaxAttempts 20 -SleepSeconds 6

    Add-SectionToFile -Title "POD CPU AND MEMORY METRICS" -OutputFile $OutputFile

    if ($metricsReady) {
        try {
            $podMetrics = kubectl top pods --namespace $Namespace 2>&1

            if ($LASTEXITCODE -eq 0) {
                $podMetrics | Out-File $OutputFile -Append -Encoding UTF8
            } else {
                "kubectl top pods failed after retry. Capturing pod resource fallback." | Out-File $OutputFile -Append -Encoding UTF8
                kubectl get pods --namespace $Namespace -o wide 2>&1 | Out-File $OutputFile -Append -Encoding UTF8
                kubectl describe pods --namespace $Namespace 2>&1 | Out-File $OutputFile -Append -Encoding UTF8
            }
        } catch {
            "Pod metrics capture failed. Capturing fallback pod details." | Out-File $OutputFile -Append -Encoding UTF8
            kubectl get pods --namespace $Namespace -o wide 2>&1 | Out-File $OutputFile -Append -Encoding UTF8
            kubectl describe pods --namespace $Namespace 2>&1 | Out-File $OutputFile -Append -Encoding UTF8
        }
    } else {
        "Metrics Server is active but Kubernetes has not produced metrics yet." | Out-File $OutputFile -Append -Encoding UTF8
        "Fallback captured below: pod status, requests, limits, and node allocation details." | Out-File $OutputFile -Append -Encoding UTF8
        kubectl get pods --namespace $Namespace -o wide 2>&1 | Out-File $OutputFile -Append -Encoding UTF8
        kubectl describe pods --namespace $Namespace 2>&1 | Out-File $OutputFile -Append -Encoding UTF8
    }

    Add-SectionToFile -Title "NODE CPU AND MEMORY METRICS" -OutputFile $OutputFile

    if ($metricsReady) {
        try {
            $nodeMetrics = kubectl top nodes 2>&1

            if ($LASTEXITCODE -eq 0) {
                $nodeMetrics | Out-File $OutputFile -Append -Encoding UTF8
            } else {
                "kubectl top nodes failed after retry. Capturing node fallback." | Out-File $OutputFile -Append -Encoding UTF8
                kubectl get nodes -o wide 2>&1 | Out-File $OutputFile -Append -Encoding UTF8
                kubectl describe nodes 2>&1 | Out-File $OutputFile -Append -Encoding UTF8
            }
        } catch {
            "Node metrics capture failed. Capturing fallback node details." | Out-File $OutputFile -Append -Encoding UTF8
            kubectl get nodes -o wide 2>&1 | Out-File $OutputFile -Append -Encoding UTF8
            kubectl describe nodes 2>&1 | Out-File $OutputFile -Append -Encoding UTF8
        }
    } else {
        "Metrics Server is active but node metrics are not ready yet." | Out-File $OutputFile -Append -Encoding UTF8
        "Fallback captured below: node status and allocation details." | Out-File $OutputFile -Append -Encoding UTF8
        kubectl get nodes -o wide 2>&1 | Out-File $OutputFile -Append -Encoding UTF8
        kubectl describe nodes 2>&1 | Out-File $OutputFile -Append -Encoding UTF8
    }

@"

# ============================================================
# METRICS STATUS
# ============================================================
# Metrics Server Checked : Yes
# Metrics Capture Mode   : kubectl top with retry
# Fallback Mode          : kubectl describe pods/nodes if live metrics are warming up
# ============================================================

"@ | Out-File $OutputFile -Append -Encoding UTF8
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
        [string]$AttachmentPath,
        [string]$DeploymentStatus,
        [string]$PodCount,
        [string]$ExpoPort,
        [string]$ExecutionDuration
    )

    try {
        if (-not (Test-Path $AttachmentPath)) {
            Write-Host "Outlook mail skipped. Attachment not found: $AttachmentPath" -ForegroundColor Yellow
            return
        }

        $resolvedAttachment = (Resolve-Path $AttachmentPath).Path
        $generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        $outlook = New-Object -ComObject Outlook.Application
        $mail = $outlook.CreateItem(0)

        $mail.To = $To
        $mail.Subject = $Subject

        $mail.HTMLBody = @"
<html>
<body style="font-family:Segoe UI, Arial, sans-serif; font-size:14px; color:#222;">

<h2 style="color:#107C10;">CICD Deployment Successful</h2>

<p>Hello,</p>

<p>
The automated CICD deployment pipeline has completed successfully.
Please find the attached Helm deployment output report for review.
</p>

<h3>Deployment Summary</h3>

<table border="1" cellpadding="8" cellspacing="0" style="border-collapse:collapse;">
<tr><td><b>Status</b></td><td style="color:#107C10;"><b>$DeploymentStatus</b></td></tr>
<tr><td><b>Docker Image</b></td><td>$DockerImage`:$ImageTag</td></tr>
<tr><td><b>Helm Release</b></td><td>$HelmRelease</td></tr>
<tr><td><b>Namespace</b></td><td>$Namespace</td></tr>
<tr><td><b>Chart Path</b></td><td>$ChartPath</td></tr>
<tr><td><b>Running Pods</b></td><td>$PodCount</td></tr>
<tr><td><b>Expo Frontend Port</b></td><td>$ExpoPort</td></tr>
<tr><td><b>Total Execution Time</b></td><td>$ExecutionDuration seconds</td></tr>
<tr><td><b>Generated At</b></td><td>$generatedAt</td></tr>
</table>

<h3>Pipeline Workflow</h3>

<p>Git Push &rarr; Docker Build &rarr; Docker Push &rarr; Helm Upgrade &rarr; Kubernetes Deployment</p>

<h3>Attachment</h3>

<p>Attached File: <b>helm-chart-output.yaml</b></p>

<br/>

<p>Regards,<br/>
<b>Automated DevOps Deployment Pipeline</b></p>

</body>
</html>
"@

        $mail.Attachments.Add($resolvedAttachment)
        $mail.Send()

        Write-Host "Outlook deployment mail sent successfully to $To" -ForegroundColor Green
    } catch {
        Write-Host "Outlook mail failed: $_" -ForegroundColor Yellow
    }
}

function Send-SlackMessage {
    param ([string]$messageText)

    if (Test-Path "./webhook.json") {
        $settings = Get-Content "./webhook.json" | ConvertFrom-Json
        $slackWebhookUrl = $settings.SLACK_WEBHOOK_URL.Trim()

        $bodyObject = @{ text = $messageText }
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

        Start-Sleep -Seconds 1
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
# HELM CHART DEPLOYMENT OUTPUT
# ============================================================
# Generated At : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Workflow     : Git Push -> Build Image -> Push Registry -> Helm Upgrade -> Kubernetes Deployment
# Docker Image : ${ImageName}:${ImageTag}
# Helm Release : $helmRelease
# Namespace    : $namespace
# Chart Path   : $helmChartPath
# ============================================================

"@ | Set-Content $helmChartOutputFile -Encoding UTF8

    Invoke-SafeCommandToFile `
        -Title "HELM RENDERED MANIFEST" `
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
        -Title "KUBERNETES DEPLOYMENT STATUS" `
        -CommandText "kubectl get deployment --namespace $namespace -o wide" `
        -OutputFile $helmChartOutputFile

    Invoke-SafeCommandToFile `
        -Title "KUBERNETES POD STATUS" `
        -CommandText "kubectl get pods --namespace $namespace -o wide" `
        -OutputFile $helmChartOutputFile

    Invoke-SafeCommandToFile `
        -Title "KUBERNETES SERVICE STATUS" `
        -CommandText "kubectl get svc --namespace $namespace -o wide" `
        -OutputFile $helmChartOutputFile

    Write-MetricsToFile -OutputFile $helmChartOutputFile -Namespace $namespace

    Write-Output "Single Helm chart output file generated: $helmChartOutputFile"
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

Write-Output "Waiting for backend API server to bind cleanly to port 8000..."

$backendReady = $false

for ($i = 1; $i -le 15; $i++) {
    try {
        Invoke-WebRequest "http://127.0.0.1:8000" -TimeoutSec 1 | Out-Null
        $backendReady = $true
        Write-Host "Backend API server is ready." -ForegroundColor Green
        break
    } catch {
        Start-Sleep -Milliseconds 500
    }
}

if (-not $backendReady) {
    Write-Host "Backend did not respond yet. Continuing pipeline because backend runs separately." -ForegroundColor Yellow
}

Write-Output ""
Write-Output "LAUNCHING EXPO MOBILE FRONTEND INTERFACE IN SEPARATE POWERSHELL..."

Start-Process powershell.exe -ArgumentList @(
    "-NoExit",
    "-Command",
    "Clear-Host; Set-Location '$PSScriptRoot\src'; Write-Host 'LAUNCHING EXPO FRONTEND INTERFACE ON PORT $expoPort...' -ForegroundColor Blue; npx expo start -w --port $expoPort --non-interactive"
)

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
Write-Output "STAGE 2: Building Docker image with BuildKit optimization..."

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

kubectl wait `
    --for=condition=available `
    deployment/expo-web-deployment `
    --namespace $namespace `
    --timeout=90s

if ($LASTEXITCODE -ne 0) {
    Send-SlackFailure "STAGE 4 - Kubernetes Rollout" "Deployment did not become available within timeout."
}

Write-Output ""
Write-Output "STAGE 5: Creating one proper Helm chart output file..."

Write-HelmChartOutput -ImageName $dockerImage -ImageTag $buildTag

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
    -AttachmentPath $helmChartOutputFile `
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
Write-Output "Single Helm Output File: $helmChartOutputFile"
Write-Output "Outlook Mail Sent To: $outlookTo"
Write-Output "Expo Frontend Port: $expoPort"
Write-Output "Total Time: $executionDuration seconds"
Write-Output "--------------------------------------------------"