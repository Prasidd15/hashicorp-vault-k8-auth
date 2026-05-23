# HashiCorp Vault — Kubernetes Authentication for AKS

![Vault](https://img.shields.io/badge/HashiCorp-Vault-black?logo=vault)
![Kubernetes](https://img.shields.io/badge/Kubernetes-AKS-326CE5?logo=kubernetes)
![Azure](https://img.shields.io/badge/Azure-AKS-0078D4?logo=microsoftazure)
![License](https://img.shields.io/badge/License-MIT-green)

A production-ready implementation of HashiCorp Vault Kubernetes authentication
for Azure Kubernetes Service (AKS). This repository demonstrates how to
enable AKS pods to securely retrieve secrets from an on-premises Vault cluster
using Kubernetes native pod identity — with no hardcoded credentials,
full audit trail, automated token rotation and Vault Enterprise licensing
efficiency through entity merging.

---

## Problem This Solves

Most teams store secrets in Kubernetes Secrets (base64 only), pipeline
variable groups, or hardcoded in config files. This approach has no audit
trail, no rotation, and anyone with namespace access can read them.

This implementation replaces all of that with:

- Pods prove their identity using their Kubernetes ServiceAccount JWT
- Vault verifies that identity against the K8s API — no passwords needed
- Each application gets a scoped policy — can only read its own secrets
- Tokens are rotated automatically every hour
- Every secret access is logged with pod identity, timestamp and IP

---

## Architecture Overview
AKS Cluster                           On-Premises Vault
─────────────────────────────         ──────────────────────────
vault-system namespace                k8s auth mount
└── token reviewer SA    ──────►   verifies pod JWTs
finance namespace                     policies
├── vault-auth-finance SA           ├── accounts-policy
├── vault-auth-finance-token        └── lending-policy
├── accounts-app pod      ──────►
└── lending-app pod       ──────►   entity (1 per namespace)
↑                             = 1 billable client
vault-secret-rotator
CronJob (hourly rotation)

---

## Key Design Decisions

### Option 2 — Client JWT as Reviewer JWT
Rather than storing a dedicated long-lived token reviewer JWT inside
Vault config, the pod's own JWT is reused by Vault to call the
Kubernetes TokenReview API. This eliminates any stored credentials
in Vault entirely.
Standard approach (Option 3):
Vault stores long-lived reviewer JWT → security risk if Vault is compromised
This implementation (Option 2):
Vault reuses the pod JWT for verification → nothing stored → better posture

### Shared ServiceAccount per Namespace
All pods in a namespace share one vault-auth ServiceAccount. This keeps
operations simple and combined with entity merging results in one billable
Vault Enterprise client per namespace regardless of how many applications
are running.

### Automated Token Rotation
A CronJob runs every hour and rotates the shared token Secret by deleting
and recreating it. Kubernetes issues a brand new JWT. If a token is ever
stolen the maximum window of exposure is one hour. Pods pick up the new
token automatically via kubelet sync — no restarts needed.

### Least Privilege RBAC Throughout
The rotation CronJob Role is locked to the specific secret name using
`resourceNames`. It cannot access any other secret in the namespace.
The vault-system namespace is owned exclusively by the infra team —
application teams have zero access.

---

## Repository Structure
├── kubernetes/
│   ├── namespace/          # Namespace definition with labels
│   ├── serviceaccount/     # Shared vault-auth SA and token Secret
│   ├── rbac/               # ClusterRoleBinding, rotator Role and RoleBinding
│   ├── cronjob/            # Hourly token rotation CronJob
│   └── deployments/        # Example app deployments with vault token mount
│
├── vault/
│   ├── policies/           # Vault HCL policies scoped per application
│   └── scripts/            # Vault configuration and role creation scripts
│
├── pipeline/               # Azure DevOps pipeline for automated SA setup
│
└── docs/                   # Full setup guides, runbooks and architecture docs

---

## What Gets Created

| Resource | Kind | Namespace | Purpose |
|---|---|---|---|
| vault-auth-finance | ServiceAccount | finance | Shared Vault auth identity |
| vault-auth-finance-token | Secret | finance | Long-lived JWT mounted into pods |
| vault-auth-finance-delegator | ClusterRoleBinding | cluster | system:auth-delegator for Option 2 |
| vault-token-rotator-role | Role | finance | Scoped to vault-auth-finance-token only |
| vault-token-rotator-binding | RoleBinding | finance | Binds rotator SA to scoped role |
| vault-secret-rotator | CronJob | finance | Hourly token rotation |
| accounts-policy | Vault Policy | — | Read finance/accounts/* only |
| lending-policy | Vault Policy | — | Read finance/lending/* only |

---

## Prerequisites

- AKS cluster with kubectl configured
- On-premises HashiCorp Vault (v1.9+) with admin access
- Azure CLI installed and logged in
- kubectl connected to your AKS cluster
- cluster-admin access for ClusterRoleBinding creation

---

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/<your-username>/hashicorp-vault-aks-kubernetes-auth.git
cd hashicorp-vault-aks-kubernetes-auth

# 2. Create namespace
kubectl apply -f kubernetes/namespace/

# 3. Create ServiceAccount and token Secret
kubectl apply -f kubernetes/serviceaccount/

# 4. Apply RBAC — requires cluster-admin
kubectl apply -f kubernetes/rbac/

# 5. Deploy CronJob (suspended by default — enable after verification)
kubectl apply -f kubernetes/cronjob/

# 6. Configure Vault auth backend
bash vault/scripts/configure-vault-auth.sh

# 7. Verify
kubectl auth can-i create tokenreviews \
  --as=system:serviceaccount:finance:vault-auth-finance
# Expected: yes
```

---

## Security Highlights

| Control | Detail |
|---|---|
| No stored credentials | Option 2 — pod JWT reused, nothing stored in Vault |
| Stolen token window | Maximum 1 hour — CronJob rotates every hour |
| Least privilege | CronJob role locked to specific secret via resourceNames |
| Namespace isolation | vault-system owned by infra team — app teams have zero access |
| Audit trail | Every secret access logged by Vault with identity and IP |
| Blast radius | Compromise limited to one namespace only |
| Vault licensing | Entity merging — 1 billable client per namespace |

---

## Azure DevOps Pipeline

The `pipeline/` folder contains a parameterised Azure DevOps pipeline
that automates the full SA setup process. Engineers input the subscription,
resource group, cluster name and namespace — the pipeline handles the rest
including kubelogin for AAD-enabled clusters.

Parameters required at run time:
- Azure Subscription ID
- AKS Resource Group
- AKS Cluster Name
- Namespace Name
- Azure Service Connection Name

---

## Documentation

Full guides are available in the `/docs` folder:

| Document | Description |
|---|---|
| 01-vault-kubernetes-auth-setup-guide | End-to-end setup walkthrough |
| 02-vault-jwt-token-options | Three HashiCorp JWT options compared |
| 03-vault-appteam-onboarding-guide | Guide for application teams |
| 04-vault-token-rotation-cronjob | Token rotation use case and runbook |
| 05-vault-token-rotation-notes | Rotation strategy and security analysis |

---

## Technologies

`HashiCorp Vault` `Kubernetes` `AKS` `Azure` `Azure DevOps`
`RBAC` `Secret Management` `Zero Trust` `GitOps` `Bash` `YAML`

---

## License

MIT — free to use, adapt and share.
