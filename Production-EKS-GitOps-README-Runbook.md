# Production EKS GitOps — Project README & Operations Runbook

## 1. Project Overview

**Project:** Production-EKS-GitOps  
**AWS Region:** `ap-south-1`  
**Kubernetes:** Amazon EKS `v1.36.x`  
**Git Branch:** `production-v2`  
**Container Registry:** Amazon ECR  
**CI:** GitHub Actions  
**CD / GitOps:** Argo CD  
**Infrastructure as Code:** Terraform  
**Container:** Docker  
**Application:** Node.js  
**Monitoring:** Prometheus/Grafana stack  
**Security:** Trivy, Gitleaks, IAM OIDC

This project demonstrates an enterprise-style AWS DevOps workflow in which infrastructure is provisioned using Terraform, application images are built and scanned by GitHub Actions, images are stored in Amazon ECR, and Argo CD continuously synchronizes Kubernetes manifests from GitHub into Amazon EKS.

The design avoids long-lived AWS access keys in GitHub Actions. GitHub Actions uses GitHub's OIDC identity token to assume a dedicated AWS IAM role.

---

# 2. High-Level Architecture

```text
                         Developer
                            |
                            v
                     GitHub Repository
              Production-EKS-GitOps / production-v2
                            |
             +--------------+--------------+
             |                             |
             v                             v
       GitHub Actions                  GitOps Manifests
             |                             |
      +------+-------+                     |
      |              |                     |
   npm test       Security                 |
      |          Trivy/Gitleaks            |
      |              |                     |
      +-------+------+                     |
              |                            |
              v                            |
         Docker Build                      |
              |                            |
              v                            |
        GitHub OIDC                        |
              |                            |
              v                            |
          AWS IAM                          |
              |                            |
              v                            |
          Amazon ECR                       |
              |                            |
              |                            v
              |                       Argo CD
              |                            |
              |                     Sync from Git
              |                            |
              +----------------------------+
                                           |
                                           v
                                      Amazon EKS
                                           |
                             +-------------+-------------+
                             |                           |
                       production-app                monitoring
                             |                           |
                       +-----+-----+                  Grafana
                       |           |
                     Pod 1       Pod 2
                       |           |
                       +-----+-----+
                             |
                       ClusterIP Service
```

---

# 3. Repository Structure

Typical project structure:

```text
Production-EKS-GitOps/
│
├── app/
│   ├── package.json
│   ├── package-lock.json
│   ├── Dockerfile
│   └── application source
│
├── k8s/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── namespace.yaml
│
├── argocd/
│   └── application.yaml
│
├── terraform/
│   ├── environments/
│   │   └── dev/
│   │       ├── main.tf
│   │       ├── provider.tf
│   │       ├── versions.tf
│   │       ├── variables.tf
│   │       ├── terraform.tfvars
│   │       └── .terraform.lock.hcl
│   │
│   └── modules/
│       ├── ec2/
│       ├── eks/
│       ├── iam/
│       ├── vpc/
│       ├── security-group/
│       └── ebs-irsa/
│
├── .github/
│   └── workflows/
│       ├── ci-cd.yml
│       └── devsecops.yml
│
└── README / documentation
```

---

# 4. AWS Infrastructure

Terraform is used to provision and manage the AWS infrastructure.

## Main components

### VPC

The project uses a dedicated VPC for the EKS environment.

Typical components include:

- VPC
- Public subnets
- Private subnets
- Route tables
- Internet Gateway
- NAT Gateway
- Security Groups

The EKS worker nodes run inside the private networking design.

### EKS

Cluster:

```text
production-eks
```

Region:

```text
ap-south-1
```

The final verified cluster used:

```text
Kubernetes v1.36.4
```

Worker nodes were healthy and running Amazon Linux 2023.

### EKS Add-ons

The environment includes important EKS add-ons such as:

- CoreDNS
- kube-proxy
- Amazon VPC CNI
- Amazon EBS CSI Driver

---

# 5. Terraform Module Design

The Terraform configuration is organized into reusable modules.

## VPC module

Responsible for:

- VPC
- Subnets
- Routing
- Internet/NAT connectivity

## EKS module

Responsible for:

- EKS cluster
- Node groups
- Kubernetes configuration
- EKS add-ons
- OIDC information required by IAM integrations

## IAM module

Responsible for IAM roles and policies required by the infrastructure.

## EC2 module

Used for EC2-related infrastructure where required by the environment.

## Security Group module

Centralizes network access rules.

## EBS IRSA module

Creates the IAM role used by the EBS CSI controller.

The trust relationship is based on the EKS OIDC provider and the Kubernetes service account:

```text
system:serviceaccount:kube-system:ebs-csi-controller-sa
```

The role uses:

```text
AmazonEBSCSIDriverPolicy
```

---

# 6. Terraform Workflow

From:

```text
terraform/environments/dev
```

initialize:

```bash
terraform init
```

validate:

```bash
terraform validate
```

format:

```bash
terraform fmt -recursive
```

review:

```bash
terraform plan
```

apply:

```bash
terraform apply
```

Destroy only when the environment is no longer required:

```bash
terraform destroy
```

## Important operational rule

Always review `terraform plan` before applying or destroying infrastructure.

For production-like resources, avoid blindly using:

```bash
terraform destroy -auto-approve
```

unless the cleanup is intentional and understood.

---

# 7. ECR

Application repository:

```text
production-eks-app
```

Registry:

```text
538774546514.dkr.ecr.ap-south-1.amazonaws.com
```

Images are tagged using the Git commit SHA.

Example:

```text
production-eks-app:a27ecb9
```

This gives traceability:

```text
Git commit
    ↓
Docker image tag
    ↓
ECR
    ↓
Kubernetes deployment
```

That is preferable to using only a mutable tag such as:

```text
latest
```

because a SHA identifies the exact build.

---

# 8. GitHub Actions CI/CD

GitHub Actions is the CI/CD system used by this project.

The workflow contains stages conceptually similar to:

```text
Test
  ↓
Security Scan
  ↓
Docker Build
  ↓
ECR Push
```

## Test

The Node.js application uses:

```text
node:22-alpine
```

The pipeline executes:

```bash
npm ci
npm test --if-present
```

## Security

Trivy scans the application filesystem for vulnerabilities.

Gitleaks scans the Git repository/history for exposed secrets.

The project previously encountered a Gitleaks Git-history scanning problem caused by an unavailable/incorrect Git revision. The workflow was corrected so the security scan can operate correctly with the repository history available to the runner.

## Docker

The application is built using Docker.

The image is tagged using:

```text
$CI_COMMIT_SHORT_SHA
```

or the equivalent GitHub Actions commit SHA logic.

## ECR push

The final image is pushed to:

```text
production-eks-app
```

---

# 9. GitHub OIDC Authentication

One of the most important security features in the project is GitHub Actions → AWS OIDC authentication.

The project does NOT need long-lived:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

stored in GitHub.

Instead:

```text
GitHub Actions
      |
      | OIDC token
      v
GitHub OIDC Provider
      |
      v
AWS STS
      |
      | AssumeRoleWithWebIdentity
      v
GitHub-Production-EKS-ECR
      |
      v
Amazon ECR
```

The AWS OIDC provider is:

```text
arn:aws:iam::538774546514:oidc-provider/token.actions.githubusercontent.com
```

The IAM role:

```text
GitHub-Production-EKS-ECR
```

The trust policy restricts access to the repository and branch:

```text
repo:Lokeshdagar03/Production-Eks-Gitops:ref:refs/heads/production-v2
```

The audience is:

```text
sts.amazonaws.com
```

This means another GitHub repository or branch cannot automatically assume the same role.

---

# 10. ECR IAM Permissions

The GitHub Actions IAM role has ECR permissions required to authenticate and push images.

Important ECR actions include:

```text
ecr:GetAuthorizationToken
ecr:BatchCheckLayerAvailability
ecr:CompleteLayerUpload
ecr:InitiateLayerUpload
ecr:PutImage
ecr:UploadLayerPart
ecr:BatchGetImage
```

The repository resource is restricted to:

```text
production-eks-app
```

This follows the least-privilege principle better than giving broad ECR administrator permissions.

---

# 11. Kubernetes Application

Namespace:

```text
production-app
```

Application:

```text
production-eks-app
```

The deployment runs two replicas.

Example architecture:

```text
                  Service
              production-eks-app
                     |
              +------+------+
              |             |
              v             v
            Pod 1         Pod 2
```

During verification, the pods were successfully running on separate EKS nodes.

The application exposes:

```text
Port: 3000
```

The Kubernetes Service exposes:

```text
Port: 80
```

Service type:

```text
ClusterIP
```

---

# 12. Application Health Check

The application provides:

```text
/health
```

Expected response:

```json
{
  "status": "UP",
  "application": "Production-EKS-GitOps",
  "version": "1.0.0"
}
```

Kubernetes uses the health endpoint for:

- Liveness probe
- Readiness probe

This prevents Kubernetes from sending traffic to an application that is not ready.

---

# 13. Kubernetes Troubleshooting

## Check pods

```bash
kubectl -n production-app get pods -o wide
```

## Check deployment

```bash
kubectl -n production-app get deployment
```

## Check service

```bash
kubectl -n production-app get svc
```

## Describe a failed pod

```bash
kubectl -n production-app describe pod <pod-name>
```

## View logs

```bash
kubectl -n production-app logs <pod-name>
```

## Check rollout

```bash
kubectl -n production-app rollout status deployment/production-eks-app
```

## Check image

```bash
kubectl -n production-app get deployment production-eks-app \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
echo
```

---

# 14. Important Incident: Docker Desktop vs EKS

One major troubleshooting issue occurred during the project.

The local Kubernetes context was initially:

```text
docker-desktop
```

Therefore:

```bash
kubectl get pods
```

was showing resources from Docker Desktop instead of EKS.

The application tried to pull a private ECR image from Docker Desktop and received:

```text
no basic auth credentials
```

The correct EKS context was restored using:

```bash
aws eks update-kubeconfig \
  --region ap-south-1 \
  --name production-eks
```

Then:

```bash
kubectl config current-context
```

confirmed the EKS cluster.

### Interview lesson

Always check:

```bash
kubectl config current-context
```

before troubleshooting Kubernetes resources.

A large number of apparent Kubernetes problems are actually caused by working against the wrong cluster/context.

---

# 15. Argo CD

Argo CD is the continuous delivery and GitOps component.

Namespace:

```text
argocd
```

The following components were verified as running:

```text
argocd-application-controller
argocd-applicationset-controller
argocd-dex-server
argocd-notifications-controller
argocd-redis
argocd-repo-server
argocd-server
```

## Argo CD Application

Application:

```text
production-eks-app
```

Repository:

```text
https://github.com/Lokeshdagar03/Production-Eks-Gitops.git
```

Branch:

```text
production-v2
```

Kubernetes manifest path:

```text
k8s
```

Destination:

```text
https://kubernetes.default.svc
```

Namespace:

```text
production-app
```

The application uses:

```text
CreateNamespace=true
```

and automated synchronization.

Final verified status:

```text
production-eks-app   Synced   Healthy
```

---

# 16. GitOps Flow

The deployment model is:

```text
Developer
   |
   v
Git commit
   |
   v
GitHub
   |
   v
GitHub Actions
   |
   +---- Test
   |
   +---- Security scan
   |
   +---- Docker build
   |
   +---- Push to ECR
   |
   v
Kubernetes manifest/image reference
   |
   v
Argo CD detects Git change
   |
   v
Argo CD sync
   |
   v
EKS
```

Argo CD is the component that continuously reconciles the Kubernetes state with the desired state stored in Git.

---

# 17. Argo CD CLI

If the Argo CD CLI says:

```text
Argo CD server address unspecified
```

the CLI is not connected to the Argo CD server.

Check the Argo CD service:

```bash
kubectl -n argocd get svc
```

If using port-forwarding:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Then log in to:

```text
localhost:8080
```

The CLI can then be configured against the forwarded endpoint.

---

# 18. Monitoring

The project contains a monitoring namespace:

```text
monitoring
```

Grafana is used for visualization.

The monitoring architecture is conceptually:

```text
Kubernetes
     |
     +---- Metrics
     |
     v
Prometheus
     |
     v
Grafana
```

Grafana can be used to monitor:

- Kubernetes nodes
- CPU
- Memory
- Pods
- Deployments
- Workloads
- Cluster resources

For application observability, the Node.js application also exposes:

```text
/metrics
```

which can be integrated into a Prometheus-based monitoring design.

---

# 19. Grafana Troubleshooting

Check monitoring pods:

```bash
kubectl -n monitoring get pods
```

Check services:

```bash
kubectl -n monitoring get svc
```

Check Grafana:

```bash
kubectl -n monitoring get pods | grep grafana
```

If Grafana is exposed through a LoadBalancer:

```bash
kubectl -n monitoring get svc
```

Look for:

```text
EXTERNAL-IP
```

---

# 20. EBS CSI / IRSA

The EBS CSI driver needs AWS permissions to create/manage EBS volumes.

The project uses IRSA:

```text
Kubernetes Service Account
        |
        v
EKS OIDC Provider
        |
        v
IAM Role
        |
        v
Amazon EBS
```

The service account is:

```text
ebs-csi-controller-sa
```

The trust policy restricts the role to that service account.

This is preferable to giving broad AWS permissions to all worker nodes.

---

# 21. Security Model

Important security practices implemented or planned in the project:

### IAM least privilege

Use dedicated IAM roles for:

- GitHub Actions
- EBS CSI
- EKS components

### OIDC

Avoid long-lived AWS credentials in GitHub.

### ECR

Restrict ECR permissions to the required repository.

### Git secrets

Use Gitleaks to detect accidental secrets.

### Container security

Use Trivy to scan application/container-related content.

### Kubernetes

Recommended additional hardening:

- NetworkPolicies
- Pod Security Standards
- RBAC
- Kubernetes Secrets / external secret management
- Resource requests and limits
- Readiness/liveness probes
- Non-root containers where possible

---

# 22. Resource Requests and Limits

The application deployment uses resource controls.

Example:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

Why?

Requests tell Kubernetes the minimum resources needed for scheduling.

Limits prevent an individual container from consuming unlimited resources.

---

# 23. High Availability

The application runs two replicas.

This provides basic workload redundancy:

```text
Replica 1 → Node A
Replica 2 → Node B
```

If one pod fails, Kubernetes can recreate it.

For stronger production availability, additional controls can be added:

- PodDisruptionBudget
- topology spread constraints
- anti-affinity
- HPA
- multi-AZ node groups
- ingress/load balancer

---

# 24. Current Service Exposure

The application service is:

```text
production-eks-app
```

Type:

```text
ClusterIP
```

This means it is reachable inside the Kubernetes cluster but is not directly exposed to the internet.

This is useful while developing and testing the GitOps deployment.

For external production traffic, an ingress/load-balancer architecture can be added:

```text
Internet
   |
   v
AWS Load Balancer
   |
   v
Ingress Controller
   |
   v
Kubernetes Service
   |
   v
Application Pods
```

---

# 25. Testing the Application Internally

Run:

```bash
kubectl -n production-app run curl-test \
  --rm -it \
  --image=curlimages/curl \
  --restart=Never \
  -- curl http://production-eks-app/health
```

Expected:

```json
{
  "status": "UP",
  "application": "Production-EKS-GitOps",
  "version": "1.0.0"
}
```

This verifies:

```text
Pod
  ↓
Service
  ↓
Application
```

---

# 26. Git Workflow

Current branch:

```text
production-v2
```

Check status:

```bash
git status
```

Check recent commits:

```bash
git log -5 --oneline
```

Add changes:

```bash
git add .
```

Commit:

```bash
git commit -m "Describe the change"
```

Push:

```bash
git push origin production-v2
```

Verify:

```bash
git status
```

Expected:

```text
nothing to commit, working tree clean
```

---

# 27. Deployment Verification After a Git Push

After pushing a Kubernetes change:

### 1. Check GitHub Actions

Confirm:

```text
Test        PASS
Security    PASS
Build       PASS
Push        PASS
```

### 2. Check ECR

```bash
aws ecr describe-images \
  --repository-name production-eks-app \
  --region ap-south-1
```

### 3. Check Argo CD

```bash
kubectl -n argocd get applications
```

Expected:

```text
production-eks-app   Synced   Healthy
```

### 4. Check Kubernetes

```bash
kubectl -n production-app get pods
```

### 5. Check rollout

```bash
kubectl -n production-app rollout status \
  deployment/production-eks-app
```

---

# 28. Common Troubleshooting Runbook

## Pod is Pending

Run:

```bash
kubectl -n production-app describe pod <pod>
```

Check:

- insufficient CPU/memory
- node selectors
- taints/tolerations
- PVC
- scheduling events

---

## ImagePullBackOff

Run:

```bash
kubectl -n production-app describe pod <pod>
```

Check:

```text
Events
```

Typical causes:

- wrong ECR image
- image tag doesn't exist
- ECR authentication
- node IAM permissions
- wrong AWS account/region
- wrong Kubernetes context

First verify:

```bash
kubectl config current-context
```

Then:

```bash
aws ecr describe-images \
  --repository-name production-eks-app \
  --region ap-south-1
```

---

## CrashLoopBackOff

Run:

```bash
kubectl -n production-app logs <pod>
```

Then:

```bash
kubectl -n production-app logs <pod> --previous
```

Check:

- application startup
- environment variables
- secrets
- ports
- database connectivity
- configuration

---

## Service not working

Check:

```bash
kubectl -n production-app get svc
```

Then:

```bash
kubectl -n production-app get endpoints
```

Verify pod labels match the Service selector.

---

## Argo CD OutOfSync

Run:

```bash
kubectl -n argocd get application production-eks-app
```

Then:

```bash
kubectl -n argocd describe application production-eks-app
```

Check:

- Git repository
- branch
- manifest path
- YAML syntax
- Kubernetes permissions
- resource differences

---

## GitHub Actions cannot assume AWS role

Check:

```text
GitHub repository
GitHub branch
OIDC provider
IAM trust policy
audience
subject
```

The trust relationship must match the actual GitHub identity.

For this project the important identity is:

```text
repo:Lokeshdagar03/Production-Eks-Gitops:ref:refs/heads/production-v2
```

Also verify:

```bash
aws iam get-role \
  --role-name GitHub-Production-EKS-ECR \
  --query 'Role.AssumeRolePolicyDocument' \
  --output json
```

---

# 29. ECR Cleanup

If intentionally destroying the lab, ECR repositories cannot normally be deleted while they contain images.

List images:

```bash
aws ecr list-images \
  --repository-name production-eks-app \
  --region ap-south-1
```

Delete images:

```bash
aws ecr batch-delete-image \
  --repository-name production-eks-app \
  --region ap-south-1 \
  --image-ids "$(aws ecr list-images \
    --repository-name production-eks-app \
    --region ap-south-1 \
    --query 'imageIds[*]' \
    --output json)"
```

Then delete the repository if required:

```bash
aws ecr delete-repository \
  --repository-name production-eks-app \
  --region ap-south-1 \
  --force
```

Alternatively, Terraform can manage this behavior with:

```hcl
force_delete = true
```

Only use this when automatic deletion of repository images is acceptable.

---

# 30. Safe Cleanup Order

For a complete lab cleanup, use this general order:

```text
Argo CD / Kubernetes workloads
        ↓
Load Balancers / external resources
        ↓
EKS
        ↓
ECR
        ↓
EC2
        ↓
VPC / networking
        ↓
Terraform-managed infrastructure
```

Before destroying:

```bash
terraform plan
```

Review the resources carefully.

Some AWS resources can leave dependent network interfaces or load balancers behind, which can prevent VPC deletion.

---

# 31. Important Lessons From This Project

### Lesson 1 — Always check Kubernetes context

```bash
kubectl config current-context
```

Docker Desktop and EKS can look similar from the CLI but are completely different clusters.

### Lesson 2 — OIDC removes long-lived cloud credentials

GitHub Actions can authenticate to AWS without storing permanent AWS keys.

### Lesson 3 — Git is the source of truth

Argo CD should reconcile the cluster with Git rather than relying on manual `kubectl apply` operations.

### Lesson 4 — Use immutable image identification

Commit SHA image tags provide deployment traceability.

### Lesson 5 — Terraform manages infrastructure, not every application operation

Terraform is used for infrastructure lifecycle; Argo CD is responsible for Kubernetes application GitOps.

### Lesson 6 — Troubleshoot from the outside in

For an application failure:

```text
Git
 ↓
CI
 ↓
ECR
 ↓
Argo CD
 ↓
Kubernetes
 ↓
Pod
 ↓
Container
 ↓
Application
```

Check each layer systematically.

---

# 32. Interview Explanation — 60 Seconds

> "I built an AWS-based production-style EKS GitOps project using Terraform, GitHub Actions, ECR and Argo CD. Terraform provisions the VPC, EKS cluster, node groups, IAM, security groups and required EKS add-ons. The application is a containerized Node.js service.
>
> GitHub Actions handles CI — it runs tests, security scans using Trivy and Gitleaks, builds the Docker image and pushes it to ECR. For AWS authentication I use GitHub OIDC, so there are no long-lived AWS access keys stored in GitHub.
>
> Argo CD handles the CD side. It watches the Git repository and synchronizes the Kubernetes manifests into EKS. The application runs with two replicas behind a ClusterIP service, with readiness and liveness probes and resource requests and limits.
>
> For observability I use Prometheus/Grafana-based monitoring. The overall design gives me infrastructure as code, secure CI authentication, container security scanning, immutable image traceability and GitOps-based Kubernetes deployments."

---

# 33. Production Improvements / Next Phase

The core project is complete. Possible next improvements are:

1. AWS Load Balancer Controller
2. Ingress with Route 53
3. ACM TLS certificates
4. HPA
5. PodDisruptionBudget
6. NetworkPolicies
7. Kubernetes RBAC hardening
8. Secrets Manager / External Secrets
9. CloudWatch Container Insights
10. Prometheus alerting
11. Alertmanager
12. Loki for logs
13. Distributed tracing
14. Multi-AZ node groups
15. Karpenter
16. Backup/restore strategy
17. Terraform remote state with S3 + DynamoDB/state locking approach appropriate to the current Terraform version
18. Argo CD ApplicationSet
19. Separate dev/staging/prod environments
20. Pull-request based GitOps promotion

These are enhancements, not prerequisites for the current working project.

---

# 34. Final Project Health Checklist

| Component | Status |
|---|---|
| AWS VPC | Complete |
| EKS cluster | Complete |
| EKS nodes | Healthy |
| Kubernetes v1.36.x | Complete |
| EKS add-ons | Complete |
| IAM | Complete |
| EBS CSI / IRSA | Complete |
| ECR | Complete |
| GitHub OIDC | Working |
| GitHub Actions | Working |
| Trivy | Integrated |
| Gitleaks | Integrated |
| Docker build | Working |
| Image push | Working |
| Argo CD | Running |
| Argo CD Application | Synced |
| Application namespace | Created by GitOps |
| Application replicas | Running |
| Kubernetes Service | Working |
| Health endpoint | Working |
| Monitoring namespace | Present |
| Grafana | Present |
| GitOps flow | Working |

---

# 35. Golden Commands

Keep these commands handy during interviews and operations:

```bash
# AWS identity
aws sts get-caller-identity

# EKS kubeconfig
aws eks update-kubeconfig \
  --region ap-south-1 \
  --name production-eks

# Kubernetes context
kubectl config current-context

# Nodes
kubectl get nodes -o wide

# Application
kubectl -n production-app get pods -o wide
kubectl -n production-app get svc
kubectl -n production-app get deployment

# Logs
kubectl -n production-app logs <pod-name>

# Describe
kubectl -n production-app describe pod <pod-name>

# Rollout
kubectl -n production-app rollout status \
  deployment/production-eks-app

# Argo CD
kubectl -n argocd get applications

# Monitoring
kubectl -n monitoring get pods
kubectl -n monitoring get svc

# ECR
aws ecr list-images \
  --repository-name production-eks-app \
  --region ap-south-1

# Terraform
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
terraform destroy

# Git
git status
git log -5 --oneline
git add .
git commit -m "Describe change"
git push origin production-v2
```

---

# 36. Project Completion Statement

The project successfully demonstrates a complete cloud-native DevOps workflow:

```text
Infrastructure as Code
        +
Secure CI
        +
Container Security
        +
Amazon ECR
        +
GitHub OIDC
        +
Amazon EKS
        +
Argo CD GitOps
        +
Prometheus/Grafana Monitoring
        =
Production-style DevOps Platform
```

The verified deployment reached:

```text
Argo CD:
production-eks-app → Synced / Healthy

Kubernetes:
2 application replicas → Running

Service:
production-eks-app → ClusterIP

Cluster:
production-eks → Healthy
```

This document should be treated as the primary operational reference for the project.
