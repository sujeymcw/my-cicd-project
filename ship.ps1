# 1. Generate a crisp timestamp-based unique build tag identifier
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

# 2. Automatically push your code updates to your GitHub tracking repo in the background
Write-Output "STAGE 1 OF 5: Syncing source files with Git Repository..."
git add .
git commit -m "$customMessage" --quiet
git push origin main --quiet

# 3. Compile and inject the image straight into your active Kubernetes node registry
Write-Output "STAGE 2 OF 5: Baking Docker Image layers directly into local cluster nodes..."
docker build -f ./Dockerfile -t sujeymcw/expo-web-app:$buildTag . --quiet

# 4. Fire the Helm upgrade configuration immediately and spawn a new terminal window for the outputs
Write-Output "STAGE 3 OF 5: Launching independent terminal for Helm Chart status outputs..."
helm upgrade --install expo-web-release ./charts/my-web-app --set image.repository="sujeymcw/expo-web-app" --set image.tag=$buildTag --set image.imagePullPolicy="IfNotPresent" --set service.type="LoadBalancer" --set service.port=80 --namespace default > $null
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Clear-Host; helm status expo-web-release --namespace default"

# 5. Force the active Kubernetes deployment configurations to swap the containers open instantly
Write-Output "STAGE 4 OF 5: Triggering instantaneous rolling update on cluster pods..."
kubectl rollout restart deployment/expo-web-deployment --namespace default

# 6. Shoot the Automated Slack Telemetry Card to your Sandbox Channel
Write-Output "STAGE 5 OF 5: Dispatching instant telemetry alert to Slack via curl stream..."

# Dynamically parse the secret webhook from your untracked local file
if (Test-Path "./webhook.json") {
    $settings = Get-Content "./webhook.json" | ConvertFrom-Json
    $slackWebhookUrl = $settings.SLACK_WEBHOOK_URL
} else {
    Write-Error "Missing webhook.json file! Cannot dispatch Slack alert."
    Exit
}

# Simplified, flat text payload string using robust formatting markdown
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$textPayload = @"
*🚀 Deployment Rollout Successful*
The local Kubernetes cluster environment has successfully processed a rolling update step.

• *Operator:* Sujey Hariprasad
• *Build Tag:* $buildTag
• *Environment:* Local Cluster (default)
• *Helm Release:* expo-web-release
• *Commit Message:* $customMessage
• *Access URL:* http://localhost  •  *Time Sync:* $timestamp
"@

# Build the payload object and compress it to JSON
$payloadObject = @{ text = $textPayload }
$jsonPayload = ConvertTo-Json $payloadObject -Compress

# NEW: Save the payload out to a temporary local file using explicit UTF-8 encoding without BOM
$tempPayloadPath = Join-Path $env:TEMP "slack_payload.json"

[System.IO.File]::WriteAllText(
    $tempPayloadPath,
    $jsonPayload,
    [System.Text.UTF8Encoding]::new($false)
)

# NEW: Tell curl to read directly from the file path using the '@' prefix
curl.exe -X POST `
  -H "Content-Type: application/json" `
  --data-binary "@$tempPayloadPath" `
  $slackWebhookUrl

# Clean up the temporary payload file after execution
if (Test-Path $tempPayloadPath) {
    Remove-Item $tempPayloadPath -Force
}

Write-Output ""
Write-Output "SUCCESS: Local server is updated. Inspect the newly opened Helm terminal and refresh your Control Plane UI!"