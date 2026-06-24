# Project Documentation — Cloud & DevOps Final Project
**Student:** Abdalhakim Elghweiry  
**Date built:** 2026-06-24  
**Repo:** `AbdalhakimElghweiry/Cloud-And-DevOps-Final-Project`  
**Azure subscription:** Azure for Students ($100 credit)

---

## Table of Contents

1. [Tool Version Check](#1-tool-version-check)
2. [Project Overview](#2-project-overview)
3. [Architecture](#3-architecture)
4. [Full File Tree](#4-full-file-tree)
5. [Section 1 — Application](#5-section-1--application)
   - [app/index.js](#appindexjs)
   - [app/package.json](#apppackagejson)
   - [Dockerfile](#dockerfile)
   - [.dockerignore](#dockerignore)
6. [Section 2 — Terraform](#6-section-2--terraform)
   - [terraform/providers.tf](#terraformproviderstf)
   - [terraform/variables.tf](#terraformvariablestf)
   - [terraform/main.tf](#terraformmaintf)
   - [terraform/outputs.tf](#terraformoutputstf)
7. [Section 3 — Kubernetes Manifests](#7-section-3--kubernetes-manifests)
   - [k8s/deployment.yaml](#k8sdeploymentyaml)
   - [k8s/service.yaml](#k8sserviceyaml)
8. [Section 4 — GitHub Actions CI/CD](#8-section-4--github-actions-cicd)
   - [.github/workflows/ci-cd.yml](#githubworkflowsci-cdyml)
9. [Section 5 — Supporting Files](#9-section-5--supporting-files)
   - [.gitignore](#gitignore)
   - [README.md](#readmemd)
10. [Key Design Decisions](#10-key-design-decisions)
11. [Setup & Deployment Guide](#11-setup--deployment-guide)
12. [GitHub Secrets Reference](#12-github-secrets-reference)
13. [Screenshot Checklist](#13-screenshot-checklist)
14. [Billing & Cleanup](#14-billing--cleanup)

---

## 1. Tool Version Check

Before any work began, every required tool was verified on the local Windows 11 machine. All passed — no PATH issues found.

| Tool | Version confirmed | Status |
|---|---|---|
| git | 2.54.0.windows.1 | OK |
| docker | 29.5.3 | OK |
| terraform | 1.9.8 | OK |
| azure-cli | 2.87.0 | OK |
| kubectl (client) | 1.34.1 | OK |

Commands used:
```powershell
git --version
docker --version
terraform --version
az --version
kubectl version --client
```

Azure login status was also verified — subscription "Azure for Students" is active and enabled.

---

## 2. Project Overview

A Node.js web application that displays the student's name is containerised with Docker, its infrastructure is provisioned on Azure with Terraform, and it is continuously delivered to Azure Kubernetes Service via a three-job GitHub Actions pipeline that includes a manual approval gate before every production deployment.

**No credentials are stored anywhere in the codebase.** AKS pulls images from ACR using a managed identity role assignment, and GitHub Actions authenticates to Azure using a service principal stored only in GitHub Secrets.

---

## 3. Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ GitHub (AbdalhakimElghweiry/Cloud-And-DevOps-Final-Project)     │
│                                                                 │
│  Every push ──► Job 1: build-and-test                          │
│                    │  docker build + curl /health smoke test    │
│                    │                                            │
│  push to main ──► Job 2: push-to-acr                           │
│                    │  az acr login → docker push :sha :latest   │
│                    │                                            │
│                   Job 3: deploy-to-aks                          │
│  ◄─ MANUAL APPROVAL GATE (GitHub Environment: production) ─►   │
│                    │  sed replaces image placeholder            │
│                    │  kubectl apply -f k8s/                     │
│                    │  kubectl rollout status                     │
└────────────────────┼────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ Azure (swedencentral)                                           │
│                                                                 │
│  rg-abdalhakim-finalproject                                     │
│  ├── ACR: abdalhakimfinalacr (Basic, admin disabled)           │
│  │       └── repository: cloudscale-app                        │
│  │               tags: :<git-sha>  :latest                     │
│  │                                                             │
│  └── AKS: aks-abdalhakim-finalproject                          │
│           ├── 2 nodes, Standard_B2s                            │
│           ├── System-assigned managed identity                  │
│           ├── kubelet identity → AcrPull role on ACR           │
│           └── Kubernetes workload:                              │
│               ├── Deployment: cloudscale-app (3 replicas)      │
│               └── Service: LoadBalancer  port 80 → 3000        │
│                                                                 │
│  rg-tfstate-abdalhakim  (separate — not managed by Terraform)  │
│  └── Storage Account: tfstateabdalhakim                        │
│          └── Container: tfstate                                 │
│                  └── Blob: finalproject.tfstate                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Full File Tree

```
Cloud-And-DevOps-Final-Project/
├── app/
│   ├── index.js              Node.js/Express web app
│   └── package.json          Dependencies (Express 4.18)
├── terraform/
│   ├── providers.tf          Provider version + remote backend config
│   ├── variables.tf          All tuneable values in one place
│   ├── main.tf               RG + ACR + AKS + AcrPull role assignment
│   └── outputs.tf            Prints ACR server, AKS name, kubectl command
├── k8s/
│   ├── deployment.yaml       3 replicas, liveness + readiness probes
│   └── service.yaml          LoadBalancer on port 80 → 3000
├── .github/
│   └── workflows/
│       └── ci-cd.yml         3-job pipeline with manual approval gate
├── Dockerfile                2-stage Node 20 Alpine build
├── .dockerignore             Excludes terraform/, k8s/, .github/ from context
├── .gitignore                Covers .terraform/, *.tfstate*, *.tfvars, .env
└── README.md                 Setup and operation instructions
```

Files that were already present at project start and replaced/kept:

| File | State at start | Action |
|---|---|---|
| `README.md` | One-line placeholder (UTF-16 BOM) | Replaced with full setup guide |
| `.git/` | Existing repo, one commit | Left untouched |

---

## 5. Section 1 — Application

### app/index.js

```javascript
const express = require('express');

const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (_req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
      <head><title>Cloud &amp; DevOps Final Project</title></head>
      <body>
        <h1>Hello from Abdalhakim Elghweiry</h1>
        <p>Cloud Computing &amp; DevOps Final Project</p>
      </body>
    </html>
  `);
});

app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
```

**What it does:**
- `GET /` — returns an HTML page displaying the student name. Used for browser screenshot.
- `GET /health` — returns HTTP 200 with `{"status":"ok"}`. This endpoint is used by both the Kubernetes liveness/readiness probes and the CI/CD smoke test.
- Port is read from `process.env.PORT` so the container runtime can override it; defaults to `3000`.
- `_req` (underscore prefix) signals the request argument is intentionally unused.

---

### app/package.json

```json
{
  "name": "cloudscale-app",
  "version": "1.0.0",
  "description": "Cloud & DevOps Final Project - Abdalhakim Elghweiry",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
```

**What it does:**
- Declares Express 4.18.x as the only runtime dependency. No dev dependencies, no build tools — this keeps the production image minimal.
- `^4.18.2` allows patch and minor updates within 4.x (e.g. 4.19.0 is fine; 5.0.0 is not).
- `npm start` runs the application directly.

**Note:** There is no `package-lock.json` committed yet. Run `npm install` locally once to generate it. The Dockerfile uses `npm install --production` (not `npm ci`) so it works without a lock file during the first build.

---

### Dockerfile

```dockerfile
# Stage 1: install production dependencies in a clean layer
FROM node:20-alpine AS deps
WORKDIR /app
COPY app/package*.json ./
RUN npm install --production --ignore-scripts

# Stage 2: minimal runtime image
FROM node:20-alpine AS runtime
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY app/ ./
EXPOSE 3000
USER node
CMD ["node", "index.js"]
```

**Why multi-stage:**
Docker multi-stage builds let you use a "builder" stage to install dependencies (which may involve compilers, package manager caches, etc.) and then copy only the result into a clean final image. This means the final image does not contain npm's cache, temporary files, or any tools beyond what is needed to run the app.

**Stage-by-stage explanation:**

| Stage | Base | Purpose |
|---|---|---|
| `deps` | `node:20-alpine` | Copies only `package.json` and `package-lock.json`, then runs `npm install --production`. The `--ignore-scripts` flag prevents lifecycle scripts (postinstall hooks) from running, which is a security precaution. |
| `runtime` | `node:20-alpine` (fresh copy) | Copies `node_modules` from the `deps` stage and the app source from the host. Nothing from the build environment leaks in. |

**Security choices:**
- `node:20-alpine` — Alpine Linux base is ~5 MB vs ~300 MB for Debian-based images. Smaller attack surface.
- `USER node` — runs the process as the non-root `node` user that is built into the official Node image. A process running as root inside a container has more blast radius if exploited.
- `EXPOSE 3000` — documents the port; does not actually publish it (that is done by `docker run -p` or Kubernetes).
- `CMD ["node", "index.js"]` — exec form (JSON array) is preferred over shell form because it makes the Node process PID 1, so OS signals (SIGTERM) reach it directly for graceful shutdown.

**Build context:** The `.dockerignore` file ensures that `terraform/`, `k8s/`, `.github/`, `.git/`, `.terraform/`, state files, and `.env` files are excluded from the build context sent to the Docker daemon.

---

### .dockerignore

```
terraform/
k8s/
.github/
.git/
*.md
.gitignore
.terraform/
*.tfstate*
*.tfvars
.env
```

**Why this matters:** Without a `.dockerignore`, Docker sends the entire working directory to the daemon as the build context. This wastes time on large directories (`.git/`, `.terraform/`) and risks accidentally copying secrets (`.env`, `*.tfvars`) into the image layer even if you never explicitly `COPY` them — a `COPY . .` instruction would pull them in.

---

## 6. Section 2 — Terraform

All Terraform files live in `terraform/`. They must be run from inside that directory (`cd terraform`).

### Terraform Remote Backend Decision

Before writing `providers.tf`, the Azure subscription was queried for existing storage accounts in `swedencentral`:

```powershell
az storage account list \
  --query "[?location=='swedencentral'].{name:name,rg:resourceGroup}" \
  -o table
```

Result: **no existing storage accounts found.** The student confirmed they wanted a remote backend, so a new one is included in the configuration. The bootstrap storage account (`tfstateabdalhakim`) is created with `az` CLI commands *before* `terraform init` — it cannot be created by Terraform itself because Terraform needs the backend to already exist when it initialises.

---

### terraform/providers.tf

```hcl
terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # Remote backend — bootstrap the storage account before running terraform init.
  # See README.md "Bootstrap Terraform Backend" section for the az CLI commands.
  backend "azurerm" {
    resource_group_name  = "rg-tfstate-abdalhakim"
    storage_account_name = "tfstateabdalhakim"   # must be globally unique — change suffix if taken
    container_name       = "tfstate"
    key                  = "finalproject.tfstate"
  }
}

provider "azurerm" {
  features {}
}
```

**Key decisions:**

| Setting | Value | Reason |
|---|---|---|
| `required_version` | `>= 1.5` | Terraform 1.9.8 is installed locally; 1.5 was when several important stability fixes landed |
| `azurerm version` | `~> 3.0` | Allows any 3.x patch/minor; blocks accidental upgrade to 4.x which has breaking changes |
| Backend RG | `rg-tfstate-abdalhakim` | Separate from the project RG — if you `terraform destroy` the project, the state file survives |
| Backend storage | `tfstateabdalhakim` | 5–50 chars, lowercase alphanumeric, globally unique. **Change the suffix if this name is already taken.** |
| Container | `tfstate` | Logical grouping for state blobs |
| Key | `finalproject.tfstate` | The blob file name inside the container |

---

### terraform/variables.tf

```hcl
variable "location" {
  type        = string
  description = "Azure region for all project resources"
  default     = "swedencentral"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group that contains all project resources"
  default     = "rg-abdalhakim-finalproject"
}

variable "acr_name" {
  type        = string
  description = "Azure Container Registry name — must be globally unique, 5-50 chars, lowercase alphanumeric only"
  default     = "abdalhakimfinalacr"
}

variable "aks_cluster_name" {
  type        = string
  description = "AKS cluster name"
  default     = "aks-abdalhakim-finalproject"
}

variable "node_count" {
  type        = number
  description = "Number of nodes in the default node pool"
  default     = 2
}

variable "node_size" {
  type        = string
  description = "VM size for AKS nodes"
  default     = "Standard_B2s"
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to all resources"
  default = {
    Project     = "Final"
    StudentName = "Abdalhakim Elghweiry"
  }
}
```

**Variable breakdown:**

| Variable | Default | Notes |
|---|---|---|
| `location` | `swedencentral` | All project resources go to the same region |
| `resource_group_name` | `rg-abdalhakim-finalproject` | Contains "Abdalhakim" as required by the spec |
| `acr_name` | `abdalhakimfinalacr` | 18 chars, all lowercase alphanumeric — valid. Globally unique requirement: change suffix if taken |
| `aks_cluster_name` | `aks-abdalhakim-finalproject` | Descriptive name matching the project |
| `node_count` | `2` | Two nodes as required by the spec |
| `node_size` | `Standard_B2s` | 2 vCPU, 4 GiB RAM burstable VM; cost-effective for a student project |
| `tags` | `Project=Final, StudentName=Abdalhakim Elghweiry` | Applied to every resource; both tag keys required by the spec |

To override any value without editing the file, create a `terraform.tfvars` file (already gitignored) or pass `-var` flags on the command line.

---

### terraform/main.tf

```hcl
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ---------- Container Registry ----------

resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.tags
}

# ---------- AKS Cluster ----------

resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "abdalhakim-finalproject"
  tags                = var.tags

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.node_size
  }

  # System-assigned managed identity — lets Azure manage credentials automatically
  identity {
    type = "SystemAssigned"
  }
}

# ---------- ACR Pull permission for AKS node pool ----------
# Grants the kubelet (node) identity AcrPull on the registry.
# No image-pull secrets are stored anywhere.

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
```

**Resource-by-resource explanation:**

#### azurerm_resource_group.rg
Creates the container for all project resources. Name `rg-abdalhakim-finalproject` satisfies the spec requirement to include the student name.

#### azurerm_container_registry.acr
- `sku = "Basic"` — the cheapest SKU, sufficient for a single-project registry. No geo-replication, no content trust, but all core features are present.
- `admin_enabled = false` — the admin account gives username/password access to the registry. Disabling it enforces identity-based access only, which is more secure.

#### azurerm_kubernetes_cluster.aks
- `dns_prefix = "abdalhakim-finalproject"` — used in the Kubernetes API server FQDN. Must be unique within the region. Allowed characters: letters, digits, hyphens.
- `identity { type = "SystemAssigned" }` — Azure automatically creates and manages a managed identity for the AKS control plane. This is what allows the role assignment below to work without storing any credentials.

#### azurerm_role_assignment.aks_acr_pull
This is the key piece that makes secretless image pulling work:

```
AKS node pool (kubelet) → AcrPull role → ACR
```

- `principal_id = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id` — the kubelet identity is the managed identity used by the VM nodes (not the control plane). It is the identity that actually does the `docker pull` at runtime.
- `role_definition_name = "AcrPull"` — a built-in Azure role that allows pulling (but not pushing) images from the registry.
- `scope = azurerm_container_registry.acr.id` — the role is scoped to this specific ACR only, following least-privilege.

With this in place, when Kubernetes schedules a pod that references an ACR image, the node uses its managed identity token to authenticate to ACR and pull the image. No `imagePullSecrets` entries are needed in the deployment manifest.

---

### terraform/outputs.tf

```hcl
output "resource_group_name" {
  description = "Name of the project resource group"
  value       = azurerm_resource_group.rg.name
}

output "acr_login_server" {
  description = "ACR login server URL (use as ACR_LOGIN_SERVER secret in GitHub)"
  value       = azurerm_container_registry.acr.login_server
}

output "aks_cluster_name" {
  description = "AKS cluster name (use as AKS_CLUSTER_NAME secret in GitHub)"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_get_credentials_command" {
  description = "Command to configure kubectl for this cluster"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.rg.name} --name ${azurerm_kubernetes_cluster.aks.name}"
}

output "kube_config" {
  description = "Raw kubeconfig (sensitive)"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}
```

**After `terraform apply`, run:**

```bash
terraform output acr_login_server
# → e.g. abdalhakimfinalacr.azurecr.io
# Paste this as the ACR_LOGIN_SERVER GitHub Secret

terraform output aks_get_credentials_command
# → az aks get-credentials --resource-group rg-abdalhakim-finalproject --name aks-abdalhakim-finalproject
# Run this command to configure your local kubectl

terraform output -raw kube_config
# → raw kubeconfig YAML (sensitive — do not share or commit)
```

---

## 7. Section 3 — Kubernetes Manifests

Both files live in `k8s/`. They are applied together with `kubectl apply -f k8s/`.

### k8s/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudscale-app
  labels:
    app: cloudscale-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: cloudscale-app
  template:
    metadata:
      labels:
        app: cloudscale-app
    spec:
      containers:
        - name: cloudscale-app
          # CI/CD replaces REGISTRY/cloudscale-app:TAG before kubectl apply
          image: REGISTRY/cloudscale-app:TAG
          ports:
            - containerPort: 3000
          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 15
            periodSeconds: 10
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 5
            failureThreshold: 3
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "250m"
              memory: "256Mi"
```

**Field-by-field explanation:**

| Field | Value | Reason |
|---|---|---|
| `replicas` | `3` | As required by spec; distributes across 2 nodes for redundancy |
| `image` | `REGISTRY/cloudscale-app:TAG` | Placeholder — the CI/CD pipeline replaces this with the real ACR address and commit SHA using `sed` before running `kubectl apply` |
| `containerPort` | `3000` | Must match the port the Express app listens on |

**Liveness probe** (`livenessProbe`):
- Kubernetes calls `GET /health` every 10 seconds after an initial 15-second wait.
- If it fails 3 times in a row (`failureThreshold: 3`), the container is killed and restarted.
- The 15-second initial delay gives Node.js time to start up before the probe begins.

**Readiness probe** (`readinessProbe`):
- Kubernetes calls `GET /health` every 5 seconds after a 5-second wait.
- If it fails, the pod is removed from the Service's endpoint list (traffic stops going to it) but the container is not restarted.
- Readiness checks sooner and more frequently than liveness because it determines whether to send traffic, not whether to restart.

**Resource requests and limits:**

| | CPU | Memory |
|---|---|---|
| `requests` | 100m (0.1 core) | 128 MiB |
| `limits` | 250m (0.25 core) | 256 MiB |

Requests are what Kubernetes uses for scheduling (it finds a node with at least this much free). Limits are hard caps — the container is OOM-killed if it exceeds the memory limit. These values are sized for a lightweight Express app on Standard_B2s nodes.

**How the image placeholder works:**
The CI/CD `deploy-to-aks` job runs this `sed` command on the file before applying it:

```bash
sed -i "s|REGISTRY/cloudscale-app:TAG|<ACR_LOGIN_SERVER>/cloudscale-app:<git-sha>|g" \
  k8s/deployment.yaml
```

The commit SHA (`github.sha`) is used as the image tag, making every deployment uniquely traceable to a commit.

---

### k8s/service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: cloudscale-app
spec:
  type: LoadBalancer
  selector:
    app: cloudscale-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 3000
```

**What it does:**
- `type: LoadBalancer` — asks Azure to provision a public Azure Load Balancer with a public IP address. Traffic arriving on port 80 is forwarded to port 3000 on any pod matching the selector.
- `selector: app: cloudscale-app` — matches the `labels` on the Deployment's pod template. The Service automatically tracks which pods are ready (via readiness probes) and only routes traffic to those.
- `port: 80` — the public port users connect to.
- `targetPort: 3000` — the port inside the container.

After deployment, `kubectl get service cloudscale-app` will show the `EXTERNAL-IP` once Azure has provisioned the load balancer (usually takes 1–3 minutes).

---

## 8. Section 4 — GitHub Actions CI/CD

### .github/workflows/ci-cd.yml

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: ["**"]
  pull_request:
    branches: [main]

env:
  IMAGE_NAME: cloudscale-app

jobs:
  build-and-test:
    name: Build & Test
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build Docker image
        run: |
          docker build -t ${{ env.IMAGE_NAME }}:${{ github.sha }} .

      - name: Smoke-test /health endpoint
        run: |
          docker run -d --name test-app -p 3000:3000 ${{ env.IMAGE_NAME }}:${{ github.sha }}
          for i in $(seq 1 10); do
            if curl -sf http://localhost:3000/health; then
              echo "Health check passed"
              break
            fi
            echo "Attempt $i failed, retrying..."
            sleep 2
          done
          curl -sf http://localhost:3000/health || (echo "Health check failed" && exit 1)
          docker stop test-app

  push-to-acr:
    name: Push to ACR
    needs: build-and-test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Login to Azure
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Login to ACR
        run: |
          ACR_NAME=$(echo "${{ secrets.ACR_LOGIN_SERVER }}" | cut -d. -f1)
          az acr login --name "$ACR_NAME"

      - name: Build and push to ACR
        run: |
          docker build \
            -t ${{ secrets.ACR_LOGIN_SERVER }}/${{ env.IMAGE_NAME }}:${{ github.sha }} \
            -t ${{ secrets.ACR_LOGIN_SERVER }}/${{ env.IMAGE_NAME }}:latest \
            .
          docker push ${{ secrets.ACR_LOGIN_SERVER }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          docker push ${{ secrets.ACR_LOGIN_SERVER }}/${{ env.IMAGE_NAME }}:latest

  deploy-to-aks:
    name: Deploy to AKS
    needs: push-to-acr
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Login to Azure
        uses: azure/login@v2
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}

      - name: Configure kubectl
        run: |
          az aks get-credentials \
            --resource-group ${{ secrets.RESOURCE_GROUP }} \
            --name ${{ secrets.AKS_CLUSTER_NAME }} \
            --overwrite-existing

      - name: Inject image reference into deployment manifest
        run: |
          sed -i "s|REGISTRY/cloudscale-app:TAG|${{ secrets.ACR_LOGIN_SERVER }}/${{ env.IMAGE_NAME }}:${{ github.sha }}|g" \
            k8s/deployment.yaml

      - name: Apply Kubernetes manifests
        run: kubectl apply -f k8s/

      - name: Wait for rollout
        run: kubectl rollout status deployment/cloudscale-app --timeout=120s
```

**Pipeline flow:**

```
Every push (any branch)
        │
        ▼
  build-and-test
  ├── docker build  (tags image with commit SHA)
  └── smoke test    (runs container, polls /health with 10 retries × 2s)
        │
        │  only if: branch == main AND event == push
        ▼
  push-to-acr
  ├── azure/login@v2  (authenticates via AZURE_CREDENTIALS secret)
  ├── az acr login    (uses Azure CLI session — no registry password stored)
  └── docker push     (pushes :sha and :latest tags to ACR)
        │
        │  pauses here for manual approval (GitHub Environment: production)
        ▼
  deploy-to-aks
  ├── azure/login@v2
  ├── az aks get-credentials  (writes kubeconfig to runner's ~/.kube/config)
  ├── sed  (replaces REGISTRY/cloudscale-app:TAG in deployment.yaml)
  ├── kubectl apply -f k8s/
  └── kubectl rollout status  (waits up to 120s for all pods to be ready)
```

**Job dependency chain:** `build-and-test` → `push-to-acr` → `deploy-to-aks`. Each job only starts if the previous one passed.

**The manual approval gate:**
`environment: production` on the `deploy-to-aks` job tells GitHub to check the `production` environment's protection rules before starting the job. Once you configure required reviewers on that environment, the pipeline will pause and send a notification asking for approval. The deploy only proceeds after you click **Approve**.

To set it up:
1. GitHub → repo → Settings → Environments → New environment
2. Name: `production` (exact match, case-sensitive)
3. Enable **Required reviewers** → add your GitHub username
4. Save protection rules

**ACR name extraction:**
```bash
ACR_NAME=$(echo "${{ secrets.ACR_LOGIN_SERVER }}" | cut -d. -f1)
```
`ACR_LOGIN_SERVER` is `abdalhakimfinalacr.azurecr.io`. `cut -d. -f1` splits on `.` and takes the first field, giving `abdalhakimfinalacr`. This is the name `az acr login` expects.

**Why `az acr login` instead of `docker login`:**
`az acr login` uses the current Azure CLI session (established by `azure/login@v2`) to get a short-lived token and authenticate Docker to the registry. This means the registry password is never stored in any secret — only the service principal credentials are stored, and those only have the permissions you grant them.

---

## 9. Section 5 — Supporting Files

### .gitignore

```gitignore
# Terraform — never commit state or provider downloads
.terraform/
*.tfstate
*.tfstate.*
*.tfstate.backup
.terraform.tfstate

# tfvars can contain secrets — commit only example files
*.tfvars
!example.tfvars

# Environment / secrets
.env
.env.*

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp

# Provider binaries — these are downloaded by terraform init and must not be committed
terraform/providers/
*.exe
```

**Why each entry is here:**

| Pattern | Reason |
|---|---|
| `.terraform/` | Downloaded by `terraform init` — contains provider plugins (large binaries). Committing these was the cause of a previous incident in this project. |
| `*.tfstate*` | State files contain plain-text resource IDs, IP addresses, and sometimes secrets. Must never enter git. |
| `*.tfvars` | Variable files often hold environment-specific values or secrets. The `!example.tfvars` exception allows an example file with placeholder values to be committed. |
| `.env` / `.env.*` | Application environment files can contain API keys, database URLs, etc. |
| `.DS_Store` | macOS Finder metadata — meaningless on other platforms. |
| `.vscode/` / `.idea/` | IDE-specific settings — each developer should maintain their own. |
| `*.exe` | Provider binaries downloaded by Terraform on Windows. |

---

### README.md

The `README.md` covers:
1. Architecture diagram (text art)
2. Prerequisites list with version check commands
3. Bootstrap Terraform Backend — full `az` CLI command sequence
4. Terraform commands (`init` → `plan` → `apply`)
5. Service principal creation command for GitHub Actions
6. GitHub Secrets table
7. GitHub Environment setup (manual approval gate)
8. Local Docker build and test commands
9. kubectl configuration and verification commands
10. `terraform destroy` cleanup instructions (with the separate backend RG cleanup)

---

## 10. Key Design Decisions

### Why Node.js / Express?
Minimal dependencies, instant startup, small image footprint. A Node 20 Alpine image with only Express installed compresses to under 50 MB. Python Flask would be comparable, but Express has better support for multi-stage Docker builds without a pip cache layer.

### Why `node:20-alpine` as the base?
Node 20 is the current LTS (Long-Term Support) release. Alpine Linux images are ~5 MB versus ~180 MB for Debian-based `node:20`. The smaller size reduces pull time in CI and reduces the attack surface in production.

### Why separate the `deps` stage from `runtime` stage?
`npm install` generates a cache in `/root/.npm` and can leave temporary files. By isolating the install in its own stage and only copying `node_modules`, the final image layer contains no install artefacts. This also means Docker can cache the `deps` stage independently — if `package.json` does not change between commits, Docker reuses the cached layer and does not re-download packages.

### Why ACR Basic SKU?
The Basic SKU supports all core features needed for this project (push, pull, managed identity auth). Standard and Premium add geo-replication, content trust, and higher throughput — none of which are needed for a two-node student cluster. Basic minimises cost on the Azure for Students credit.

### Why `admin_enabled = false` on ACR?
The admin account uses a static username/password that, if leaked, gives permanent push/pull access to the registry. Managed identity access is time-limited, automatically rotated, and auditable. Disabling the admin account removes the static credential risk entirely.

### Why `SystemAssigned` managed identity on AKS?
Two types of managed identity are available for AKS: `SystemAssigned` (Azure creates and manages it, tied to the cluster lifecycle) and `UserAssigned` (you create it separately, reusable across resources). `SystemAssigned` is simpler for a single-cluster project and has no risk of the identity outliving its resource.

### Why `kubelet_identity[0].object_id` for the role assignment (not the cluster identity)?
The AKS cluster has two managed identities:
- **Control plane identity** — used by the Kubernetes API server and controller manager.
- **Kubelet identity** — used by the VM nodes (kubelets) to pull container images, write logs, etc.

`AcrPull` must be granted to the **kubelet identity** because it is the kubelet that performs the image pull when scheduling a pod. Granting it to the control plane identity would not work — the control plane does not pull images.

### Why a separate resource group for Terraform state?
If the project RG (`rg-abdalhakim-finalproject`) and the state storage were in the same group, running `terraform destroy` on the project could delete the resource group and with it the state file. This would leave Terraform with no record of what it created — making it impossible to clean up properly. Keeping the state in `rg-tfstate-abdalhakim` means the state survives a project destroy.

### Why `github.sha` as the image tag?
Every commit produces a unique SHA. Tagging images with the commit SHA means:
- Every deployed image is traceable to an exact commit.
- Rolling back is as simple as re-applying the manifest from a previous commit (the image is still in ACR).
- `:latest` is also pushed for convenience (e.g., pulling the most recent version without knowing the SHA).

### Why `failureThreshold: 3` on both probes?
A single failed probe should not immediately restart or remove a pod — a transient network hiccup would cause unnecessary churn. Three consecutive failures means approximately 30 seconds of liveness failure (3 × 10s) before a restart, and 15 seconds of readiness failure (3 × 5s) before traffic is pulled. This gives the app time to recover from a momentary slowdown before Kubernetes intervenes.

### Why the `sed` placeholder approach for image injection?
Alternatives considered:
- **Kustomize** — more powerful, but requires `kustomization.yaml` and adds a learning curve.
- **Helm** — full template engine, overkill for a two-file deployment.
- **Environment variables in YAML** — Kubernetes does not evaluate shell variables in manifests.
- **`sed` replacement** — one line, no additional tooling, transparent in CI logs.

`sed` was chosen because it keeps the Kubernetes manifests readable as plain YAML (the placeholder `REGISTRY/cloudscale-app:TAG` is self-documenting) and the substitution step is visible in the CI log.

---

## 11. Setup & Deployment Guide

### Step 0 — Verify tools

```powershell
git --version        # expect 2.x
docker --version     # expect 20+
terraform --version  # expect 1.5+
az --version         # expect 2.x
kubectl version --client
az account show      # verify you are logged in to the right subscription
```

### Step 1 — Bootstrap the Terraform backend

Run once before `terraform init`. These commands create the storage account that will hold `finalproject.tfstate`.

```bash
az group create \
  --name rg-tfstate-abdalhakim \
  --location swedencentral

az storage account create \
  --name tfstateabdalhakim \
  --resource-group rg-tfstate-abdalhakim \
  --location swedencentral \
  --sku Standard_LRS \
  --kind StorageV2

az storage container create \
  --name tfstate \
  --account-name tfstateabdalhakim
```

> If `tfstateabdalhakim` is already taken (Azure storage account names are globally unique), choose a different suffix, update `providers.tf` line 15, and retry.

### Step 2 — Initialise and plan Terraform

```bash
cd terraform
terraform init    # downloads azurerm provider, connects to backend
terraform plan    # shows what will be created — review carefully, no changes yet
```

### Step 3 — Apply Terraform (billable)

> **Confirm with yourself before running this.** It provisions two Standard_B2s VMs (AKS nodes) and an ACR, both of which cost money while running.

```bash
terraform apply
```

Note the outputs:
```
acr_login_server = "abdalhakimfinalacr.azurecr.io"
aks_cluster_name = "aks-abdalhakim-finalproject"
aks_get_credentials_command = "az aks get-credentials ..."
resource_group_name = "rg-abdalhakim-finalproject"
```

### Step 4 — Configure kubectl locally

```bash
az aks get-credentials \
  --resource-group rg-abdalhakim-finalproject \
  --name aks-abdalhakim-finalproject

kubectl get nodes   # should show 2 nodes in Ready state
```

### Step 5 — Create the GitHub service principal

```bash
# Get your subscription ID
az account show --query id -o tsv

# Create the service principal (replace <SUB_ID>)
az ad sp create-for-rbac \
  --name "github-actions-finalproject" \
  --role contributor \
  --scopes /subscriptions/<SUB_ID>/resourceGroups/rg-abdalhakim-finalproject \
  --json-auth
```

Copy the entire JSON output. It looks like:
```json
{
  "clientId": "...",
  "clientSecret": "...",
  "subscriptionId": "...",
  "tenantId": "...",
  ...
}
```

### Step 6 — Create GitHub Secrets

Go to: GitHub → repo → Settings → Secrets and variables → Actions → New repository secret

| Secret name | Value |
|---|---|
| `AZURE_CREDENTIALS` | Entire JSON from `az ad sp create-for-rbac` |
| `ACR_LOGIN_SERVER` | `abdalhakimfinalacr.azurecr.io` (from `terraform output acr_login_server`) |
| `AKS_CLUSTER_NAME` | `aks-abdalhakim-finalproject` (from `terraform output aks_cluster_name`) |
| `RESOURCE_GROUP` | `rg-abdalhakim-finalproject` |

### Step 7 — Create GitHub Environment (manual approval gate)

1. GitHub → repo → Settings → Environments → **New environment**
2. Name: `production` (must match exactly — case-sensitive)
3. Under **Deployment protection rules** → enable **Required reviewers**
4. Add your GitHub username as a required reviewer
5. **Save protection rules**

### Step 8 — Test locally before pushing

```bash
# From repo root
docker build -t cloudscale-app:local .
docker run -d -p 3000:3000 cloudscale-app:local
curl http://localhost:3000/
curl http://localhost:3000/health
# expected: {"status":"ok"}
docker stop $(docker ps -q --filter name=cloudscale-app)
```

### Step 9 — Commit and push (you do this yourself)

Review each file, stage what you want, and commit in the order you prefer. The CI/CD pipeline will trigger automatically on push.

### Step 10 — Watch and approve the pipeline

1. Go to GitHub → Actions tab
2. Watch `build-and-test` and `push-to-acr` complete
3. The `deploy-to-aks` job will show a **"Review deployments"** banner
4. Click it → **Approve and deploy**

### Step 11 — Verify the deployment

```bash
kubectl get pods                          # all 3 should be Running
kubectl get service cloudscale-app        # wait for EXTERNAL-IP (1-3 min)
curl http://<EXTERNAL-IP>/health          # {"status":"ok"}
# Open http://<EXTERNAL-IP>/ in a browser to see the name
```

---

## 12. GitHub Secrets Reference

| Secret | What it contains | How to get it |
|---|---|---|
| `AZURE_CREDENTIALS` | JSON with clientId, clientSecret, subscriptionId, tenantId | `az ad sp create-for-rbac ... --json-auth` |
| `ACR_LOGIN_SERVER` | e.g. `abdalhakimfinalacr.azurecr.io` | `terraform output acr_login_server` |
| `AKS_CLUSTER_NAME` | e.g. `aks-abdalhakim-finalproject` | `terraform output aks_cluster_name` |
| `RESOURCE_GROUP` | `rg-abdalhakim-finalproject` | Fixed — same as `var.resource_group_name` in `variables.tf` |

No secrets are hardcoded anywhere in the repository. All sensitive values are injected at runtime via GitHub Secrets and referenced with `${{ secrets.SECRET_NAME }}` syntax.

---

## 13. Screenshot Checklist

| # | Screenshot | How to capture it |
|---|---|---|
| 1 | **Azure Resource Group** — all resources visible | Azure Portal → Resource Groups → `rg-abdalhakim-finalproject` → Overview |
| 2 | **AKS cluster** — node count, status, region | Portal → `aks-abdalhakim-finalproject` → Overview tab |
| 3 | **ACR with pushed image** — repository and tags | Portal → `abdalhakimfinalacr` → Repositories → `cloudscale-app` |
| 4 | **GitHub Actions — all 3 jobs green** | GitHub → Actions tab → click the successful `main` branch run |
| 5 | **Manual approval gate** — the "Review deployments" prompt | Same Actions run → `deploy-to-aks` job → before clicking Approve |
| 6 | **kubectl — pods running** | Terminal: `kubectl get pods -o wide` |
| 7 | **App in browser** showing your name | Open `http://<EXTERNAL-IP>/` — get IP from `kubectl get service cloudscale-app` |
| 8 | **Terraform plan or apply output** | Terminal: `terraform plan` output (or `terraform apply` confirmation) |

---

## 14. Billing & Cleanup

**Resources that cost money while running:**

| Resource | Approximate cost |
|---|---|
| 2 × Standard_B2s nodes (AKS) | ~$0.05/hour each = ~$0.10/hour total |
| ACR Basic | ~$0.167/day |
| Azure Load Balancer | ~$0.025/hour |

At ~$0.13/hour, 10 hours of running costs about $1.30. The Azure for Students $100 credit is sufficient, but leaving it running for days will drain the credit.

**When you have all your screenshots, destroy everything:**

```bash
cd terraform
terraform destroy
```

This removes: the resource group, ACR, AKS cluster, and the role assignment. It does **not** remove:
- The backend state resource group (`rg-tfstate-abdalhakim`)
- The GitHub service principal

To clean those up:

```bash
# Remove the Terraform backend state storage
az group delete --name rg-tfstate-abdalhakim --yes --no-wait

# Remove the service principal
az ad sp delete --id $(az ad sp list --display-name github-actions-finalproject --query "[0].id" -o tsv)
```

> **Do not skip `terraform destroy`.** Forgetting this step is the most common cause of unexpected credit drain on Azure for Students accounts.
