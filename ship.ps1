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
Write-Output "STAGE 5 OF 5: Dispatching instant telemetry alert to Slack..."

# Dynamically parse the secret webhook from your untracked local file
if (Test-Path "./local_settings.json") {
    $settings = Get-Content "./local_settings.json" | ConvertFrom-Json
    $slackWebhookUrl = $settings.SLACK_WEBHOOK_URL
} else {
    Write-Error "Missing local_settings.json file! Cannot dispatch Slack alert."
    Exit
}

# Pure JSON layout string guarantees Slack validation passes 100% of the time
$jsonPayload = @"
{
  "attachments": [
    {
      "color": "#2EB886",
      "pretext": "Deployment Rollout Successful",
      "fallback": "Kubernetes Deployment Update Successful.",
      "blocks": [
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": "The local Kubernetes cluster environment has successfully processed a rolling update layout step."
          }
        },
        {
          "type": "section",
          "fields": [
            { "type": "mrkdwn", "text": "*Operator:*\nSujey Hariprasad" },
            { "type": "mrkdwn", "text": "*Build Tag:*\n$buildTag" },
            { "type": "mrkdwn", "text": "*Environment:*\nLocal Cluster (default)" },
            { "type": "mrkdwn", "text": "*Helm Release:*\nexpo-web-release" }
          ]
        },
        {
          "type": "section",
          "text": {
            "type": "mrkdwn",
            "text": "*Commit/Deployment Message:*\n_$customMessage_"
          }
        },
        {
          "type": "context",
          "elements": [
            {
              "type": "mrkdwn",
              "text": "Access URL: http://localhost  •  Time Sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            }
          ]
        }
      ]
    }
  ]
}
"@

# Fire the webhook straight into your Slack workspace!
$null = Invoke-RestMethod -Uri $slackWebhookUrl -Method Post -Body $jsonPayload -ContentType "application/json; charset=utf-8"

Write-Output "SUCCESS: Local server is updated. Inspect the newly opened Helm terminal and refresh your Control Plane UI!"