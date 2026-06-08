# GitOps Control Plane & Automated CI/CD Pipeline

An enterprise-grade orchestration system designed to automate full-stack container compilation, validation testing, remote repository state tracking, and cloud-native rolling deployments onto a managed Kubernetes cluster.

---

## 🏗️ Core Architecture Overview

The system bridges local infrastructure runtimes with remote cloud telemetry endpoints. It is split cleanly into a backend management bridge, a responsive mobile-first monitoring control deck, and an asynchronous task pipeline.

### Component Map
* **Pipeline Engine (`ship.ps1`)**: A master PowerShell controller managing continuous integration and delivery.
* **Telemetry Server (`dashboard_backend.py`)**: A Python-based REST API aggregating cluster states, resource usage, and health parameters.
* **Control Deck App (`src/App.js`)**: A cross-platform Expo React Native dashboard displaying live performance metrics and orchestration actions.

---

## 🕹️ Deep Dive: Core Orchestration Mechanics

### 1. Multi-Window Infrastructure Spawning
To isolate execution logging environments, `ship.ps1` runs concurrently across independent sub-shells via native Win32 processes:
* **Terminal 1 (Host)**: Executes code syntax compilation, image registry uploading, and performance timing tracking.
* **Terminal 2 (API Bridge)**: Spawns the persistent Python API layer. It automatically clears conflicts on port `8000` via active PID termination checks to prevent networking bind failures (`WinError 10048`).
* **Terminal 3 (Frontend)**: Evaluates environment parameters, scans local TCP sockets to locate a vacant fallback runtime port (`8081`–`8099`), navigates directly to the decoupled `\src` workspace, and initiates the Expo compiler.

### 2. Guarded Termination Rules (Error Trapping)
The automation pipeline implements an anti-fragile, zero-leak validation design pattern. Every execution phase is isolated using native `$LASTEXITCODE` assessment guards:
* If a critical error occurs (e.g., syntax validation breaks in the `Dockerfile`, a network drop drops the GitHub mirror push, or a Helm chart evaluation fails), execution ceases **immediately**.
* The pipeline interrupts the workflow loop, blocking corrupted code modifications or broken image references from reaching the production Kubernetes cluster layout.
* The system invokes an emergency exit hook (`Send-SlackFailure`), compiling raw terminal errors into a bright red alert dispatched to the engineering team's Slack channel.

### 3. Integrated Diagnostics Log Engine
At step 5 of the continuous delivery phase, the script aggregates multi-tier logging outputs into a unified, version-controlled yaml logfile (`helm-chart-output.yaml`). It explicitly parses:
* Rendered Helm chart templates (`helm template`)
* Live Release status states and values mappings (`helm status`, `helm get values`)
* Low-level cluster specifications (`kubectl get deployment`, `kubectl get pods -o wide`)
* Container compute loads (`kubectl top pods`, `kubectl top nodes`)

---

## 🚀 Execution Guide

### Prerequisites
Ensure your terminal session possesses cluster administrative rights and the following dependencies are globally active in your environment path:
```bash
git --version
docker --version
helm version
kubectl version
presentation with prem