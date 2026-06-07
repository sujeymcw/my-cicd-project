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

# Slack sender function to prevent invalid_payload errors
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

# HARD PORT CLEANER FUNCTION
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

# EXPO AUTOMATED PORT FUNCTION
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

# AUTOMATION 1: Aggressive process execution wipe to clear port 8000 permanently
Write-Output "PERFORMING HARD SCRUB ON PORT 8000 AND LAUNCHING BACKEND..."
Clear-Port8000

# Spawn the separate window, set location strictly to the root project folder, and launch the backend cleanly
Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "Clear-Host; Set-Location '$PSScriptRoot'; Write-Host 'LAUNCHING CONTROL PLANE BACKEND BRIDGE ENGINE...' -ForegroundColor Cyan; python dashboard_backend.py"

Write-Output "Waiting 5 seconds for backend API server to bind cleanly to port 8000..."
Start-Sleep -Seconds 5

Write-Output "STARTING INSTANT GITOPS PIPELINE ROLLOUT..."

# Reusable Emergency Gatekeeper Function for Pipeline Safety
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

    # EMERGENCY FALLBACK: Navigate to 'src' in a separate window and open Expo for debugging
    Write-Output "LAUNCHING EXPO MOBILE INTERFACE CONSOLE IN SEPARATE POWERSHELL..."
    Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "Clear-Host; Set-Location '$PSScriptRoot\src'; Write-Host 'LAUNCHING EXPO MOBILE FRONTEND INTERFACE ON PORT $expoPort...' -ForegroundColor Blue; npx expo start -w --port $expoPort --non-interactive"
    Exit
}

# 2. Stage 1: Sync with GitHub Tracking Repository
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
if ($LASTEXITCODE -ne 0) {
    Send-SlackFailure "STAGE 2 (Docker Build)" "Compilation failed inside the Dockerfile environment layers."
}

# 4. Stage 3: Helm Chart Manifest Deployments
Write-Output "STAGE 3 OF 5: Launching independent terminal for Helm Chart status outputs..."
helm upgrade --install expo-web-release ./charts/my-web-app --set image.repository="sujeymcw/expo-web-app" --set image.tag=$buildTag --set image.imagePullPolicy="IfNotPresent" --set service.type="LoadBalancer" --set service.port=80 --namespace default > $null
if ($LASTEXITCODE -ne 0) {
    Send-SlackFailure "STAGE 3 (Helm Upgrade)" "Helm manifest configuration parsing rejected by the target cluster."
}

Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "Clear-Host; Set-Location '$PSScriptRoot'; Write-Host 'MONITORING ACTIVE HELM RELEASE STATUS...' -ForegroundColor Green; helm status expo-web-release --namespace default"

# 5. Stage 4: Kubectl Rolling Pod Update
Write-Output "STAGE 4 OF 5: Triggering instantaneous rolling update on cluster pods..."
kubectl rollout restart deployment/expo-web-deployment --namespace default
if ($LASTEXITCODE -ne 0) {
    Send-SlackFailure "STAGE 4 (Kubectl Rollout)" "Deployment target missing or pod template scheduling initialization failed."
}

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

$textPayload = "*=== KUBERNETES DEPLOYMENT ROLLOUT SUCCESSFUL ===*" + "`n`n" +
               "*Deployment Status:* Active & Rolling" + "`n" +
               "*Cluster Health Check:* " + $healthStatus + "`n" +
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
Write-Output "--------------------------------------------------"

# AUTOMATION 2: Open Expo development suite completely inside its standalone window environment tail
Write-Output "LAUNCHING EXPO MOBILE INTERFACE CONSOLE IN SEPARATE POWERSHELL..."
Start-Process powershell.exe -ArgumentList "-NoExit", "-Command", "Clear-Host; Set-Location '$PSScriptRoot\src'; Write-Host 'LAUNCHING FRONTEND INTERFACE ON PORT $expoPort...' -ForegroundColor Blue; npx expo start -w --port $expoPort --non-interactive"