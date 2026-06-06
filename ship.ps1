# 1. Generate a crisp timestamp-based unique build tag identifier
$buildTag = "local-" + (Get-Date -Format "yyyyMMdd-HHmmss")

Write-Output "STARTING INSTANT GITOPS PIPELINE ROLLOUT..."

# 2. Automatically push your code updates to your GitHub tracking repo in the background
Write-Output "STAGE 1 OF 4: Syncing source files with Git Repository..."
git add .
git commit -m "style: rapid telemetry interface deployment sync" --quiet
git push origin main --quiet

# 3. Compile and inject the image straight into your active Kubernetes node registry
Write-Output "STAGE 2 OF 4: Baking Docker Image layers directly into local cluster nodes..."
# Corrected: -f points to Dockerfile in root, context is . so it sees package.json and src/
docker build -f ./Dockerfile -t sujeymcw/expo-web-app:$buildTag . --quiet

# 4. Fire the Helm upgrade configuration immediately with no cloud delays
Write-Output "STAGE 3 OF 4: Executing immediate Helm Chart upgrade parameters..."
helm upgrade --install expo-web-release ./charts/my-web-app --set image.repository="sujeymcw/expo-web-app" --set image.tag=$buildTag --set image.imagePullPolicy="IfNotPresent" --set service.type="LoadBalancer" --set service.port=80 --namespace default

# 5. Force the active Kubernetes deployment configurations to swap the containers open instantly
Write-Output "STAGE 4 OF 4: Triggering instantaneous rolling update on cluster pods..."
# Target layout name matching your active cluster resource name
kubectl rollout restart deployment/expo-web-deployment --namespace default

Write-Output "SUCCESS: Local server is updated. Refresh your Control Plane UI!"