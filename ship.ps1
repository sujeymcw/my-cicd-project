# ============================================================
# ship.ps1 - Notification Dispatcher Only
# Reads deployment state written by the CI/CD pipeline and
# sends Slack + Outlook notifications. No build, deploy, or
# cluster operations are performed here.
# ============================================================

$ErrorActionPreference = "Stop"

# ---- Load deployment state written by the pipeline ----
$stateFile = "./deploy-state.json"

if (-not (Test-Path $stateFile)) {
    Write-Error "deploy-state.json not found. Run the main pipeline first."
    exit 1
}

$state = Get-Content $stateFile | ConvertFrom-Json

$dockerImage      = $state.dockerImage
$buildTag         = $state.buildTag
$helmRelease      = $state.helmRelease
$namespace        = $state.namespace
$helmChartPath    = $state.helmChartPath
$podCount         = $state.podCount
$expoPort         = $state.expoPort
$executionDuration = $state.executionDuration
$helmChartOutputFile = $state.helmChartOutputFile

$outlookTo      = "sujey.hariprasad@multicorewareinc.com"
$outlookSubject = "CICD Deployment Successful - $helmRelease - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# ============================================================
# Slack
# ============================================================
function Send-SlackMessage {
    param ([string]$messageText)

    if (Test-Path "./webhook.json") {
        $settings        = Get-Content "./webhook.json" | ConvertFrom-Json
        $slackWebhookUrl = $settings.SLACK_WEBHOOK_URL.Trim()

        $bodyObject = @{ text = $messageText }
        $jsonBody   = $bodyObject | ConvertTo-Json -Compress

        Invoke-RestMethod `
            -Uri         $slackWebhookUrl `
            -Method      Post `
            -Body        $jsonBody `
            -ContentType "application/json; charset=utf-8"
    } else {
        Write-Host "webhook.json not found — Slack notification skipped." -ForegroundColor Yellow
    }
}

# ============================================================
# Outlook
# ============================================================
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
            Write-Host "Outlook mail skipped — attachment not found: $AttachmentPath" -ForegroundColor Yellow
            return
        }

        $resolvedAttachment = (Resolve-Path $AttachmentPath).Path
        $generatedAt        = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        $outlook = New-Object -ComObject Outlook.Application
        $mail    = $outlook.CreateItem(0)

        $mail.To      = $To
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
<tr><td><b>Docker Image</b></td><td>${DockerImage}:${ImageTag}</td></tr>
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
<p>Regards,<br/><b>Automated DevOps Deployment Pipeline</b></p>

</body>
</html>
"@

        $mail.Attachments.Add($resolvedAttachment)
        $mail.Send()

        Write-Host "Outlook mail sent to $To" -ForegroundColor Green
    } catch {
        Write-Host "Outlook mail failed: $_" -ForegroundColor Yellow
    }
}

# ============================================================
# Send notifications
# ============================================================
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

Write-Output ""
Write-Output "Dispatching Slack notification..."

$slackPayload = "*=== KUBERNETES DEPLOYMENT ROLLOUT SUCCESSFUL ===*" + "`n`n" +
    "*Deployment Status:* Active" + "`n" +
    "*Docker Image:* ${dockerImage}:$buildTag" + "`n" +
    "*Running Pods:* $podCount" + "`n" +
    "*Helm Output File:* $helmChartOutputFile" + "`n" +
    "*Expo Frontend Port:* $expoPort" + "`n" +
    "*Total Time:* $executionDuration seconds" + "`n" +
    "*Workflow:* Git Push -> Build Image -> Push Registry -> Helm Upgrade -> Kubernetes Deployment" + "`n" +
    "_Telemetry Sync Complete: $timestamp_"

try {
    Send-SlackMessage $slackPayload
} catch {
    Write-Host "Slack notification failed: $_" -ForegroundColor Yellow
}

Write-Output ""
Write-Output "Dispatching Outlook notification..."

Send-OutlookDeploymentMail `
    -To               $outlookTo `
    -Subject          $outlookSubject `
    -DockerImage      $dockerImage `
    -ImageTag         $buildTag `
    -HelmRelease      $helmRelease `
    -Namespace        $namespace `
    -ChartPath        $helmChartPath `
    -AttachmentPath   $helmChartOutputFile `
    -DeploymentStatus "Successful" `
    -PodCount         $podCount `
    -ExpoPort         $expoPort `
    -ExecutionDuration $executionDuration

Write-Output ""
Write-Output "--------------------------------------------------"
Write-Output "Notifications dispatched."
Write-Output "--------------------------------------------------"