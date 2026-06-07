# ============================================================
# Git Push -> Docker Build -> Push Registry -> Helm Upgrade -> Kubernetes Deployment
# Full DevOps CICD Script with Backend + Expo Auto Launch + Clean Helm Output
# ============================================================

$ErrorActionPreference = "Stop"

# 1. Start the performance benchmark stopwatch
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

# Single proper Helm output file
$helmChartOutputFile = "./helm-chart-output.yaml"

function Test-CommandExists {
    param (
        [string]$CommandName
    )

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    return $null -ne $command
}

function Refresh-Path {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = $machinePath + ";" + $userPath
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

function Install-MinikubeIfMissing {
    Write-Output ""
    Write-Output "PRE-FLIGHT: Checking Minikube installation..."

    if (Test-CommandExists "minikube") {
        Write-Output "Minikube is already installed."
        return
    }

    Write-Output "Minikube is not installed. Installing Minikube using winget..."

    if (-not (Test-CommandExists "winget")) {
        Write-Error "winget is not available. Install Minikube manually using: winget install Kubernetes.minikube"
        exit 1
    }

    winget install --id Kubernetes.minikube -e --accept-package-agreements --accept-source-agreements

    Refresh-Path

    if (-not (Test-CommandExists "minikube")) {
        Write-Error "Minikube was installed, but PowerShell cannot detect it yet. Close this terminal, open PowerShell again, and rerun this script."
        exit 1
    }

    Write-Output "Minikube installed successfully."
}

function Start-MinikubeCluster {
    Write-Output ""
    Write-Output "PRE-FLIGHT: Checking Minikube cluster..."

    minikube status *> $null

    if ($LASTEXITCODE -eq 0) {
        Write-Output "Minikube cluster is already running."
        return
    }

    Write-Output "Starting Minikube cluster using Docker driver..."

    minikube start --driver=docker

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Minikube failed to start. Make sure Docker Desktop is running."
        exit 1
    }

    Write-Output "Minikube cluster started successfully."
}

function Ensure-MetricsServer {
    Write-Output ""
    Write-Output "PRE-FLIGHT: Checking Kubernetes Metrics Server..."

    $topCheck = kubectl top nodes 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Output "Metrics Server is already active."
        return
    }

    Write-Output "Metrics Server not ready yet."
    Write-Output "Current metrics response: $topCheck"

    if (-not (Test-CommandExists "minikube")) {
        Write-Error "Minikube is required to enable metrics-server addon."
        exit 1
    }

    Write-Output "Enabling Minikube metrics-server addon..."

    minikube addons enable metrics-server

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to enable metrics-server addon."
        exit 1
    }

    Write-Output "Waiting for metrics-server rollout..."

    kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s

    Write-Output "Waiting for Metrics API to become available..."

    for ($i = 1; $i -le 30; $i++) {
        $metricsCheck = kubectl top nodes 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Output "Metrics Server is active. CPU and memory metrics are available."
            return
        }

        Write-Output "Metrics API warming up... attempt $i of 30"
        Start-Sleep -Seconds 5
    }

    Write-Output "Metrics Server is installed but metrics are still not available yet."
    Write-Output "Deployment will continue. The Helm output file will show this clearly instead of crashing."
}

function Send-SlackMessage {
    param (
        [string]$messageText
    )

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

    Invoke-SafeCommandToFile `
        -Title "POD CPU AND MEMORY METRICS" `
        -CommandText "kubectl top pods --namespace $namespace" `
        -OutputFile $helmChartOutputFile

    Invoke-SafeCommandToFile `
        -Title "NODE CPU AND MEMORY METRICS" `
        -CommandText "kubectl top nodes" `
        -OutputFile $helmChartOutputFile

@"

# ============================================================
# METRICS NOTE
# ============================================================
# If this file shows "metrics not available yet", the deployment is not failed.
# It only means metrics-server is still warming up.
# Run after 1-2 minutes:
#   kubectl top nodes
#   kubectl top pods --namespace $namespace
# ============================================================

"@ | Out-File $helmChartOutputFile -Append -Encoding UTF8

    Write-Output "Single Helm chart output file generated: $helmChartOutputFile"
}

# ============================================================
# Main Pipeline
# ============================================================

Invoke-RequiredCommandCheck
Install-MinikubeIfMissing
Start-MinikubeCluster

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

Ensure-MetricsServer

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
Write-Output "STAGE 5: Creating one proper Helm chart output file..."

Write-HelmChartOutput -ImageName $dockerImage -ImageTag $buildTag

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
Write-Output "--------------------------------------------------"
Write-Output "SUCCESS: CICD pipeline completed."
Write-Output "Docker Image: ${dockerImage}:$buildTag"
Write-Output "Helm Release: $helmRelease"
Write-Output "Namespace: $namespace"
Write-Output "Single Helm Output File: $helmChartOutputFile"
Write-Output "Expo Frontend Port: $expoPort"
Write-Output "Total Time: $executionDuration seconds"
Write-Output "--------------------------------------------------"
