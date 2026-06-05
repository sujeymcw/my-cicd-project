# 1. Capture the unique commit tag hash before pushing
$gitHash = git rev-parse --short HEAD

Write-Host "🚀 1/3: Pushing fresh UI changes to GitHub..." -ForegroundColor Cyan
git add .
git commit -m "auto: pipeline sync deployment"
git push origin main

Write-Host "⏳ 2/3: Pausing for 60 seconds to let the GitHub Actions build complete..." -ForegroundColor Yellow
Start-Sleep -Seconds 60

Write-Host "⛵ 3/3: Executing Helm rollout to local Kubernetes pods..." -ForegroundColor Green
helm upgrade --install expo-web-release ./charts/my-web-app --set image.repository="sujeymcw/expo-web-app" --set image.tag=$gitHash --namespace default

Write-Host "🎯 Done! Hit 'Force Telemetry Sync' on your dashboard to see it live!" -ForegroundColor Magenta