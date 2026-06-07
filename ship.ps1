# 1. Start the performance benchmark stopwatch to calculate execution velocity
$pipelineStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$buildTag = "local-" + (Get-Date -Format "yyyyMMdd-HHmmss")

# Prompt the user for a custom commit message right at launch
Write-Output "--------------------------------------------------"
$customMessage = Read-Host "Enter your commit/deployment message"
Write-Output "--------------------------------------------------"

# Fallback to a default message if you just press Enter
if ([string]::IsNullOrWhiteSpace($customMessage)) {
    $customMessage = "style: rapid telemetry interface deployment sync"
}

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
    Exit
}

# 2. Automatically push your code updates to your GitHub tracking repo in the background
Write-Output "STAGE 1 OF 5: Syncing source files with Git Repository..."
git add .
git commit -m "$customMessage" --quiet
git push origin main --quiet
if (-not $?) { Send-SlackFailure "STAGE 1 (Git Sync)" "Repository push rejected or upstream remote server unavailable." }

# 3. Compile and inject the image straight into your active Kubernetes node registry
Write-Output "STAGE 2 OF 5: Baking Docker Image layers directly into local cluster nodes..."
docker build -f ./Dockerfile -t sujeymcw/expo-web-app:$buildTag . --quiet
if (-not $?) { Send-SlackFailure "STAGE 2 (Docker Build)" "Compilation failed inside the Dockerfile environment layers." }

# 4. Fire the Helm upgrade configuration immediately and spawn a new terminal window for the outputs
Write-Output "STAGE 3 OF 5: Launching independent terminal for Helm Chart status outputs..."
helm upgrade --install expo-web-release ./charts/my-web-app --set image.repository="sujeymcw/expo-web-app" --set image.tag=$buildTag --set image.imagePullPolicy="IfNotPresent" --set service.type="LoadBalancer" --set service.port=80 --namespace default > $null
if (-not $?) { Send-SlackFailure "STAGE 3 (Helm Upgrade)" "Helm manifest configuration parsing rejected by the target cluster." }
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Clear-Host; helm status expo-web-release --namespace default"

# 5. Force the active Kubernetes deployment configurations to swap the containers open instantly
Write-Output "STAGE 4 OF 5: Triggering instantaneous rolling update on cluster pods..."
kubectl rollout restart deployment/expo-web-deployment --namespace default
if (-not $?) { Send-SlackFailure "STAGE 4 (Kubectl Rollout)" "Deployment target missing or pod template scheduling initialization failed." }

# 6. Active Cluster Networking Health Probe
Write-Output "RUNNING OPERATIONAL ENVIRONMENT HEALTH CHECK..."
Start-Sleep -Seconds 3 # Give pods a brief moment to cycle open
$portCheck = Test-NetConnection -ComputerName "localhost" -Port 80 -WarningAction SilentlyContinue
if ($portCheck.TcpTestSucceeded) {
    $healthStatus = "PASSED (Port 80 responding cleanly)"
} else {
    $healthStatus = "WARNING (Port 80 not responding yet)"
}

# Stop execution timer and capture final time metric metrics
$pipelineStopwatch.Stop()
$executionDuration = [math]::Round($pipelineStopwatch.Elapsed.TotalSeconds, 2)
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

# 7. Shoot the Automated Slack Telemetry Card to your Sandbox Channel
Write-Output "STAGE 5 OF 5: Dispatching instant telemetry alert to Slack..."

# Dynamically parse the secret webhook from your untracked local file
if (Test-Path "./webhook.json") {
    $settings = Get-Content "./webhook.json" | ConvertFrom-Json
    $slackWebhookUrl = $settings.SLACK_WEBHOOK_URL
} else {
    Write-Error "Missing webhook.json file! Cannot dispatch Slack alert."
    Exit
}

# Advanced metrics dashboard text aggregation layout payload
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

# Create a native PowerShell body object
$bodyObject = @{ text = $textPayload }

# Fire the webhook directly using native PowerShell memory processing
try {
    $response = Invoke-RestMethod -Uri $slackWebhookUrl -Method Post -Body ($bodyObject | ConvertTo-Json) -ContentType "application/json; charset=utf-8"
} catch {
    Write-Error "Slack API failed: $_"
}

Write-Output ""
Write-Output "SUCCESS: Local server is updated. Inspect the newly opened Helm terminal and refresh your Control Plane UI!"
Write-Output "Total execution processing velocity completed in $executionDuration seconds."