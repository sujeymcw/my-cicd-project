# ============================================================
# GitHub Push -> Docker Build -> Docker Push -> Helm Upgrade -> Kubernetes Deployment
# Clean DevOps Pipeline Script
# ============================================================

$ErrorActionPreference = "Stop"

# Start pipeline timer
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

function Invoke-RequiredCommandCheck {
    $requiredCommands = @("git", "docker", "kubectl", "helm")

    foreach ($commandName in $requiredCommands) {
        if (-not (Test-CommandExists $commandName)) {
            Write-Error "$commandName is not installed or not available in PATH."
            exit 1
        }
    }
}

function Ensure-MetricsServer {
    Write-Output ""
    Write-Output "PRE-FLIGHT: Checking Kubernetes Metrics Server..."

    kubectl top nodes *> $null

    if ($LASTEXITCODE -eq 0) {
        Write-Output "Metrics Server is already active."
        return
    }

    if (Test-CommandExists "minikube") {
        Write-Output "Metrics Server not found. Minikube detected, enabling metrics-server addon..."

        minikube addons enable metrics-server *> $null

        if ($LASTEXITCODE -ne 0) {
            Write-Output "Metrics Server addon could not be enabled. Continuing deployment."
            return
        }

        Write-Output "Waiting for Metrics Server rollout..."
        kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s *> $null

        for ($i = 1; $i -le 20; $i++) {
            kubectl top nodes *> $null

            if ($LASTEXITCODE -eq 0) {
                Write-Output "Metrics Server is active."
                return
            }

            Start-Sleep -Seconds 5
        }

        Write-Output "Metrics Server was enabled, but metrics API is still warming up."
        return
    }

    Write-Output "Minikube is not installed. Skipping Minikube metrics-server addon step."
    Write-Output "Deployment will continue normally."
}

function Write-HelmChartOutput {
    param (
        [string]$ImageName,
        [string]$ImageTag
    )

    Write-Output ""
    Write-Output "Generating single Helm chart output file..."

@"
# ============================================================
# HELM CHART DEPLOYMENT OUTPUT
# ============================================================
# Generated At: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Workflow:
#   Git Push
#      ↓
#   Build Image
#      ↓
#   Push Registry
#      ↓
#   Helm Upgrade
#      ↓
#   Kubernetes Deployment
#
# Docker Image : ${ImageName}:${ImageTag}
# Helm Release : $helmRelease
# Namespace    : $namespace
# Chart Path   : $helmChartPath
# ============================================================

"@ | Set-Content $helmChartOutputFile -Encoding UTF8

    helm template $helmRelease $helmChartPath `
        --set image.repository="$ImageName" `
        --set image.tag="$ImageTag" `
        --set image.imagePullPolicy="IfNotPresent" `
        --set service.type="LoadBalancer" `
        --set service.port=80 `
        --namespace $namespace | Out-File $helmChartOutputFile -Append -Encoding UTF8

@"

# ============================================================
# HELM RELEASE STATUS
# ============================================================

"@ | Out-File $helmChartOutputFile -Append -Encoding UTF8

    helm status $helmRelease --namespace $namespace | Out-File $helmChartOutputFile -Append -Encoding UTF8

@"

# ============================================================
# KUBERNETES DEPLOYMENT STATUS
# ============================================================

"@ | Out-File $helmChartOutputFile -Append -Encoding UTF8

    kubectl get deployment --namespace $namespace -o wide | Out-File $helmChartOutputFile -Append -Encoding UTF8

@"

# ============================================================
# KUBERNETES POD STATUS
# ============================================================

"@ | Out-File $helmChartOutputFile -Append -Encoding UTF8

    kubectl get pods --namespace $namespace -o wide | Out-File $helmChartOutputFile -Append -Encoding UTF8

@"

# ============================================================
# KUBERNETES SERVICE STATUS
# ============================================================

"@ | Out-File $helmChartOutputFile -Append -Encoding UTF8

    kubectl get svc --namespace $namespace -o wide | Out-File $helmChartOutputFile -Append -Encoding UTF8

@"

# ============================================================
# RESOURCE METRICS
# ============================================================

"@ | Out-File $helmChartOutputFile -Append -Encoding UTF8

    kubectl top pods --namespace $namespace 2>$null | Out-File $helmChartOutputFile -Append -Encoding UTF8

    if ($LASTEXITCODE -ne 0) {
@"
Metrics API is not available.
This does not stop the deployment.
Install or enable metrics-server to view CPU and memory usage.

"@ | Out-File $helmChartOutputFile -Append -Encoding UTF8
    }

    Write-Output "Helm chart output created: $helmChartOutputFile"
}

# ============================================================
# Pipeline execution
# ============================================================

Invoke-RequiredCommandCheck

Write-Output ""
Write-Output "STARTING DEVOPS CICD PIPELINE..."
Write-Output ""
Write-Output "Workflow:"
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

Ensure-MetricsServer

Write-Output ""
Write-Output "STAGE 1: Pushing code to GitHub..."

git add .

git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Output "No new changes found. Skipping git commit."
} else {
    git commit -m "$customMessage"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Git commit failed."
        exit 1
    }
}

git push origin main

if ($LASTEXITCODE -ne 0) {
    Write-Error "Git push failed."
    exit 1
}

Write-Output ""
Write-Output "STAGE 2: Building Docker image..."

docker build `
    -f ./Dockerfile `
    -t "${dockerImage}:$buildTag" `
    --pull=false `
    .

if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker image build failed."
    exit 1
}

Write-Output "Docker image created: ${dockerImage}:$buildTag"

Write-Output ""
Write-Output "STAGE 3: Pushing Docker image to registry..."

docker push "${dockerImage}:$buildTag"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker image push failed. Please check Docker login and repository access."
    exit 1
}

Write-Output "Docker image pushed: ${dockerImage}:$buildTag"

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
    Write-Error "Helm upgrade failed."
    exit 1
}

Write-Output ""
Write-Output "Waiting for Kubernetes deployment rollout..."

kubectl rollout status deployment/expo-web-deployment --namespace $namespace --timeout=180s

if ($LASTEXITCODE -ne 0) {
    Write-Error "Kubernetes deployment rollout failed."
    exit 1
}

Write-Output ""
Write-Output "STAGE 5: Creating one proper Helm chart output..."

Write-HelmChartOutput -ImageName $dockerImage -ImageTag $buildTag

$pipelineStopwatch.Stop()
$executionDuration = [math]::Round($pipelineStopwatch.Elapsed.TotalSeconds, 2)

Write-Output ""
Write-Output "--------------------------------------------------"
Write-Output "SUCCESS: CICD pipeline completed."
Write-Output "Docker Image: ${dockerImage}:$buildTag"
Write-Output "Helm Release: $helmRelease"
Write-Output "Namespace: $namespace"
Write-Output "Single Helm Output File: $helmChartOutputFile"
Write-Output "Total Time: $executionDuration seconds"
Write-Output "--------------------------------------------------"
