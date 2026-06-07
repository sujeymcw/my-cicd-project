# 1. Start the performance benchmark stopwatch to calculate execution velocity
$pipelineStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$buildTag = "local-" + (Get-Date -Format "yyyyMMdd-HHmmss")

# Prompt the user for a custom commit message right at launch
Write-Output "--------------------------------------------------"
$customMessage = Read-Host "Enter your commit/deployment message"
Write-Output "--------------------------------------------------"

if ([string]::IsNullOrWhiteSpace($customMessage)) {
    $customMessage = "style: rapid telemetry interface deployment sync"
}

# IMMEDIATE AUTOMATION: Spawn a separate, independent, visible PowerShell window to run your Python API backend
Write-Output "LAUNCHING PYTHON BACKEND SYSTEM IN SEPARATE POWERSHELL..."
Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "Clear-Host; Write-Host 'LAUNCHING CONTROL PLANE BACKEND BRIDGE ENGINE...' -ForegroundColor Cyan; python dashboard_backend.py"

Write-Output "Waiting 3 seconds for backend API server to bind cleanly to port 8000..."
Start-Sleep -Seconds 3

Write-Output "STARTING INSTANT GITOPS PIPELINE ROLLOUT..."

# Reusable Emergency Gatekeeper Function for Pipeline Safety
function Send-SlackFailure([string]$stageName, [string]$errorDetails) {
    if (Test-Path "./webhook.json") {
        $settings = Get-Content "./webhook.json" | ConvertFrom-Json
        $failPayload = "*=== KUBERNETES DEPLOYMENT CRITICAL FAILURE ===*" + "`n`n" +
                       "*Broken Stage:* " + $stageName + "`n" +
                       "*Error Context:* " + $errorDetails + "`n" +
                       "--------------------------------------------------" + "`n" +
                       "_Execution halted instantly to protect active cluster node stability._"
        $body = @{ text = $failPayload }
        $null = Invoke-RestMethod -Uri $settings.SLACK_WEBHOOK_URL -Method Post -Body ($body | ConvertTo-Json) -ContentType "application/json; charset=utf-8"
    }
    Write-Error "CRITICAL: Pipeline halted during execution at $stageName."
    
    # EMERGENCY FALLBACK: Even if the pipeline breaks, still launch the Expo frontend window for debugging!
    Write-Output "LAUNCHING EXPO MOBILE INTERFACE CONSOLE IN SEPARATE POWERSHELL..."
    Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "Clear-Host; Write-Host 'LAUNCHING EXPO MOBILE FRONTEND INTERFACE...' -ForegroundColor Blue; npx expo start -w"
    Exit
}

# 2. Stage 1: Sync with GitHub Tracking Repository
Write-Output "STAGE 1 OF 5: Syncing source files with Git Repository..."
git add .
git commit -m "$customMessage" --quiet
git push origin main --quiet
if (-not $?) { Send-SlackFailure "STAGE 1 (Git Sync)" "Repository push rejected or upstream remote server unavailable." }

# 3. Stage 2: Compile and Inject Image with Live Disruption Interceptor Check
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

docker build -f ./Dockerfile -t sujeymcw/expo-web-app:$buildTag . --quiet
if (-not $?) { Send-SlackFailure "STAGE 2 (Docker Build)" "Compilation failed inside the Dockerfile environment layers." }

# 4. Stage 3: Helm Chart Manifest Deployments
Write-Output "STAGE 3 OF 5: Launching independent terminal for Helm Chart status outputs..."
helm upgrade --install expo-web-release ./charts/my-web-app --set image.repository="sujeymcw/expo-web-app" --set image.tag=$buildTag --set image.imagePullPolicy="IfNotPresent" --set service.type="LoadBalancer" --set service.port=80 --namespace default > $null
if (-not $?) { Send-SlackFailure "STAGE 3 (Helm Upgrade)" "Helm manifest configuration parsing rejected by the target cluster." }
Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "Clear-Host; Write-Host 'MONITORING ACTIVE HELM RELEASE STATUS...' -ForegroundColor Green; helm status expo-web-release --namespace default"

# 5. Stage 4: Kubectl Rolling Pod Update
Write-Output "STAGE 4 OF 5: Triggering instantaneous rolling update on cluster pods..."
kubectl rollout restart deployment/expo-web-deployment --namespace default
if (-not $?) { Send-SlackFailure "STAGE 4 (Kubectl Rollout)" "Deployment target missing or pod template scheduling initialization failed." }

# 6. Active Network Probing Check
Write-Output "RUNNING OPERATIONAL ENVIRONMENT HEALTH CHECK..."
Start-Sleep -Seconds 3
$portCheck = Test-NetConnection -ComputerName "localhost" -Port 80 -WarningAction SilentlyContinue
if ($portCheck.TcpTestSucceeded) {
    $healthStatus = "PASSED (Port 80 responding cleanly)"
} else {
    $healthStatus = "WARNING (Port 80 not responding yet)"
}

# Stop execution timer and calculate performance benchmarking speeds
$pipelineStopwatch.Stop()
$executionDuration = [math]::Round($pipelineStopwatch.Elapsed.TotalSeconds, 2)
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

# 7. Stage 5: Dispatch Automated Slack Telemetry Card
Write-Output "STAGE 5 OF 5: Dispatching instant telemetry alert to Slack..."
if (Test-Path "./webhook.json") {
    $settings = Get-Content "./webhook.json" | ConvertFrom-Json
    $slackWebhookUrl = $settings.SLACK_WEBHOOK_URL
} else {
    Write-Error "Missing webhook.json file! Cannot dispatch Slack alert."
    Exit
}

$textPayload = "*=== KUBERNETES DEPLOYMENT ROLLOUT SUCCESSFUL ===*" + "`n`n" +
               "*Deployment Status:* Active & Rolling" + "`n" +
               "*Cluster Health Check:* " + $healthStatus + "`n" +
               "*Total Processing Velocity:* " + $executionDuration + " seconds" + "`n" +
               "*Local Endpoint URL:* http://localhost" + "`n`n" +
               "--------------------------------------------------" + "`n" +
               "*PIPELINE METRICS LOGS*" + "`n" +
               "> *Operator:* Sujey Hariprasad" + "`n" +
               "> *Cluster Environment:* Local Desktop Node (default)" + "`n" +
               "> *Helm Chart Release:* expo-web-release" + "`n" +
               "> *Unique Build Tag:* " + $buildTag + "`n" +
               "> *Git Sync Message:* " + $customMessage + "`n" +
               "--------------------------------------------------" + "`n`n" +
               "_Telemetry Sync Complete: " + $timestamp + "_"

$bodyObject = @{ text = $textPayload }
try {
    $null = Invoke-RestMethod -Uri $slackWebhookUrl -Method Post -Body ($bodyObject | ConvertTo-Json) -ContentType "application/json; charset=utf-8"
} catch {
    Write-Error "Slack API failed: $_"
}

Write-Output ""
Write-Output "SUCCESS: Local server is updated. Total pipeline execution velocity: $executionDuration seconds."
Write-Output "--------------------------------------------------"

# FINAL STEP AUTOMATION: Spawn another fresh, separate PowerShell window to boot your frontend app and load it inside the browser automatically
Write-Output "LAUNCHING EXPO MOBILE INTERFACE CONSOLE IN SEPARATE POWERSHELL..."
Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "Clear-Host; Write-Host 'LAUNCHING EXPO MOBILE FRONTEND INTERFACE...' -ForegroundColor Blue; npx expo start -w"