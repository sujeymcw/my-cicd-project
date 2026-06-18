# 🚀 DevOps Control Plane & Automated CI/CD Pipeline

Enterprise-grade GitOps platform for automating containerized application delivery, Kubernetes orchestration, observability, deployment reporting, and infrastructure telemetry.

---

# 📌 Overview

This project implements a complete DevOps automation ecosystem that transforms a simple Git push into a fully deployed Kubernetes workload with integrated monitoring, reporting, alerting, and dashboard generation.

The platform combines:

* GitHub Actions CI/CD
* Docker Image Automation
* Helm-Based Kubernetes Deployments
* Prometheus Monitoring
* Grafana Dashboards
* Slack Notifications
* Outlook Deployment Reports
* Automated Infrastructure Auditing

---

# 🏗️ System Architecture

```text
Developer
    │
    ▼
Git Push
    │
    ▼
GitHub Actions
    │
    ├── Docker Build
    ├── Docker Push
    ├── Helm Deployment
    ├── Kubernetes Rollout
    ├── Metrics Collection
    ├── Prometheus Setup
    ├── Grafana Setup
    └── Report Generation
    │
    ▼
Kubernetes Cluster
    │
    ├── Application Pods
    ├── Services
    ├── Metrics Server
    ├── Prometheus
    └── Grafana
```

---

# ⚙️ Core Components

| Component            | Technology        | Purpose                       |
| -------------------- | ----------------- | ----------------------------- |
| 🚢 Pipeline Engine   | PowerShell        | Orchestrates CI/CD workflow   |
| 🐳 Container Runtime | Docker            | Builds and distributes images |
| ☸️ Orchestrator      | Kubernetes        | Runs workloads                |
| ⛵ Package Manager    | Helm              | Application deployment        |
| 📊 Metrics Layer     | Metrics Server    | Resource collection           |
| 📈 Monitoring        | Prometheus        | Metrics aggregation           |
| 📉 Visualization     | Grafana           | Dashboard rendering           |
| 🔔 Notifications     | Slack             | Failure alerts                |
| 📧 Reporting         | Outlook           | Deployment reports            |
| 🖥️ Backend API      | Python FastAPI    | Cluster telemetry bridge      |
| 📱 Control Deck      | React Native Expo | Live monitoring dashboard     |

---

# 🔄 CI/CD Workflow

```text
Git Push
   │
   ▼
Docker Build
   │
   ▼
Docker Push
   │
   ▼
Helm Upgrade
   │
   ▼
Kubernetes Deployment
   │
   ▼
Metrics Collection
   │
   ▼
Prometheus Installation
   │
   ▼
Grafana Dashboard Creation
   │
   ▼
Audit Report Generation
```

---

# 🚀 Automated Deployment Stages

| Stage | Description                     |
| ----- | ------------------------------- |
| 1️⃣   | Git repository synchronization  |
| 2️⃣   | Docker image build              |
| 3️⃣   | Docker registry push            |
| 4️⃣   | Helm deployment                 |
| 5️⃣   | Kubernetes rollout verification |
| 6️⃣   | Metrics Server validation       |
| 7️⃣   | Prometheus installation         |
| 8️⃣   | Grafana deployment              |
| 9️⃣   | Dashboard provisioning          |
| 🔟    | Infrastructure auditing         |

---

# 🛡️ Reliability Features

### Error Isolation

Every stage validates execution status before proceeding.

```powershell
if ($LASTEXITCODE -ne 0) {
    Send-SlackFailure
    exit 1
}
```

### Automatic Failure Protection

When any stage fails:

✅ Deployment stops immediately

✅ Slack alert is generated

✅ Invalid release is blocked

✅ Cluster integrity remains protected

---

# 🖥️ Multi-Process Runtime Architecture

The PowerShell controller automatically launches isolated execution environments.

| Window         | Purpose            |
| -------------- | ------------------ |
| 🖥️ Terminal 1 | CI/CD Pipeline     |
| 🌐 Terminal 2  | Python Backend API |
| 📱 Terminal 3  | Expo Dashboard     |

---

# 🔥 Automatic Port Management

### Backend API

Before launching:

* Detects existing processes on port 8000
* Terminates conflicting PIDs
* Prevents WinError 10048

### Expo Frontend

Automatically scans:

```text
8081
8082
8083
8084
8085
8090
8091
8092
19000
19001
19002
```

and selects the first available port.

---

# 📊 Kubernetes Monitoring Stack

## Metrics Server

Collects:

* Node CPU Usage
* Node Memory Usage
* Pod CPU Usage
* Pod Memory Usage

---

## Prometheus

Monitors:

* Cluster Nodes
* Pod Metrics
* Deployments
* Services
* Resource Consumption
* Kubernetes Events

---

## Grafana

Generates live dashboards for:

| Dashboard Panel   | Description           |
| ----------------- | --------------------- |
| 🟢 Running Pods   | Active workload count |
| 🖥️ Cluster Nodes | Available nodes       |
| 📈 CPU Usage      | Node CPU consumption  |
| 📉 Memory Usage   | Node RAM consumption  |
| 📦 Pod CPU        | Per-pod utilization   |
| 📦 Pod Memory     | Per-pod memory usage  |

---

# 📁 Generated Deployment Artifacts

After every deployment:

### 1️⃣ helm-chart-output.yaml

Contains:

* Helm Template Output
* Helm Status
* Kubernetes Resources
* Deployments
* Pods
* Services
* Metrics
* Cluster Information

---

### 2️⃣ observability-audit-report.yaml

Contains:

* Monitoring Validation
* Prometheus Health
* Grafana Health
* Metrics Verification
* Cluster Events
* Resource Utilization

---

### 3️⃣ actual-grafana-dashboard.png

Real dashboard screenshot automatically captured using Playwright.

---

# 📧 Automated Notifications

## Slack Alerts

### Success

```text
Deployment Successful
Docker Image
Running Pods
Execution Time
Helm Output File
```

### Failure

```text
Broken Stage
Error Details
Failure Timestamp
```

---

## Outlook Reports

Deployment completion automatically sends:

* Deployment Status
* Docker Image
* Running Pods
* Helm Release
* Namespace
* Execution Duration
* Attached Helm Report

---

# 📋 Prerequisites

Install the following tools:

| Tool    | Verify           |
| ------- | ---------------- |
| Git     | git --version    |
| Docker  | docker --version |
| Kubectl | kubectl version  |
| Helm    | helm version     |
| Python  | python --version |
| Node.js | node --version   |

---

# ▶️ Running Locally

```powershell
.\ship.ps1
```

Pipeline Flow:

```text
Git Commit
    ↓
Git Push
    ↓
Docker Build
    ↓
Docker Push
    ↓
Helm Upgrade
    ↓
Kubernetes Rollout
    ↓
Metrics Collection
    ↓
Prometheus
    ↓
Grafana
    ↓
Audit Reports
```

---

# 📈 Observability Features

✅ Real-Time Node Metrics

✅ Real-Time Pod Metrics

✅ Dashboard Auto-Provisioning

✅ Metrics Server Validation

✅ Cluster Event Tracking

✅ Resource Allocation Analysis

✅ Health Endpoint Validation

✅ Screenshot Capture Automation

---

# 🎯 Key Highlights

* 🚀 Fully Automated GitOps Workflow
* ☸️ Kubernetes Native Deployments
* 🐳 Docker Registry Integration
* 📊 Prometheus Monitoring
* 📈 Grafana Visualization
* 📧 Outlook Reporting
* 🔔 Slack Alerting
* 📁 Automated Audit Reports
* 🛡️ Failure Protection Mechanism
* ⚡ Zero-Touch Deployment Process

---

# 👨‍💻 Author

**Sujey Hariprasad**

B.E Computer Science Engineering
Cloud Architect Intern @ MulticoreWare
Full Stack Developer | DevOps Enthusiast | KAAVAL Hackathon Winner

---

## ⭐ One-Line Summary

**A complete GitOps-powered DevOps platform that automates Docker builds, Kubernetes deployments, observability provisioning, infrastructure auditing, and deployment reporting from a single Git push.**
