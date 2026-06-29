# Enterprise Cloud DevSecOps Platform (CDS)

> **A production-grade, GitOps-driven DevSecOps platform on AWS EKS — fully automated from infrastructure provisioning to continuous deployment, with security and observability baked in at every layer.**

[![Terraform Validate](https://github.com/Debasish-87/CDS/actions/workflows/terraform-plan.yaml/badge.svg)](https://github.com/Debasish-87/CDS/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Kubernetes: 1.32](https://img.shields.io/badge/Kubernetes-1.32-blue?logo=kubernetes)](https://kubernetes.io/)
[![Terraform: ≥1.6](https://img.shields.io/badge/Terraform-≥1.6-purple?logo=terraform)](https://www.terraform.io/)
[![ArgoCD: Stable](https://img.shields.io/badge/ArgoCD-stable-orange?logo=argo)](https://argoproj.github.io/cd/)

---

## Table of Contents

1. [Overview](#-overview)
2. [Architecture](#-architecture)
3. [Platform Components](#-platform-components)
4. [Repository Structure](#-repository-structure)
5. [Prerequisites](#-prerequisites)
6. [Required GitHub Secrets](#-required-github-secrets)
7. [Quick Start](#-quick-start)
8. [Detailed Deployment Guide](#-detailed-deployment-guide)
9. [CI/CD Pipeline](#-cicd-pipeline)
10. [GitOps Workflow](#-gitops-workflow)
11. [Security Controls](#-security-controls)
12. [Observability Stack](#-observability-stack)
13. [Accessing Dashboards](#-accessing-dashboards)
14. [Makefile Reference](#-makefile-reference)
15. [Script Reference](#-script-reference)
16. [Terraform Modules](#-terraform-modules)
17. [Kyverno Policies](#-kyverno-policies)
18. [Secrets Management](#-secrets-management)
19. [Node Autoscaling with Karpenter](#-node-autoscaling-with-karpenter)
20. [Tear Down](#-tear-down)
21. [Troubleshooting](#-troubleshooting)
22. [Contributing](#-contributing)

---

## Overview

This repository is the **control plane** for a complete Enterprise DevSecOps platform. It provisions, bootstraps, secures, monitors, and continuously deploys a **RAG-based Document Q&A application** (`rag-document-qa`) on AWS EKS — following GitOps principles with ArgoCD as the deployment engine.

### What this platform provides

| Capability | Implementation |
|---|---|
| Infrastructure as Code | Terraform (modular, remote state on S3 + DynamoDB) |
| Container Orchestration | AWS EKS (Kubernetes 1.32) |
| GitOps / CD | ArgoCD (App-of-Apps pattern) |
| CI / Image Build | GitHub Actions |
| Image Registry | AWS ECR |
| Secrets Management | External Secrets Operator + AWS Secrets Manager |
| Policy Enforcement | Kyverno (ClusterPolicies) |
| Runtime Security | Falco (eBPF-based threat detection) |
| Container Scanning | Trivy Operator (in-cluster) + Trivy Action (CI) |
| IaC Security | Checkov + TFLint |
| SBOM Generation | Syft (SPDX JSON) |
| Metrics | Prometheus + kube-prometheus-stack |
| Dashboards | Grafana |
| Distributed Tracing & Metrics | OpenTelemetry Collector |
| Node Autoscaling | Karpenter |
| Ingress / Load Balancing | AWS Load Balancer Controller (ALB) |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          GitHub Actions CI                              │
│                                                                         │
│  [Push to main] ──► lint-security ──► build-image ──► gitops-update     │
│                          │                  │               │           │
│                     Checkov/TFLint    Build+Scan        Update image    │
│                     Trivy FS Scan     Push ECR          tag in repo     │
│                     SBOM (Syft)       Trivy Scan                        │
└─────────────────────┬───────────────────────────────────────────────────┘
                      │ Writes image SHA to gitops-repo/applications/
                      ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      AWS Cloud (ap-south-1)                             │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  VPC (10.0.0.0/16)                                               │   │
│  │                                                                  │   │
│  │  Public Subnets ──► Internet Gateway ──► NAT Gateway             │   │
│  │  Private Subnets ──► EKS Node Group (m7i-flex.large)             │   │
│  │  Database Subnets (reserved)                                     │   │
│  │                                                                  │   │
│  │  ┌────────────────────────────────────────────────────────────┐  │   │
│  │  │  EKS Cluster (enterprise-devsecops-dev, k8s 1.32)          │  │   │
│  │  │                                                            │  │   │
│  │  │  Platform Namespace Stack:                                 │  │   │
│  │  │  ├── argocd          (GitOps engine, App-of-Apps)          │  │   │
│  │  │  ├── kube-system     (ALB Controller, CoreDNS)             │  │   │
│  │  │  ├── monitoring      (Prometheus, Alertmanager, Grafana)   │  │   │
│  │  │  ├── observability   (OpenTelemetry Collector)             │  │   │
│  │  │  ├── external-secrets(ESO + ClusterSecretStore)            │  │   │
│  │  │  ├── kyverno         (Policy Engine + ClusterPolicies)     │  │   │
│  │  │  ├── falco           (Runtime Threat Detection, eBPF)      │  │   │
│  │  │  ├── trivy-system    (In-cluster Image Scanning)           │  │   │
│  │  │  ├── karpenter       (Node Autoscaling)                    │  │   │
│  │  │  └── rag             (Application Namespace)               │  │   │
│  │  │                                                            │  │   │
│  │  └────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  Supporting Services:                                                   │
│  ├── ECR (rag-document-qa image registry)                               │
│  ├── S3  (Terraform state, AES256 encrypted, versioned)                 │
│  ├── DynamoDB (Terraform state locking)                                 │
│  ├── AWS Secrets Manager (GEMINI_API_KEY, API_TOKEN)                    │
│  ├── KMS (EKS secrets encryption)                                       │
│  ├── CloudWatch (VPC Flow Logs)                                         │
│  └── IAM (IRSA roles, GitHub OIDC federated role)                       │
└─────────────────────────────────────────────────────────────────────────┘
```


## Deep Architecture

```
                                             EnterpriseCloud DevSecOps Platform
========================================================================================================================

                                                   +----------------------+
                                                   |      Developer       |
                                                   |   Git Push / PR      |
                                                   +----------+-----------+
                                                              |
                                                              v
                                            +-------------------------------+
                                            |         GitHub Repository      |
                                            |                               |
                                            |  application/                 |
                                            |  terraform-infra/             |
                                            |  gitops-repo/                 |
                                            |  bootstrap/                   |
                                            +---------------+---------------+
                                                            |
                                                            |
                                  GitHub Actions CI/CD Pipeline
                                                            |
      ==========================================================================================================
      |                |                 |                  |                 |                |                 |
      v                v                 v                  v                 v                v                 v

+-------------+  +-------------+  +--------------+  +---------------+  +--------------+ +--------------+ +-------------+
| Hadolint    |  | Terraform   |  | Checkov      |  | Trivy FS      |  | Build Image  | | Trivy Image  | | Generate    |
| Dockerfile  |  | Validate    |  | Scan         |  | Scan          |  | Docker       | | Scan         | | SBOM        |
+------+------+  +------+------+
| Build     |      | Scan      |      | Push Image     |
| Docker    | ---> | Trivy     | ---> | Amazon ECR     |
+-----------+      +-----------+      +-------+--------+
                                             |
                                             |
                                             v
                                +---------------------------+
                                |     Amazon ECR            |
                                |  rag-document-qa Image    |
                                +-------------+-------------+
                                              |
                                              |
                                              v
                        +------------------------------------------+
                        | GitOps Repository Update                 |
                        | deployment.yaml image updated            |
                        +----------------+-------------------------+
                                         |
                                         |
                                         v
                            +------------------------------+
                            |        ArgoCD                |
                            | Watches gitops-repo          |
                            +--------------+---------------+
                                           |
                                           |
                                 Automatic Sync / Self Heal
                                           |
                                           v
=========================================================================================
                                   Amazon EKS Cluster
=========================================================================================

                    +------------------------------------------------------+
                    |                   Kubernetes                          |
                    +------------------------------------------------------+

Namespaces

├── argocd
│      ├── argocd-server
│      ├── repo-server
│      ├── application-controller
│      ├── dex
│      └── notifications
│
├── rag
│      ├── Deployment
│      ├── Service
│      ├── Ingress
│      ├── HPA
│      └── Secrets
│
├── monitoring
│      ├── Prometheus
│      ├── Grafana
│      └── kube-state-metrics
│
├── observability
│      └── OpenTelemetry Collector
│
├── external-secrets
│      └── External Secrets Operator
│
├── kyverno
│      └── Policy Engine
│
├── falco
│      └── Runtime Threat Detection
│
├── trivy-system
│      └── Trivy Operator
│
└── karpenter
       └── Node Autoscaler

=========================================================================================

Application Flow

                User
                  |
                  |
                  v
         Internet / Browser
                  |
                  |
          AWS Load Balancer
                  |
                  |
              Kubernetes
               Ingress
                  |
                  |
          RAG Service (ClusterIP)
                  |
                  |
          RAG Deployment Pods
                  |
                  |
      +-----------+-----------+
      |                       |
      v                       v
 Vector Database        LLM Provider
 / Embeddings           (OpenAI etc.)

=========================================================================================

Infrastructure Provisioning

Terraform
    |
    +--------------------------+
    |                          |
    v                          v
 Amazon VPC             IAM Roles
    |
    v
 Public Subnets
 Private Subnets
 NAT Gateway
 Internet Gateway
 Security Groups
    |
    v
 Amazon EKS
    |
    +-------------------+
    |                   |
    v                   v
 Managed Nodes      Karpenter

Remote State

Terraform
      |
      +-------------> S3 Backend
      |
      +-------------> DynamoDB Lock Table

=========================================================================================

Security

Developer
      |
      v
GitHub OIDC
      |
      v
IAM Role
      |
      v
AWS Credentials

Security Layers

• Hadolint
• Terraform Validate
• Checkov
• Trivy Filesystem
• Trivy Image Scan
• Kyverno Policies
• Falco Runtime Detection
• External Secrets
• IAM Roles
• ECR Image Scanning

=========================================================================================

Observability

Application
      |
      v
OpenTelemetry Collector
      |
      +------------------------+
      |                        |
      v                        v
 Prometheus               Grafana
      |
      v
 Metrics / Alerts

=========================================================================================

GitOps Flow

Developer
     |
     v
Git Push
     |
     v
GitHub Actions
     |
     v
Docker Image
     |
     v
Amazon ECR
     |
     v
Update deployment.yaml
     |
     v
GitOps Repository
     |
     v
ArgoCD Sync
     |
     v
Amazon EKS
     |
     v
Application Updated

=========================================================================================

Bootstrap Flow

Terraform Bootstrap
        |
        v
S3 + DynamoDB Backend
        |
        v
Terraform Apply
        |
        v
Amazon EKS Cluster
        |
        v
Bootstrap Script
        |
        v
Install ArgoCD
        |
        v
Root Application
        |
        v
Sync Entire Platform

=========================================================================================

Dashboards

Developer
     |
     +---------------------> ArgoCD UI
     |
     +---------------------> Grafana
     |
     +---------------------> Prometheus

=========================================================================================

```

### GitOps Flow

```
GitHub Push
    │
    ▼
GitHub Actions CI Pipeline
    ├── Security scan (Checkov, TFLint, Trivy FS)
    ├── Docker build → Trivy image scan → ECR push
    ├── SBOM generation (Syft)
    └── Update gitops-repo/applications/rag-document-qa/deployment.yaml
            │
            ▼ (ArgoCD polls every ~3 min or webhook)
        ArgoCD detects drift
            │
            ▼
        Sync → Kubernetes reconciles desired state
            │
            ▼
        New pods running on EKS
```

---

## Platform Components

### Infrastructure (Terraform)

| Module | Description | Key Resources |
|---|---|---|
| `vpc` | Network foundation | VPC, public/private/DB subnets, IGW, NAT, route tables, VPC Flow Logs |
| `eks` | Kubernetes cluster | EKS 1.32, managed node group, KMS secrets encryption, OIDC provider, IMDSv2, encrypted EBS |
| `ecr` | Container registry | ECR repositories with lifecycle policies |
| `github-oidc` | Keyless CI auth | GitHub Actions OIDC provider, IAM role for ECR push |
| Bootstrap TF | Remote state backend | S3 (AES256, versioning, public-access blocked), DynamoDB lock table |

### Platform Services (GitOps via ArgoCD)

| Component | Namespace | Helm Chart | Version | Purpose |
|---|---|---|---|---|
| ArgoCD | `argocd` | argoproj/argo-cd | stable | GitOps engine, App-of-Apps root |
| AWS ALB Controller | `kube-system` | eks-charts/aws-load-balancer-controller | 1.11.0 | Ingress → AWS ALB |
| Prometheus | `monitoring` | prometheus-community/kube-prometheus-stack | 69.5.2 | Metrics scraping + Alertmanager |
| Grafana | `monitoring` | grafana/grafana | 8.10.1 | Metrics dashboards |
| Kyverno | `kyverno` | kyverno/kyverno | 3.3.7 | Policy-as-Code engine |
| Kyverno Policies | `kyverno` | (from this repo) | HEAD | disallow-latest, resource-limits, non-root |
| Falco | `falco` | falcosecurity/falco | 4.19.0 | Runtime security (eBPF) |
| Trivy Operator | `trivy-system` | aquasecurity/trivy-operator | 0.27.1 | In-cluster CVE scanning |
| External Secrets | `external-secrets` | external-secrets/external-secrets | 0.15.0 | AWS Secrets Manager sync |
| OpenTelemetry | `observability` | open-telemetry/opentelemetry-collector | 0.117.3 | Traces + metrics pipeline |
| Karpenter | `karpenter` | public.ecr.aws/karpenter/karpenter | 1.3.2 | Node autoprovisioning |

### Application

| Component | Namespace | Description |
|---|---|---|
| `rag-document-qa` | `rag` | Python FastAPI RAG application (cloned from `Debasish-87/rag-based-document-qa`) |

---

## Repository Structure

```
CDS/
├── .github/
│   └── workflows/
│       ├── ci.yaml                    # Main CI/CD pipeline
│       └── terraform-plan.yaml        # Terraform validate & plan on PRs
│
├── bootstrap/
│   ├── argocd/
│   │   └── install.sh                 # ArgoCD installer + root app creator
│   ├── main.tf                        # S3 state bucket + DynamoDB lock table
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   └── terraform.tfvars               # AWS region + bucket/table names
│
├── terraform-infra/
│   ├── environments/
│   │   └── dev/
│   │       ├── main.tf                # Orchestrates all modules
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       ├── versions.tf
│   │       ├── backend.tf             # Remote state (S3 + DynamoDB)
│   │       └── terraform.tfvars
│   └── modules/
│       ├── vpc/                       # VPC, subnets, NAT, flow logs
│       ├── eks/                       # EKS cluster, node group, OIDC, KMS
│       ├── ecr/                       # ECR repositories
│       └── github-oidc/               # GitHub Actions OIDC IAM role
│
├── gitops-repo/
│   ├── kustomization.yaml             # Root kustomization
│   ├── platform/
│   │   ├── kustomization.yaml         # All platform components
│   │   ├── argocd/                    # argocd namespace
│   │   ├── alb-controller/            # AWS ALB Controller ArgoCD App
│   │   ├── prometheus/                # Prometheus ArgoCD App
│   │   ├── grafana/                   # Grafana ArgoCD App
│   │   ├── kyverno/                   # Kyverno + policies ArgoCD Apps
│   │   │   └── policies/
│   │   │       ├── disallow-latest.yaml
│   │   │       ├── require-resource-limits.yaml
│   │   │       └── require-non-root.yaml
│   │   ├── falco/                     # Falco ArgoCD App
│   │   ├── trivy-operator/            # Trivy Operator ArgoCD App
│   │   ├── external-secrets/          # ESO ArgoCD App + ClusterSecretStore
│   │   │   ├── stores/
│   │   │   │   └── cluster-secret-store.yaml
│   │   │   └── examples/
│   │   │       └── rag-secret.yaml
│   │   ├── opentelemetry/             # OTel Collector ArgoCD App
│   │   └── karpenter/                 # Karpenter ArgoCD App
│   └── applications/
│       ├── rag-document-qa/           # Application manifests
│       │   ├── deployment.yaml        # ← image tag updated by CI
│       │   ├── service.yaml
│       │   ├── ingress.yaml
│       │   ├── namespace.yaml
│       │   └── kustomization.yaml
│       └── templates/                 # Reusable app manifest templates
│
├── application/
│   ├── Dockerfile                     # Multi-stage, non-root, hardened
│   └── scripts/
│       └── clone-rag.sh               # Clones rag-based-document-qa repo
│
├── scripts/
│   ├── helpers.sh                     # Shared logging, retry, timer utils
│   ├── bootstrap.sh                   # Full bootstrap orchestrator
│   ├── terraform.sh                   # Terraform wrapper (init/plan/apply/destroy)
│   ├── doctor.sh                      # Pre-flight checks (tools, AWS, k8s)
│   ├── health.sh                      # Cluster health checker
│   ├── dashboard.sh                   # Port-forward launcher
│   ├── logs.sh                        # Pod log streamer per component
│   ├── destroy.sh                     # Safe teardown with confirmation
│   ├── cleanup.sh                     # Local cache cleanup
│   └── commit.sh                      # Git lint, commit, and push helper
│
└── Makefile                           # Developer experience entrypoint
```

---

## Prerequisites

### Local tools required

Run `make doctor` to verify all of these automatically.

| Tool | Minimum Version | Install |
|---|---|---|
| `terraform` | ≥ 1.6.0 | [terraform.io](https://developer.hashicorp.com/terraform/install) |
| `kubectl` | ≥ 1.28 | [kubernetes.io](https://kubernetes.io/docs/tasks/tools/) |
| `helm` | ≥ 3.12 | [helm.sh](https://helm.sh/docs/intro/install/) |
| `aws` CLI | ≥ 2.13 | [aws.amazon.com](https://aws.amazon.com/cli/) |
| `git` | ≥ 2.40 | System package manager |
| `curl` | any | System package manager |
| `base64` | any | System package manager |
| `docker` | ≥ 24.0 | [docker.com](https://docs.docker.com/get-docker/) |

### AWS account requirements

- IAM user or role with permissions for: EKS, EC2, VPC, ECR, S3, DynamoDB, IAM, KMS, SecretsManager, CloudWatch
- AWS region configured: **ap-south-1** (Mumbai) — change `terraform.tfvars` + workflow env vars if different
- Recommended: use IAM Identity Center or assume a role with least privilege

---

## Required GitHub Secrets

Configure these in **Settings → Secrets and variables → Actions**:

| Secret | Description |
|---|---|
| `AWS_ACCOUNT_ID` | Your 12-digit AWS account ID |
| `GITOPS_TOKEN` | GitHub Personal Access Token with `repo` scope (for the gitops-update job to push back to this repo) |

> The pipeline uses **GitHub OIDC** (keyless auth) to assume the `github-actions-ecr-role` IAM role in AWS — **no static AWS keys needed**. The Terraform module `github-oidc` provisions this role.

---

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/Debasish-87/CDS.git
cd CDS

# 2. Verify your local environment
make doctor

# 3. Bootstrap Terraform remote state (S3 + DynamoDB) — one-time
cd bootstrap
terraform init
terraform apply
cd ..

# 4. Provision AWS infrastructure (VPC, EKS, ECR, IAM)
make init
make plan
make apply

# 5. Bootstrap ArgoCD and deploy the full platform
make bootstrap

# 6. Check everything is healthy
make health

# 7. Open dashboards
make dashboard
```

---

## Detailed Deployment Guide

### Step 1 — Bootstrap Terraform state backend

This is a **one-time operation** to create the S3 bucket and DynamoDB table that store Terraform state for the rest of the platform.

```bash
cd bootstrap
terraform init
terraform plan
terraform apply
```

This creates:
- S3 bucket `409837635702-devsecops-tf-state` with AES256 encryption, versioning enabled, and all public access blocked
- DynamoDB table `terraform-state-lock` for state locking

Update `bootstrap/terraform.tfvars` with your own bucket name and AWS account ID before running.

### Step 2 — Provision infrastructure

```bash
# From repo root
make init     # terraform init (downloads providers, configures backend)
make plan     # terraform plan (review what will be created)
make apply    # terraform apply -auto-approve
```

This provisions:
- VPC with public/private/database subnets across 2 AZs
- NAT Gateway with Elastic IP
- VPC Flow Logs → CloudWatch
- EKS cluster `enterprise-devsecops-dev` (Kubernetes 1.32)
- Managed node group (m7i-flex.large, 1–5 nodes, desired 2)
- KMS key for EKS secrets encryption
- OIDC provider for IRSA
- ECR repository `rag-document-qa`
- GitHub Actions OIDC IAM role

After apply, update your kubeconfig:

```bash
aws eks update-kubeconfig \
  --region ap-south-1 \
  --name enterprise-devsecops-dev
kubectl get nodes
```

### Step 3 — Bootstrap ArgoCD and platform

```bash
make bootstrap
```

This runs `scripts/bootstrap.sh` which:
1. Verifies all tools and AWS auth
2. Updates kubeconfig
3. Installs ArgoCD into the `argocd` namespace
4. Waits for all ArgoCD deployments and pods to become Ready
5. Patches ArgoCD server to run in `--insecure` mode (for local port-forward access)
6. Creates the **root ArgoCD Application** (`dev-root`) pointing at `gitops-repo/`
7. ArgoCD then auto-syncs and deploys **all platform components** via the App-of-Apps pattern
8. Prints admin password, component status, and dashboard access info

> **ArgoCD admin password** — auto-generated and stored in `argocd-initial-admin-secret`. Retrieve it at any time:
> ```bash
> kubectl -n argocd get secret argocd-initial-admin-secret \
>   -o jsonpath="{.data.password}" | base64 -d
> ```

### Step 4 — Verify

```bash
make verify   # shows namespaces, pods, services, ArgoCD applications
make health   # deep health check: nodes, pods, component-by-component status
```

---

## CI/CD Pipeline

Defined in `.github/workflows/ci.yaml`. Triggers on **push to `main`** or **manual dispatch**.

```
lint-security ──────────────────────────────────────────────────────────────┐
│                                                                           │
│  ● Checkov (Terraform IaC scan) → SARIF → GitHub Security tab             │
│  ● Trivy filesystem scan        → SARIF → GitHub Security tab             │
│  ● TFLint (Terraform linting)                                             │
│                                                                           │
└───────────────────────────► build-image ──────────────────────────────────┤
                              │                                             │
                              │  ● Clone rag-based-document-qa source       │
                              │  ● Docker build (multi-stage, hardened)     │
                              │  ● Docker push → ECR (tagged with SHA)      │
                              │  ● Trivy image scan → SARIF                 │
                              │                                             │
                              ├──────────────► gitops-update (main only)    │
                              │               ● sed image tag in            │
                              │                 deployment.yaml             │
                              │               ● git commit + push           │
                              │                                             │
                              ├──────────────► sbom                         │
                              │               ● Syft generates SPDX JSON    │
                              │               ● Upload as artifact          │
                              │                                             │
                              ├──────────────► verify-image                 │
                              │               ● aws ecr describe-images     │
                              │                                             │
                              └──────────────► artifacts                    │
                                              ● Upload SARIF reports        │
```

### Pipeline jobs summary

| Job | Trigger | Purpose |
|---|---|---|
| `lint-security` | all pushes | Checkov, TFLint, Trivy FS scan |
| `build-image` | after lint | Clone app, build Docker image, ECR push, Trivy image scan |
| `gitops-update` | after build, main only | Updates `deployment.yaml` image tag, commits back |
| `sbom` | after build | Syft SPDX-JSON SBOM generation |
| `verify-image` | after build | Confirms image exists in ECR |
| `artifacts` | always | Upload SARIF and Checkov reports |
| `deployment-summary` | always | GitHub Step Summary with deploy status |
| `cleanup` | always | Docker prune on runner |
| `completed` | always | Final pipeline status |

### GitHub Actions authentication (OIDC)

No long-lived AWS credentials are used. The pipeline assumes the `github-actions-ecr-role` IAM role via **GitHub's OIDC token** (`id-token: write` permission). The role is provisioned by the `github-oidc` Terraform module.

---

## GitOps Workflow

This platform uses the **App-of-Apps** GitOps pattern with ArgoCD.

```
ArgoCD Root App (dev-root)
└── gitops-repo/              [path in this repo]
    ├── platform/             [all platform services]
    │   ├── alb-controller    → ArgoCD Application → Helm → kube-system
    │   ├── prometheus        → ArgoCD Application → Helm → monitoring
    │   ├── grafana           → ArgoCD Application → Helm → monitoring
    │   ├── kyverno           → ArgoCD Application → Helm → kyverno
    │   ├── kyverno-policies  → ArgoCD Application → Kustomize → kyverno
    │   ├── falco             → ArgoCD Application → Helm → falco
    │   ├── trivy-operator    → ArgoCD Application → Helm → trivy-system
    │   ├── external-secrets  → ArgoCD Application → Helm → external-secrets
    │   ├── opentelemetry     → ArgoCD Application → Helm → observability
    │   └── karpenter         → ArgoCD Application → Helm → karpenter
    └── applications/
        └── rag-document-qa   → Kubernetes manifests → rag namespace
```

All ArgoCD Applications are configured with:
- `automated.prune: true` — removes resources deleted from Git
- `automated.selfHeal: true` — reverts any manual changes in the cluster
- `syncOptions.CreateNamespace: true` — namespaces are auto-created

### Deploying a new application version

The GitOps update is **fully automated by CI**. On every push to `main`:

1. CI builds a new Docker image tagged with the git SHA
2. Pushes to ECR
3. Updates `gitops-repo/applications/rag-document-qa/deployment.yaml` with the new image URI
4. Commits and pushes back to this repo
5. ArgoCD detects the change and reconciles within ~3 minutes

### Manual GitOps commit

```bash
# Edit manifest, then use the commit helper
make release   # runs scripts/commit.sh — lints, commits, pushes
```

---

## Security Controls

### Defense-in-depth layers

```
Layer 1  — IaC Security:       Checkov + TFLint (CI gate)
Layer 2  — Image Security:     Trivy (CI) + Trivy Operator (in-cluster, continuous)
Layer 3  — Supply Chain:       SBOM generation with Syft (SPDX JSON)
Layer 4  — Admission Control:  Kyverno ClusterPolicies (Enforce mode)
Layer 5  — Runtime Security:   Falco (eBPF, kernel-level threat detection)
Layer 6  — Network Security:   VPC Flow Logs, security groups, private subnets
Layer 7  — Node Security:      IMDSv2 enforced, encrypted EBS (gp3), KMS secrets
Layer 8  — Identity:           IRSA (pod-level IAM), GitHub OIDC (keyless CI)
Layer 9  — Secrets:            External Secrets Operator + AWS Secrets Manager
Layer 10 — Container hardening: Non-root user (UID 1000), read-only FS, dropped capabilities
```

### Kyverno ClusterPolicies (Enforce mode)

Three policies are enforced in the `rag`, `production`, and `staging` namespaces:

**1. `disallow-latest-tag`** — Blocks any Pod using the `:latest` image tag.
```yaml
# All containers and initContainers must use a specific version tag
image: "!*:latest"
```

**2. `require-resource-limits`** — Every container must declare CPU and memory limits.
```yaml
resources:
  limits:
    cpu: "?*"
    memory: "?*"
```

**3. `require-non-root`** — All Pods must set `runAsNonRoot: true` in their security context.
```yaml
securityContext:
  runAsNonRoot: true
```

### EKS Hardening

- **KMS encryption** of Kubernetes secrets (etcd-level)
- **IMDSv2 required** on all EC2 nodes (prevents SSRF credential theft)
- **Encrypted EBS volumes** (50 GiB gp3) on all nodes
- **Private node groups** — nodes have no public IP
- **Control plane logs** enabled: `api`, `audit`, `authenticator`, `controllerManager`, `scheduler`
- **Private API endpoint** enabled (public access also allowed — restrict in production)
- **IRSA** (IAM Roles for Service Accounts) for component-level AWS access

### Dockerfile hardening

```dockerfile
# Multi-stage build — no build tools in final image
# Non-root user UID 1000 / GID 2000
# Health check via Python urllib
# No PIP cache, no write bytecode
# EXPOSE only port 8000
```

---

## Observability Stack

### Metrics pipeline

```
Application pods
    │ (Prometheus scrape)
    ▼
Prometheus (kube-prometheus-stack 69.5.2)
    │ 7-day retention, 10 GiB PVC
    │ Alertmanager enabled
    ▼
Grafana (8.10.1)
    │ Datasource: Prometheus (auto-configured)
    │ Credentials from grafana-admin-secret (Kubernetes Secret)
    │ Persistence: 10 GiB PVC
```

### Traces + custom metrics pipeline

```
Application pods (instrumented with OTel SDK)
    │ OTLP gRPC (4317) or HTTP (4318)
    ▼
OpenTelemetry Collector (0.117.3, deployment mode)
    ├── Traces → debug exporter (stdout)
    └── Metrics → Prometheus exporter (:8889)
                    │
                    ▼
                Prometheus scrapes :8889
```

### Runtime security alerts

```
Node kernel events
    │ (eBPF probe)
    ▼
Falco (4.19.0, modern_ebpf driver)
    │ JSON output
    └── stdout → integrate with falcosidekick for alerting (disabled by default)
```

### Vulnerability scanning

```
Running workloads
    │ (continuous, every scan cycle)
    ▼
Trivy Operator (0.27.1)
    ├── VulnerabilityReport CRDs
    ├── ConfigAuditReport CRDs
    └── RbacAssessmentReport CRDs
```

---

## Accessing Dashboards

After `make bootstrap` completes, use port-forwarding to access dashboards locally.

### Option A — Launch all at once

```bash
make dashboard         # or: scripts/dashboard.sh all
```

### Option B — Individual dashboards

```bash
# ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# → https://localhost:8080
# Username: admin
# Password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Grafana
kubectl port-forward svc/grafana -n monitoring 3000:80
# → http://localhost:3000
# Credentials from Kubernetes secret: grafana-admin-secret

# Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090
# → http://localhost:9090

# OpenTelemetry metrics
kubectl port-forward svc/opentelemetry-collector -n observability 8889:8889
# → http://localhost:8889/metrics
```

| Dashboard | URL | Credentials |
|---|---|---|
| ArgoCD | https://localhost:8080 | admin / see above |
| Grafana | http://localhost:3000 | from `grafana-admin-secret` |
| Prometheus | http://localhost:9090 | none |
| OTel Metrics | http://localhost:8889 | none |

---

## Makefile Reference

```bash
make doctor       # Pre-flight check — verify all tools + AWS auth + cluster connectivity
make init         # terraform init (with S3 backend)
make fmt          # terraform fmt -recursive
make validate     # terraform validate
make plan         # terraform plan
make apply        # terraform apply -auto-approve
make destroy      # terraform destroy (with confirmation prompt)
make bootstrap    # Full platform bootstrap (EKS kubeconfig + ArgoCD + root app)
make verify       # Show namespaces, pods, services, ArgoCD applications
make health       # Cluster + component health check (nodes, pods, each namespace)
make dashboard    # Launch all port-forwards (ArgoCD, Grafana, Prometheus)
make logs         # Tail logs (usage: make logs COMPONENT=argocd)
make release      # Lint, commit, and push current changes (GitOps trigger)
make clean        # Remove Terraform cache, Docker layers, Python cache, log files
make output       # terraform output
make refresh      # terraform refresh
make graph        # terraform graph → graph.png (requires graphviz)
```

### Logs per component

```bash
make logs COMPONENT=argocd
make logs COMPONENT=rag
make logs COMPONENT=alb
make logs COMPONENT=external-secrets
make logs COMPONENT=prometheus
make logs COMPONENT=grafana
make logs COMPONENT=kyverno
make logs COMPONENT=falco
make logs COMPONENT=trivy
make logs COMPONENT=otel
make logs COMPONENT=karpenter
make logs COMPONENT=all   # kubectl get pods -A
```

---

## Script Reference

All scripts are in `scripts/` and share common helper functions from `scripts/helpers.sh`.

| Script | Purpose | Key flags |
|---|---|---|
| `helpers.sh` | Shared: logging, colors, retry, timers, checks | (sourced by all others) |
| `bootstrap.sh` | Full bootstrap orchestrator | No args |
| `terraform.sh` | Terraform wrapper | `init\|fmt\|validate\|plan\|apply\|destroy\|output\|refresh\|graph\|state\|clean` |
| `doctor.sh` | Environment pre-flight check | No args |
| `health.sh` | Cluster health report | No args |
| `dashboard.sh` | Port-forward launcher | `grafana\|argocd\|prometheus\|otel\|all` |
| `logs.sh` | Stream pod logs | `<component> [lines]` e.g. `logs.sh rag 500` |
| `destroy.sh` | Safe teardown | Requires typing `DESTROY` |
| `cleanup.sh` | Local workspace cleanup | No args |
| `commit.sh` | Git lint + commit + push | No args |

---

## Terraform Modules

### `modules/vpc`

| Variable | Default | Description |
|---|---|---|
| `project_name` | required | Prefix for all resource names |
| `environment` | required | `dev` / `staging` / `prod` |
| `vpc_cidr` | required | e.g. `10.0.0.0/16` |
| `public_subnets` | required | List of public CIDRs |
| `private_subnets` | required | List of private CIDRs |
| `database_subnets` | required | List of database CIDRs |
| `availability_zones` | required | e.g. `["ap-south-1a", "ap-south-1b"]` |

Outputs: `vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `database_subnet_ids`, `nat_gateway_ip`

### `modules/eks`

| Variable | Default | Description |
|---|---|---|
| `cluster_name` | required | EKS cluster name |
| `cluster_version` | `"1.32"` | Kubernetes version |
| `vpc_id` | required | From VPC module output |
| `private_subnet_ids` | required | From VPC module output |
| `node_instance_types` | `["m7i-flex.large"]` | EC2 instance types |
| `desired_size` | `2` | Initial node count |
| `min_size` | `1` | Minimum nodes |
| `max_size` | `5` | Maximum nodes |

Outputs: `cluster_name`, `cluster_endpoint`, `cluster_arn`, `cluster_certificate_authority`, `oidc_provider_arn`, `oidc_provider_url`, `kms_key_arn`

### `modules/ecr`

Creates ECR repositories with configurable lifecycle policies.

Outputs: `repository_urls` (map of name → URL)

### `modules/github-oidc`

| Variable | Description |
|---|---|
| `github_repo` | `"owner/repo-name"` format |

Creates an OIDC provider for `token.actions.githubusercontent.com` and an IAM role with ECR push/pull permissions, scoped to the specified repository.

Outputs: `github_role_arn`

---

## Kyverno Policies

Policies are stored in `gitops-repo/platform/kyverno/policies/` and deployed via a dedicated ArgoCD Application (`kyverno-policies`).

### `disallow-latest-tag` (ClusterPolicy)

- **Action:** Enforce (blocks non-compliant pods)
- **Scope:** All namespaces
- **Rule:** Containers and initContainers cannot use `:latest` tag
- **Error message:** `"Using image tag 'latest' is not allowed. Use a specific version tag."`

### `require-resource-limits` (ClusterPolicy)

- **Action:** Enforce
- **Scope:** `rag`, `production`, `staging` namespaces
- **Rule:** Every container must define `resources.limits.cpu` and `resources.limits.memory`
- **Error message:** `"CPU and memory limits are required for all containers."`

### `require-non-root` (ClusterPolicy)

- **Action:** Enforce
- **Scope:** `rag`, `production`, `staging` namespaces
- **Rule:** Pod spec must include `securityContext.runAsNonRoot: true`
- **Error message:** `"Containers must not run as root (runAsNonRoot: true required)."`

---

## Secrets Management

### Architecture

```
AWS Secrets Manager
    ├── rag/gemini-api-key  →  GEMINI_API_KEY
    └── rag/api-token       →  API_TOKEN

External Secrets Operator (ESO)
    └── ClusterSecretStore (aws-secrets-manager)
            └── ExternalSecret (rag-secret, namespace: rag)
                    └── Kubernetes Secret (rag-secret)
                            └── Mounted into rag-document-qa pods
```

### IRSA setup for ESO

External Secrets Operator uses an IRSA-annotated service account to assume an IAM role with Secrets Manager `GetSecretValue` permissions. The role ARN is configured in the Helm values:
```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::409837635702:role/external-secrets-irsa-role
```

You must create this IAM role manually or add it to the `modules/eks` Terraform module. The role policy needs:
```json
{
  "Action": ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
  "Resource": "arn:aws:secretsmanager:ap-south-1:409837635702:secret:rag/*"
}
```

### Grafana admin secret

Grafana reads credentials from a pre-existing Kubernetes Secret:
```bash
kubectl create secret generic grafana-admin-secret \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=<your-password> \
  -n monitoring
```

---

## Node Autoscaling with Karpenter

Karpenter (v1.3.2) is installed via ArgoCD and configured to auto-provision EKS nodes based on pending pod demand.

The Karpenter controller uses an IRSA-annotated service account:
```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::409837635702:role/karpenter-irsa-role
```

Private subnets are tagged for Karpenter discovery:
```
karpenter.sh/discovery: enterprise-devsecops-dev
```

To provision `NodePool` and `EC2NodeClass` resources, add them to `gitops-repo/platform/karpenter/` and let ArgoCD sync them.

---

## Tear Down

>  **This is irreversible.** All data, infrastructure, and state will be destroyed.

```bash
make destroy
# Type DESTROY when prompted
```

This runs `scripts/destroy.sh` which:
1. Deletes all ArgoCD Applications
2. Deletes all Ingress objects (releases ALBs)
3. Deletes all LoadBalancer Services
4. Deletes all platform namespaces
5. Runs `terraform destroy`
6. Cleans kubeconfig
7. Prunes Docker images on the local machine

To also destroy the Terraform state backend:
```bash
cd bootstrap
terraform destroy
```

---

## Troubleshooting

### ArgoCD app stuck in Progressing

```bash
kubectl get applications -n argocd
kubectl describe application <app-name> -n argocd
# Check events and sync status
```

### Pod not starting — Kyverno policy violation

```bash
# Check policy violation events
kubectl describe pod <pod-name> -n <namespace>
# Look for: "Error from server: admission webhook... denied"
# Fix: add resource limits, set runAsNonRoot, use versioned image tag
```

### External Secrets not syncing

```bash
kubectl get externalsecret -n rag
kubectl describe externalsecret rag-secret -n rag
# Common causes: IRSA role missing, secret path mismatch, IAM permissions
```

### ECR push failing in CI

- Verify `AWS_ACCOUNT_ID` GitHub secret is correct
- Verify `github-oidc` Terraform module is applied (`terraform output` in `environments/dev`)
- Verify the IAM role trust policy allows your repository: `repo:Debasish-87/CDS:*`

### Nodes not Ready

```bash
kubectl get nodes
kubectl describe node <node-name>
kubectl get pods -n kube-system
# Check aws-node (CNI) and kube-proxy pods
```

### Kyverno blocking all pods

If Kyverno was installed but policies are too strict during initial setup:
```bash
# Temporarily set to Audit mode
kubectl patch clusterpolicy require-non-root \
  --type merge \
  -p '{"spec":{"validationFailureAction":"Audit"}}'
```

### Checking all component health at once

```bash
make health
# or
scripts/health.sh
```

---

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/my-improvement`
3. Make changes, ensure `make doctor` passes
4. Run `make validate` and `make plan` (if touching Terraform)
5. Commit: `make release` (runs lint checks before committing)
6. Open a Pull Request — the `terraform-plan.yaml` workflow will automatically run `fmt`, `validate`, `tflint`, and `checkov` checks

### Code standards

- Terraform: formatted with `terraform fmt`, validated with `terraform validate` + TFLint
- Shell scripts: `set -Eeuo pipefail`, shellcheck recommended
- Docker: multi-stage, non-root, no `:latest` tags
- GitOps manifests: all resources must include `resources.limits`
- All new platform components: deploy via ArgoCD Application in `gitops-repo/platform/`

---

## License

MIT — see [LICENSE](LICENSE) for details.

---

## 👤 Author

**Debasish** — [github.com/Debasish-87](https://github.com/Debasish-87)

---

<p align="center">
  Built with ❤️ using Terraform · ArgoCD · Kubernetes · GitHub Actions · AWS EKS
</p>
