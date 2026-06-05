from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import subprocess
import json
import re
import urllib.request

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def run_command(cmd):
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.stdout.strip()
    except Exception as e:
        return str(e)

def get_docker_hub_tags():
    # Fetch live tag registry details from official Docker Hub public API
    url = "https://hub.docker.com/v2/repositories/sujeymcw/expo-web-app/tags/?page_size=3"
    try:
        response = urllib.request.urlopen(url, timeout=3)
        data = json.loads(response.read().decode())
        tags_list = []
        for result in data.get("results", []):
            tags_list.append({
                "name": result.get("name"),
                "size": f"{round(result.get('full_size', 0) / (1024*1024), 2)} MB",
                "pushed": result.get("last_updated", "")[:10]
            })
        return tags_list
    except Exception as e:
        return [{"name": "Error fetching registry", "size": "N/A", "pushed": "N/A"}]

@app.get("/api/metrics")
def get_dashboard_data():
    # 1. Fetch Live Pod Status
    pod_output = run_command("kubectl get pods -l app=expo-web-app -o json")
    pod_count = 0
    pod_status = "Offline"
    restarts = 0
    try:
        pod_data = json.loads(pod_output)
        if pod_data.get("items"):
            pod_count = len(pod_data["items"])
            pod_status = pod_data["items"][0]["status"]["phase"]
            restarts = pod_data["items"][0]["status"]["containerStatuses"][0]["restartCount"]
    except:
        pass

    # 2. Fetch Live Helm Status
    helm_output = run_command("helm list --namespace default -o json")
    helm_version = "v1.0.0"
    helm_status = "Unknown"
    try:
        helm_data = json.loads(helm_output)
        for release in helm_data:
            if release["name"] == "expo-web-release":
                helm_version = release["chart"]
                helm_status = release["status"]
    except:
        pass

    # 3. Fetch Live Resource Performance
    top_output = run_command("kubectl top pod -l app=expo-web-app")
    cpu_usage = "12m"
    memory_usage = "24Mi"
    if top_output and "NAME" not in top_output:
        lines = top_output.split("\n")
        if len(lines) > 1:
            parts = re.split(r'\s+', lines[1])
            if len(parts) >= 3:
                cpu_usage = parts[1]
                memory_usage = parts[2]

    # 4. Fetch Git Repo Metadata
    git_sha = run_command("git rev-parse --short HEAD") or "Unknown"
    git_branch = run_command("git rev-parse --abbrev-ref HEAD") or "main"
    git_msg = run_command("git log -1 --pretty=%B") or "Initial setup"

    # 5. Fetch Docker Hub Registry History
    docker_tags = get_docker_hub_tags()

    return {
        "repository": {
            "provider": "GitHub",
            "branch": git_branch,
            "commitSha": git_sha,
            "lastCommitMessage": git_msg
        },
        "cluster": {
            "activePods": pod_count,
            "status": pod_status,
            "restarts": restarts
        },
        "resources": {
            "cpu": cpu_usage,
            "memory": memory_usage
        },
        "helm": {
            "chartName": helm_version,
            "status": helm_status
        },
        "dockerHubHistory": docker_tags
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)