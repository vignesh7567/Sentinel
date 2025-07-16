# Rapyd Sentinel PoC

This repository provides a production‑style proof‑of‑concept (PoC) for **Rapyd Sentinel**, a threat intelligence platform split into two isolated AWS domains:

- **Gateway Layer (Public)**: Hosts internet‑facing APIs and reverse proxies in a dedicated public VPC.
- **Backend Layer (Private)**: Runs internal services and sensitive workloads in a private VPC with no internet exposure.

Both environments are deployed in AWS **eu-west-1**, each in its own VPC and Amazon EKS cluster. Private networking, cross‑account patterns, and secure service access are demonstrated end‑to‑end.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Getting Started](#getting-started)
3. [Objectives](#objectives)
4. [1. Terraform: Two Isolated VPCs](#1-terraform-two-isolated-vpcs)
   - 1.1. Module Structure
   - 1.2. Variables & Outputs
   - 1.3. VPC & Subnet Definitions
   - 1.4. NAT Gateway Setup
5. [2. Deploy Two EKS Clusters](#2-deploy-two-eks-clusters)
   - 2.1. Cluster Module Inputs
   - 2.2. Node Group Configuration
6. [3. Secure Private Networking](#3-secure-private-networking)
   - 3.1. VPC Peering
   - 3.2. Route Tables
   - 3.3. Security Groups
7. [4. Application Deployment](#4-application-deployment)
   - 4.1. Backend Service Details
   - 4.2. NetworkPolicy Example
   - 4.3. Gateway Proxy Details
8. [5. Private AWS Service Access](#5-private-aws-service-access)
   - 5.1. VPC Endpoint Configuration
   - 5.2. IAM Role & Policies
9. [6. DNS & Resolver Controls](#6-dns--resolver-controls)
   - 6.1. Private Route 53 Sharing
   - 6.2. Route 53 Resolver Endpoints
   - 6.3. Validation & Troubleshooting
   - 6.4. Security Considerations
10. [7. Cross-Account Patterns](#7-cross-account-patterns)
    - 7.1. IAM Trust Relationships
    - 7.2. SSM Access Flow
11. [8. CI/CD Pipeline](#8-cicd-pipeline)
    - 8.1. GitHub Actions Workflow
    - 8.2. Terraform OIDC Setup
    - 8.3. Kubernetes Deployment Steps
12. [9. Design, Security, & Trade‑offs](#9-design-security--trade-offs)
13. [10. Networking Requirements & Trust Policies](#10-networking-requirements--trust-policies)
14. [11. Detailed Operational Instructions & Justifications](#11-detailed-operational-instructions--justifications)
15. [12. Next Steps & Cost Optimization](#12-next-steps--cost-optimization)

---

## Prerequisites

- **AWS CLI** configured with profiles for **Account A** (orchestration) and **Account B** (resources), region `eu-west-1`.
- **Terraform v1.5+** installed.
- **kubectl v1.24+** installed.
- **GitHub** account with permissions for Actions and Container Registry.
- **AWS Accounts**:
  - **Account A**: Runs Ansible/Chef/Octopus, GitHub OIDC.
  - **Account B**: Hosts all AWS resources.

## Getting Started

1. **Clone the repository**:
   ```bash
   git clone https://github.com/vignesh7567/Sentinel.git
   ```
2. **Switch to Account B context** (Terraform & eksctl):
   ```bash
   export AWS_PROFILE=account-b
   export AWS_REGION=eu-west-1
   ```
3. **Initialize & deploy Terraform**:
   ```bash
   cd terraform
   terraform init
   terraform plan -out=plan.tf
   terraform apply -input=false plan.tf
   ```
4. **Connect kubectl to clusters**:
   ```bash
   aws eks update-kubeconfig --name eks-gateway --region eu-west-1 --profile account-a
   aws eks update-kubeconfig --name eks-backend --region eu-west-1 --profile account-b
   ```
5. **Deploy Kubernetes workloads** via CI/CD or manually:
   ```bash
   kubectl apply -f k8s/backend/
   kubectl apply -f k8s/gateway/
   ```

---

## Objectives

1. Use Terraform to build two isolated VPCs
2. Deploy two EKS clusters (one per VPC)
3. Set up secure private networking between them
4. Deploy a basic app in the backend and a proxy in the gateway
5. Implement secure private access to AWS managed services from private subnets
6. Demonstrate and document DNS and resolver controls
7. Demonstrate cross-account patterns using IAM roles via Terraform
8. Wire everything up with a CI/CD pipeline
9. Document design rationale, security decisions, and trade-offs
10. Provide example Terraform code, IAM trust policies, and step-by-step documentation of access grants and networking requirements
11. How to clone and run the project
12. How networking is configured between VPCs & clusters
13. How the proxy talks to the backend
14. NetworkPolicy explanation and security model
15. How private subnets connect to AWS services/resources exclusively via private endpoints
16. Describe and validate DNS scenarios (Route 53 sharing, resolver endpoints, on-prem domain)
17. Cross-account establishment workflows and IAM role assumptions
18. CI/CD pipeline structure and job flow
19. Trade-offs made due to the 3-day PoC time constraint
20. Optional cost optimization notes (NAT usage, instance types, load balancer selection)
21. Future enhancements (TLS/mTLS, observability, GitOps, ingress controllers, service mesh, Vault, etc.)

---

## 1. Terraform: Two Isolated VPCs Terraform: Two Isolated VPCs

### 1.1. Module Structure

```
sentinal/
├── main.tf
├── variables.tf
├── outputs.tf
├── endpoints-sg.tf
├── endpoints.tf
├── providers.tf
├── workloads.tf
├── modules/
│ ├── vpc/
│ │ ├── variables.tf
│ │ ├── main.tf
│ │ └── outputs.tf
│ ├── eks-cluster/
│ │ ├── variables.tf
│ │ ├── main.tf
│ │ └── outputs.tf
│ ├── iam/
│ │ ├── variables.tf
│ │ ├── main.tf
│ │ └── outputs.tf
├── README.md
```

### 1.2. Variables & Outputs

- **modules/vpc/variables.tf**:
  ```hcl
  variable "name" { type = string }
  variable "cidr" { type = string }
  variable "azs"  { type = list(string) }
  ```
- **modules/vpc/outputs.tf**:
  ```hcl
  output "vpc_id"                 { value = aws_vpc.this.id }
  output "private_subnets"        { value = aws_subnet.private.[*].id }
  output "private_route_table_ids"{ value = aws_route_table.private[*].id }
  ```

### 1.3. VPC & Subnet Definitions

**modules/vpc/main.tf** excerpt:

```hcl
resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.name}-vpc"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.azs)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]
  tags = {
    Name = "${var.name}-private-${var.azs[count.index]}"
  }
}
```

### 1.4. NAT Gateway Setup

```hcl
resource "aws_eip" "nat" {
  count = length(var.azs)
  domain = "vpc"
  tags = {
    Name = "${var.name}-nat-eip-${count.index}"
  }
}

resource "aws_nat_gateway" "this" {
  count         = length(var.azs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags = {
    Name = "${var.name}-nat-gw-${count.index}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = {
    Name = "${var.name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
```

---

## 2. Deploy Two EKS Clusters

### 2.1. Cluster Module Inputs

```hcl
module "eks_gateway" {
  source                 = "./modules/eks-cluster"
  cluster_name           = "eks-gateway"
  eks_version            = "1.27"
  vpc_id                 = module.vpc_gateway.vpc_id
  subnet_ids             = module.vpc_gateway.private_subnet_ids
  cluster_role_arn    = module.iam_roles.gateway_cluster_role_arn
  node_role_arn       = module.iam_roles.gateway_node_role_arn
}
```

### 2.2. Node Group Configuration

```hcl
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids
  #skip_role_validation = true

  scaling_config {
    desired_size = var.node_group_desired
    max_size     = var.node_group_desired + 1
    min_size     = 1
  }

  instance_types = var.node_group_instance_types
}
```

---

## 3. Secure Private Networking

### 3.1. VPC Peering

```hcl
resource "aws_vpc_peering_connection" "gw_to_be" {
  vpc_id        = module.vpc_gateway.vpc_id
  peer_vpc_id   = module.vpc_backend.vpc_id
  auto_accept   = true
  tags = {
    Name = "gateway-backend-peering"
  }
}
```

### 3.2. Route Tables

```hcl
resource "aws_route" "gateway_to_backend" {
  count = length(module.vpc_gateway.private_route_table_ids)
  route_table_id            = module.vpc_gateway.private_route_table_ids[count.index]
  destination_cidr_block    = var.backend_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.gw_to_be.id
}

resource "aws_route" "backend_to_gateway" {
  count = length(module.vpc_backend.private_route_table_ids)
  route_table_id            = module.vpc_backend.private_route_table_ids[count.index]
  destination_cidr_block    = var.gateway_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.gw_to_be.id
}
```

### 3.3. Security Groups

```hcl
resource "aws_security_group" "endpoint_sg_gateway" {
  name        = "gateway-endpoints-sg"
  description = "Allow HTTPS from private subnets"
  vpc_id      = module.vpc_gateway.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.gateway_private_subnets
    description = "EKS nodes to endpoints"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "gateway-endpoints-sg"
  }
}
```

---

## 4. Application Deployment

### 4.1. Backend Service Details

```hcl
resource "kubernetes_deployment" "backend_app" {
  provider = kubernetes.backend
  depends_on = [ module.eks_backend, kubernetes_namespace.backend ]
  metadata {
    name      = "backend-app"
    namespace = kubernetes_namespace.backend.metadata[0].name
    labels    = { app = "backend" }
  }

  spec {
    replicas = 2
    selector { match_labels = { app = "backend" } }

    template {
      metadata { labels = { app = "backend" } }
      spec {
        container {
          name  = "http-echo"
          image = "hashicorp/http-echo:0.2.3"
          args  = ["-text=Hello from backend"]
          port { container_port = 5678 }
        }
      }
    }
  }
}
```
### 4.2. Gateway Proxy Details

```hcl
resource "kubernetes_deployment" "gateway_proxy" {
  provider = kubernetes.gateway
  depends_on = [ module.eks_gateway, kubernetes_config_map.nginx_conf ]
  metadata {
    name      = "gateway-proxy"
    namespace = kubernetes_namespace.gateway.metadata[0].name
    labels    = { app = "gateway" }
  }

  spec {
    replicas = 2
    selector { match_labels = { app = "gateway" } }

    template {
      metadata { labels = { app = "gateway" } }
      spec {
        container {
          name  = "nginx"
          image = "nginx:latest"
          port  { container_port = 80 }

          volume_mount {
            name       = "nginx-config"
            mount_path = "/etc/nginx/conf.d"
          }
        }
        volume {
          name = "nginx-config"
          config_map { name = kubernetes_config_map.nginx_conf.metadata[0].name }
        }
      }
    }
  }
}
```

---

## 5. Private AWS Service Access

### 5.1. VPC Endpoint Configuration

```hcl
resource "aws_vpc_endpoint" "gw_s3" {
  vpc_id            = module.vpc_gateway.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc_gateway.private_route_table_ids
  tags = {
    Name = "gateway-s3-gateway-endpoint"
  }
}
```

### 5.2. IAM Role & Policies

```hcl
resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

---

## 6. DNS & Resolver Controls

### 6.1. Private Route 53 Sharing

1. In **Account A**, share the private hosted zone via RAM:
   ```bash
   aws ram create-resource-share --name "xyz-share" \
     --resource-arns arn:aws:route53:::hostedzone/ZONEID \
     --principals arn:aws:iam::ACCOUNT_B_ID:root
   ```
2. In **Account B**, accept the share:
   ```bash
   aws ram accept-resource-share-invitation --resource-share-invitation-arn INVITE_ARN
   ```
3. Associate the shared zone with VPCs in both regions.

### 6.2. Route 53 Resolver Endpoints

```hcl
# Outbound (AWS → on-prem)
resource "aws_route53_resolver_endpoint" "outbound" {
  name               = "outbound-abc"
  direction          = "OUTBOUND"
  vpc_id             = module.vpc_gateway.vpc_id
  security_group_ids = [module.eks_gateway.cluster_security_group_id]
  ip_address { subnet_id = module.vpc_gateway.private_subnets[0] }
  ip_address { subnet_id = module.vpc_gateway.private_subnets[1] }
}
# Resolver Rule for abc.org
resource "aws_route53_resolver_rule" "abc_forward" {
  name     = "forward-abc"
  domain_name = "abc.org"
  rule_type   = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound.id
  target_ips { ip = "10.0.100.10" } # on-prem DNS server
}
```

### 6.3. Validation & Troubleshooting

```bash
# Test from pod
kubectl exec -n backend -it $(kubectl get pod -n backend -o jsonpath='{.items[0].metadata.name}') -- nslookup xyz.com
kubectl exec -n gateway -it $(kubectl get pod -n gateway -o jsonpath='{.items[0].metadata.name}') -- nslookup abc.org
# Ping endpoints, check /etc/resolv.conf
```

### 6.4. Security Considerations

- Restrict RAM shares and resolver endpoints to minimal security groups.
- Enable CloudWatch Logs for Route 53 Resolver query logging.
- Audit cross-account DNS actions.

---

## 7. Cross-Account Patterns

### 7.1. IAM Trust Relationships

**Terraform snippet in Account B** to allow Account A assume role:

```hcl
resource "aws_iam_role" "orchestration_role" {
  name = "OrchestrationRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { AWS = "arn:aws:iam::${var.account_a_id}:root" },
      Action    = "sts:AssumeRole"
    }]
  })
}
# Attach SSM and EC2 permissions
```

### 7.2. SSM Access Flow

1. **Account A** calls:
   ```bash
   aws sts assume-role --role-arn arn:aws:iam::ACCOUNT_B_ID:role/OrchestrationRole --role-session-name deploy
   ```
2. Use returned temporary creds to call SSM:
   ```bash
   aws ssm send-command --document-name "AWS-RunShellScript" ...
   ```
3. EC2 instances in private subnets with no public IP are managed entirely via SSM.

---

## 8. CI/CD Pipeline

### 8.1. GitHub Actions Workflow

```yaml
name: infra-and-app
on: [push]
jobs:
  terraform:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
    - uses: actions/checkout@v3
    - name: Configure AWS Credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        role-to-assume: arn:aws:iam::ACCOUNT_B_ID:role/GitHubOIDCDeployRole
        aws-region: eu-west-1
    - uses: hashicorp/setup-terraform@v2
      with: terraform_version: 1.5.0
    - run: terraform init
    - run: terraform validate
    - run: tflint
    - run: terraform plan -out=tfplan
    - run: terraform apply -input=false tfplan

  kubernetes:
    needs: terraform
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - uses: azure/setup-kubectl@v3
      with: version: v1.24.0
    - run: kubeval k8s/backend/*.yaml
    - run: kubectl apply --dry-run=client -f k8s/backend/
    - run: kubectl apply -f k8s/backend/
    - run: kubeval k8s/gateway/*.yaml
    - run: kubectl apply --dry-run=client -f k8s/gateway/
    - run: kubectl apply -f k8s/gateway/
```

### 8.2. Terraform OIDC Setup

1. **Create IAM OIDC identity provider** in Account B pointing to `token.actions.githubusercontent.com`.
2. **Define IAM role** with trust condition matching repo, ref, and environment.
3. Attach admin or scoped policies.

### 8.3. Kubernetes Deployment Steps

1. Validate manifests with `kubeval`.
2. Dry‑run apply to ensure correctness.
3. Live apply into both clusters.

---

## 9. Design, Security, & Trade‑offs

- **Modularity** via Terraform modules for VPC, networking, EKS, IAM.
- **Zero public exposure**: Private subnets, no public EC2, strict SGs.
- **Service access** via VPC endpoints (S3, SSM, SecretsManager, KMS).
- **NetworkPolicy** to enforce pod‑level communication boundaries.

**Trade‑offs** (3‑day PoC):

- Chose VPC Peering over Transit Gateway for rapid delivery.
- Used t3.medium node types vs. production instances.
- Excluded full service mesh, observability, and advanced ingress.

---

## 10. Networking Requirements & Trust Policies

- **CIDR blocks**: 10.0.0.0/16 (gateway), 10.1.0.0/16 (backend).
- **Subnets**: 2 private per AZ, 2 AZs each.
- **NAT Gateways**: One per AZ for outbound traffic.
- **VPC Peering**: Bidirectional routes in private route tables.
- **Security Groups**: Scoped to cluster SGs; restrict port 80 ingress.
- **IAM Trust**: Role in Account B assumable by Account A via OIDC or STS.

---

## 11. Detailed Operational Instructions & Justifications

This section provides actionable instructions and rationale for each critical operational concern, ensuring clarity on setup, design choices, and future enhancements.

### a. How to Clone and Run the Project

**Steps to get started quickly:**

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-org/rapyd-sentinel-poc.git
   cd rapyd-sentinel-poc
   ```
2. **Configure AWS Profiles:**
   - **Account B** (resources deployment):
     ```bash
     export AWS_PROFILE=account-b
     export AWS_REGION=eu-west-1
     ```
   - **Account A** (orchestration, optional):
     ```bash
     export AWS_PROFILE=account-a
     ```
3. **Initialize Terraform:**
   ```bash
   cd terraform
   terraform init
   ```
4. **Review & Apply Terraform:**
   ```bash
   terraform plan -out=plan.tf
   terraform apply -input=false plan.tf
   ```
5. **Set up Kubernetes contexts:**
   ```bash
   aws eks update-kubeconfig --name eks-gateway --profile account-b
   aws eks update-kubeconfig --name eks-backend --profile account-b
   ```
6. **Deploy workloads:**
   ```bash
   kubectl apply -f k8s/backend/    # backend namespace
   kubectl apply -f k8s/gateway/    # gateway namespace
   ```

> **Justification:** This step-by-step workflow standardizes environment setup and ensures reproducibility across teams.

### b. How Networking is Configured Between VPCs & Clusters

- **VPC CIDRs**: `10.10.0.0/16` for Gateway, `10.20.0.0/16` for Backend.
- **Subnets**: Two private subnets per AZ (eu-west-1a, eu-west-1b), no public subnets hosting EC2/EKS nodes.
- **NAT Gateways**: Each VPC deploys NAT Gateways in public subnets to allow controlled outbound internet for OS updates and AWS API calls when endpoints aren’t used.
- **VPC Peering**: A direct peering connection is established with auto-accept on both sides, and private route tables updated in each VPC:
  - Gateway private route table: route to Backend CIDR via peering
  - Backend private route table: route to Gateway CIDR via peering
- **Security Groups**: Cluster SGs reference each other to allow only required traffic (e.g., SG-backend ingress from SG-gateway on port 80).

> **Justification:** This design isolates external and internal traffic while enabling secure, low-latency communication across clusters without public exposure.

### c. How the Proxy Talks to the Backend

1. **Service Discovery:**
   - Backend Service: `backend-svc.backend.svc.cluster.local`
   - The proxy deployment defines an environment variable `BACKEND_URL` pointing to this DNS name.
2. **Traffic Flow:** Client → AWS ALB (gateway VPC) → proxy pods → backend pods via VPC peering.
3. **Security Enforcement:**
   - Backend SG only allows ingress from proxy SG on port 80.
   - Kubernetes NetworkPolicy in backend namespace further restricts ingress to pods labeled `app: proxy`.

> **Justification:** Using Kubernetes DNS and SGs avoids IP hardcoding and leverages native cluster discovery, simplifying failover and scaling.

### d. NetworkPolicy Explanation and Security Model

- **Default Deny**: Two policies applied in `backend` namespace:
  1. **Ingress Policy**: Only allows traffic from pods in `gateway` namespace on port 80.
  2. **Egress Policy**: Allows only traffic to CIDRs of VPC endpoints (e.g., SSM, S3) and other necessary service subnets.
- **Defense in Depth**: Combines AWS-level SG controls with pod-level NetworkPolicies for layered security.

```yaml
# Example Ingress Policy (backend)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-gateway
  namespace: backend
spec:
  podSelector:
    matchLabels: {}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: gateway
    ports:
    - protocol: TCP
      port: 80
```

> **Justification:** Pod-level policies reduce blast radius in case of compromised pods or misconfigured SGs.

### e. How Private Subnets Connect to AWS Services Privately

- **Interface VPC Endpoints** for SSM, EC2 messages, Secrets Manager, KMS, and Secrets encryption via AWS PrivateLink.
- **Gateway Endpoint** for S3, enabling S3 API calls without NAT.
- **Private DNS Enabled**: Ensures AWS SDKs transparently resolve service endpoints to private IPs.
- **IAM Role Attachments**: Node IAM roles include `AmazonSSMManagedInstanceCore` to allow SSM agent communication.

```hcl
resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = module.vpc_backend.vpc_id
  service_name      = "com.amazonaws.eu-west-1.ssm"
  private_dns_enabled = true
  subnet_ids        = module.vpc_backend.private_subnets
  security_group_ids = [module.eks_backend.cluster_security_group_id]
}
```

> **Justification:** This approach removes internet egress for management and data-plane tasks, meeting compliance and least-privilege requirements.

### f. DNS Scenarios

1. **Private Hosted Zone (xyz.com)**
   - Shared via AWS RAM from Account A to Account B.
   - Associated with target VPCs in Account B (London, Ohio) to enable native resolution.
2. **On-Premise Domain (abc.org)**
   - **Outbound Resolver Endpoint** in AWS VPC to forward queries to on-prem DNS.
   - **Resolver Rule** created mapping `abc.org` queries to on-prem DNS IPs.
3. **Validation**:
   ```bash
   kubectl exec -n backend -it <pod> -- nslookup xyz.com
   kubectl exec -n gateway -it <pod> -- nslookup abc.org
   ```

> **Justification:** Using Route 53 Resolver integrates hybrid DNS seamlessly, supporting multi-account and on-prem scenarios.

### g. Cross-Account Establishment

- **IAM Role** in Account B (`OrchestrationRole`) with trust policy allowing principals from Account A or GitHub OIDC.
- **Trust Policy Example:**
  ```hcl
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { AWS = "arn:aws:iam::ACCOUNT_A_ID:root" },
      Action    = "sts:AssumeRole"
    }]
  })
  ```
- **Role Assumption Workflow:**
  1. Account A runs `aws sts assume-role` → obtains temporary creds.
  2. Executes SSM commands or Terraform applies in Account B without storing long-lived keys.

> **Justification:** Centralizes orchestration credentials and leverages AWS-native cross-account security, eliminating SSH keys.

### h. CI/CD Pipeline Structure

**Two-stage workflow** in GitHub Actions:

1. **Infrastructure Stage** (`terraform`):
   - **Actions:** checkout, OIDC auth, terraform init/validate/tflint, plan & apply.
2. **Application Stage** (`kubernetes`):
   - **Actions:** checkout, setup-kubectl, kubeval validation, dry-run and apply for backend & gateway manifests.

```yaml
jobs:
  terraform:
    steps:
      # OIDC-based AWS auth
      - run: terraform init
      - run: terraform validate && tflint
      - run: terraform plan -out=tfplan && terraform apply -input=false tfplan
  kubernetes:
    needs: terraform
    steps:
      - run: kubeval k8s/**/*.yaml
      - run: kubectl apply -f k8s/backend/
      - run: kubectl apply -f k8s/gateway/
```

> **Justification:** Separating infra and app stages improves clarity, ensures infra is provisioned before deployments, and leverages GitHub’s OIDC for secure auth.

### i. Trade-offs Due to the 3-Day Limit

| Decision              | Trade-off                                              |
| --------------------- | ------------------------------------------------------ |
| VPC Peering vs. TGW   | Faster setup; limited scalability to 125 peering links |
| t3.medium Nodes       | Quick launch; not optimized for high-throughput loads  |
| Minimal Observability | Saves time; lacks centralized logging & metrics        |

> **Justification:** Prioritized delivery speed and clarity over full production-grade features given time constraints.

### j. Cost Optimization Notes

- **NAT Gateways:** Consider central NAT or reducing to one AZ to cut costs.
- **Compute:** Use Spot Instances or smaller instance types for non-critical workloads.
- **Load Balancer Choice:** NLB for stable pricing per connection; reuse ALB across services where possible.

> **Justification:** Balancing cost savings with reliability, especially for a PoC environment.

### k. Future Enhancements

- **mTLS/TLS**: Deploy cert-manager and integrate with AWS ACM for end-to-end encryption.
- **Observability**: Add Prometheus + Grafana + AWS X-Ray for metrics, logs, and tracing.
- **GitOps**: Implement Argo CD or Flux for fully declarative rollouts.
- **Service Mesh**: Evaluate Istio or Linkerd for advanced traffic management.
- **Secrets Management**: Integrate Vault or Kubernetes Secrets encryption provider.

> **Justification:** These additions align with production hardening, observability, and secure practices for a mature microservices platform.

---

## 12. Next Steps & Cost Optimization

This section outlines actionable next steps for production hardening, as well as cost optimization strategies specific to this PoC.

### a. TLS/mTLS and Certificate Management

- **Deploy cert-manager** in both clusters to automate TLS certificate issuance.
- **Integrate AWS Certificate Manager (ACM)** with cert-manager’s `acme-dns` solver or use `service.beta.kubernetes.io/aws-load-balancer-ssl-cert` annotation for ALB.
- **mTLS**: Evaluate Istio or Linkerd to enforce mutual TLS at the service mesh layer.

### b. Observability & Monitoring

- **Metrics**: Deploy Prometheus Operator with custom `ServiceMonitor` resources for node and pod metrics.
- **Logging**: Integrate Fluentd or FireLens to ship container logs to CloudWatch Logs or Elasticsearch.
- **Distributed Tracing**: Use AWS X-Ray Daemon or OpenTelemetry Collector as a sidecar for tracing requests through the proxy and backend.

### c. GitOps & Deployment Automation

- **Argo CD** or **Flux**: Install a GitOps controller in each cluster, pointing to the `k8s/` directory in this repo for declarative app delivery.
- **Helm**: Package proxy and backend manifests into Helm charts for versioned releases.

### d. Ingress Controllers & Service Mesh

- **Ingress NGINX**: Deploy the community ingress controller for advanced path-based routing, WAF integration, and custom annotations.
- **Service Mesh**: Pilot Istio or Linkerd to add traffic shaping, retries, and circuit breaking.

### e. Secrets Management & Vault Integration

- **HashiCorp Vault**: Install the Vault Agent Injector to mount secrets into pods dynamically.
- **AWS Secrets Manager**: Use Kubernetes External Secrets (KES) to sync Secrets Manager secrets into Kubernetes `Secret` objects.

### f. Cost Optimization Notes

- **Central NAT Gateway**: Migrate to a shared NAT in a networking account to reduce per-AZ NAT costs.
- **Compute Savings**: Use Spot Instances or Savings Plans for long-running EKS node groups.
- **Load Balancers**: Consolidate ALBs with path-based routing; consider NLB or Gateway Load Balancer for low-latency use cases.
- **Resource Sizing**: Right-size nodes and downscale non-production clusters during off-hours to save on hourly costs.

### g. Future Experimental Enhancements

- **Chaos Engineering**: Integrate LitmusChaos or AWS Fault Injection Simulator to test resilience.
- **Policy Enforcement**: Deploy Open Policy Agent (Gatekeeper) for admission control policies.
- **AI/ML Integration**: Leverage AWS SageMaker endpoints in the backend for advanced threat detection.

> **Justification:** These enhancements will transition the PoC toward a production‑ready posture by adding security, reliability, and operational maturity, while optimizing ongoing costs.

---

Kubernetes configuration to execute pods and get the output:

Run these commands in Powershell:

```PowerShell
1. Configure your kubeconfig contexts
Make sure you have two contexts — one for each cluster:
# Backend cluster
aws eks update-kubeconfig \
  --region eu-west-1 \
  --name eks-backend \
  --alias backend

# Gateway cluster
aws eks update-kubeconfig \
  --region eu-west-1 \
  --name eks-gateway \
  --alias gateway

You can list them with:
'kubectl config get-contexts'

2. Check that Kubernetes nodes & system pods are running
A. Backend cluster
kubectl --context backend get nodes
kubectl --context backend get pods -n kube-system
You should see your worker nodes in Ready state and the CoreDNS pods Running.

B. Gateway cluster
kubectl --context gateway get nodes
kubectl --context gateway get pods -n kube-system

3. Verify the backend service itself
A. List your backend workloads
kubectl --context backend get all -n backend
# Should see Deployment/backend-app and Service/backend-svc

B. Port‑forward the ClusterIP locally
Since backend-svc is only a ClusterIP, you can’t curl it from your laptop directly. Instead:
kubectl --context backend -n backend port-forward svc/backend-svc 8080:80

In another terminal, run:
curl http://localhost:8080/
# → "Hello from backend"
This proves the app is running inside the cluster.

4. Test the full flow via the gateway LoadBalancer
A. Get the external address:
kubectl --context gateway -n gateway get svc gateway-lb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

Store it in a shell variable:
$LB = kubectl --context gateway -n gateway get svc gateway-lb -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"

Inspect the variable:
Write-Output $LB

Invoke a web request (PowerShell’s built‑in):
Invoke-WebRequest -Uri "http://$LB" -UseBasicParsing
(or)
curl "http://$LB"
```