# Coffee-shop
## 1. Summary: 
- Reference repository: [go-coffeeshop](https://github.com/thangchung/go-coffeeshop/tree/main)
- Overall flow

![overall-flow](/images/coffeeshop.svg)
### 1.1 Development
#### [Resource](/dev/)
- Include
    - docker-compose.yml
    - nginx.conf
    - push-image.sh
    - .env (self include)
#### [Terraform](/infra/)
- Include
    - bootstrap/
        - main.tf
    - infra-dev/
        - env/ 
            - dev.tfvars
        - modules/
            - vpc/
        - main.tf
        - output.tf
        - variables.tf
### 1.2 Production
#### [Resource](/prod/)
- Include
    - argocd/
    - certmanager/
    - helm/
    - ingress/
    - manifest/
#### [Terraform](/infra/)
- Include
    - bootstrap/
        - main.tf
    - infra-prod/
        - env/ 
            - prod.tfvars
        - modules/
            - vpc/
        - main.tf
        - output.tf
        - variables.tf

## 2. Architecture
### 2.1 Development
#### CI/CD Pipeline
- Path: [.github/workflows/pipeline.yml](.github/workflows/pipeline.yml)
- Workflow: 

![cicd-workflow](/images/cicd-dev-workflow.png)
#### Terraform Infrastructure (and Architecture)
- Path: [infra/infra-dev/](infra/infra-dev/)
- Workflow

![terraform-dev-workflow](/images/terraform-dev.png)

### 2.2. Production
#### CI/CD Pipeline
- Path: [.github/workflows/pipeline.yml](.github/workflows/pipeline.yml)
- Workflow: 

![cicd-prod-workflow](/images/cicd-prod-workflow.png)
#### Infrastructure (with terraform)
- Path: [infra/infra-prod/](infra/infra-prod/)
- Workflow

![terraform-prod-workflow](/images/terraform-prod.png)

#### Full-stack Architecture

![full-stack](/images/full_architecture.png)

#### App Architecture

![architecture-prod](/images/coffee_shop_kubernetes_resources.png)

#### ArgoCD Architecture

![argocd](/images/argocd.png)

#### Ingress Architecture

![ingress](/images/ingress.png)

#### Metrics Server Architecture

![metric](/images/metrics.png)

#### Monitoring Architecture

![monitoring](/images/monitoring.png)
## 3. Component description
### 3.1 CI/CD Pipeline

- **`on`**  
  - **`push`**: Triggers on commits to the `main` or `develop` branches.  
  - **`workflow_dispatch`**: Allows manual runs via the Actions UI.

- **`workflow_dispatch.inputs.environment`**  
  - An optional input to override the environment tag.  
  - Defaults to `dev` if not provided.

- **`jobs.scan_and_push_images`**  
  - The single job that orchestrates all steps.  
  - Runs on `ubuntu-latest`.

- **Environment Variables**  
  - `DOCKER_USERNAME`: Set to `meraviglioso8` for Docker Hub operations.

- **Steps**  
  1. **Checkout repository** (`actions/checkout@v2`)  
     - Clones the repo to access code and commit SHA.  
  2. **Set up Docker Buildx** (`docker/setup-buildx-action@v2`)  
     - Installs Buildx for multi-arch support and advanced build features.  
  3. **Log in to Docker Hub** (`docker/login-action@v2`)  
     - Authenticates using `DOCKER_USERNAME` and `${{ secrets.DOCKER_PASSWORD }}`.  
  4. **Determine `ENV_TAG`**  
     - If manual dispatch: uses the `environment` input.  
     - On `main`: sets `ENV_TAG=prod`.  
     - Otherwise: sets `ENV_TAG=dev`.  
  5. **Install Trivy**  
     - Downloads and installs Trivy v0.22.0 via `.deb` package.  
  6. **Set GitHub Token for Trivy**  
     - Writes `${{ secrets.GH_TOKEN }}` to `~/.github_token` and exports it.  
  7. **Initialize Trivy report**  
     - Creates `trivy-scan-report.txt` with a timestamp and repo reference.  
  8. **Pull, Scan, Tag, and Push Docker Images**  
     - Iterates over a predefined list of image names.  
     - For each image:  
       - Pull from Docker Hub.  
       - Scan with Trivy (append to report).  
       - Tag as `${ENV_TAG}-${short_sha}` and push.  
       - Tag as `${ENV_TAG}-latest` and push.  
  9. **Upload Trivy Scan Report** (`actions/upload-artifact@v4`)  
     - Saves `trivy-scan-report.txt` as a downloadable artifact.

### 3.2 Development environment

- **`provider "aws"`**  
  Configures the AWS provider for Terraform, using the region specified by the variable `var.region`. All subsequent AWS resources will be created in this region.

- **`terraform { backend "s3" { ... } }`**  
  Defines the remote state backend.  
  - **`bucket`**: The S3 bucket (`huyen-tfstate-backend`) where Terraform state is stored.  
  - **`key`**: The path (`dev/terraform.tfstate`) within the bucket for this workspace.  
  - **`region`**: The AWS region (`us-west-2`) where the state bucket resides.  
  - **`encrypt`**: Ensures that the state file is stored encrypted at rest.

- **`module "custom_vpc"`**  
  A local VPC module that builds networking infrastructure:  
  - **`cidr_block`**, **`public_subnet_cidrs`**, **`private_subnet_cidrs`** define the VPC and subnet ranges.  
  - **Security group inputs** (`name`, `description`, `ingress`, `egress`) configure a dedicated SG.  
  - **`common_tags`** and **`name`** apply consistent tagging across all VPC resources.  
  - **Outputs** include `public_subnet_ids`, `private_subnet_ids`, and `security_group_id` for downstream use.

- **`module "docker_ec2"`**  
  Uses the `terraform-aws-modules/ec2-instance/aws` module (v5.x) to launch an EC2 instance for running Docker:  
  - **`ami`**, **`instance_type`**, **`key_name`** configure the instance image, size, and SSH key.  
  - **`subnet_id`** and **`vpc_security_group_ids`** place it in the VPC’s public subnet with the VPC’s SG.  
  - **`associate_public_ip_address = true`** makes the instance internet-accessible.  
  - **`user_data`** bootstraps the instance: installs Docker, Docker Compose, NGINX, PostgreSQL client, clones the coffee-shop repo, injects environment variables, logs in to Docker Hub, and brings up the application.  
  - **`tags`** apply the common tags.

- **`resource "aws_db_subnet_group" "postgres"`**  
  Defines an RDS subnet group named `${var.name}-db-subnet-group` that spans the VPC’s private subnets. RDS uses this to place instances in multiple AZs for high availability.

- **`resource "aws_db_parameter_group" "custom_postgres"`**  
  Creates a custom parameter group for PostgreSQL 17 (`family = "postgres17"`), overriding parameters (. disabling SSL enforcement with `rds.force_ssl = 0`).

- **`resource "aws_db_instance" "postgres"`**  
  Provisions the PostgreSQL RDS instance:  
  - **Identifiers** (`identifier`, `db_name`, `port`) and **size** (`instance_class`, `allocated_storage`).  
  - **Availability** (`multi_az`, `publicly_accessible`), **storage** (`storage_type`, `backup_retention_period`).  
  - **Credentials** (`username`, `password`) and **networking** (`db_subnet_group_name`, `vpc_security_group_ids`).  
  - **Lifecycle** (`skip_final_snapshot`, `deletion_protection`)  
  - **`parameter_group_name`** attaches the custom parameter group.  
  - **Tags** apply common metadata.

- **`resource "aws_secretsmanager_secret" "db_credentials"`**  
  Creates an AWS Secrets Manager secret (`${var.name}-postgresdb-rds-credentials`) to securely store the RDS master credentials.

- **`resource "aws_secretsmanager_secret_version" "db_credentials"`**  
  Populates the secret with a JSON object containing `username`, `password`, `engine`, `host`, `port`, and `dbname`. Depends on the RDS instance to ensure connection details are available.

### 3.3 Development resource

- **`networks`**  
  - `coffeeshop-net`: a user-defined bridge network that all containers attach to for service discovery and isolation.

- **`volumes`**  
  - `rabbitmq_data`: a named Docker volume mounted into the RabbitMQ container at `/var/lib/rabbitmq` to persist message queues.

- **`services`**  
  - **`rabbitmq`**  
    - Image: `meraviglioso8/rabbitmq:dev-latest`  
    - Restarts automatically on failure.  
    - Exposes AMQP (5672) and management UI (15672).  
    - Uses `rabbitmq_data` for persistent storage.  
    - Health-checks via `rabbitmqctl status`.

  - **`product`**  
    - gRPC service on port 5001 (`go-coffeeshop-product:dev-latest`).  
    - Depends on RabbitMQ being available.  
    - Exposes port 5001 for other services to call.

  - **`counter`**  
    - gRPC service on port 5002 (`go-coffeeshop-counter:dev-latest`).  
    - Depends on `product` and `rabbitmq`.  
    - Reads database and messaging URLs from environment (. `PG_URL`, `RABBITMQ_URL`).

  - **`barista`**  
    - Coffee-order processing service (`go-coffeeshop-barista:dev-latest`).  
    - Depends on RabbitMQ.  
    - Configured via environment for DB and RabbitMQ connection.

  - **`kitchen`**  
    - Order-fulfillment service (`go-coffeeshop-kitchen:dev-latest`).  
    - Depends on RabbitMQ.  
    - Uses the same environment variables for database and messaging.

  - **`proxy`**  
    - Reverse-proxy / gateway (`go-coffeeshop-proxy:dev-latest`) on port 5000.  
    - Forwards gRPC calls to `product` (port 5001) and `counter` (port 5002).  
    - Provides a single entry point for API consumers.

  - **`web`**  
    - Frontend UI (`go-coffeeshop-web:dev-latest`) on port 8888.  
    - Points at `/proxy` for its API backend.  

  - **`watchtower`**  
    - Auto-updater (`meraviglioso8/watchtower:dev-latest`).  
    - Monitors all containers on `coffeeshop-net` every 5 minutes, pulling and restarting if new images exist.  
    - Cleans up old images after updates.

- **`nginx.conf`**  

  - **Global Settings**  
    - `user nginx` / `worker_processes auto` / `error_log` / `pid` / `include modules`  
    - Controls master-process user, worker count, logs, PID file, and module loading.

  - **`events`**  
    - `worker_connections 1024`: max simultaneous connections per worker.

  - **`http`**  
    - **Logging & performance**  
      - Defines a `main` log_format and writes access_log.  
      - Enables `sendfile`, `tcp_nopush`, and `keepalive_timeout`.  
      - Loads MIME types.  

    - **`server { ... }`**  
      - Listens on port 80 for IPv4/IPv6.  
      - **`location /`**: proxies all root traffic to the web UI at `http://127.0.0.1:8888`.  
      - **`location /proxy/`**: strips the `/proxy/` prefix and forwards requests to the API gateway at `http://127.0.0.1:5000/`, including WebSocket headers.  
      - Custom `error_page` directives for 404 and 50x responses.


### 3.4 Production environment

- **`provider "aws"`**  
  Configures the AWS provider using the region from `var.region`.

- **`terraform.backend "s3"`**  
  Stores Terraform state remotely in S3:  
  - **bucket**: `huyen-tfstate-backend`  
  - **key**: `prod/terraform.tfstate`  
  - **region**: `us-west-2`  
  - **encrypt**: `true`

- **`module "custom_vpc"`**  
  Deploys a reusable VPC module with:  
  - VPC CIDR (`var.cidr_block`)  
  - Public and private subnet CIDRs  
  - A security group (name, description, ingress/egress rules)  
  - Common tags and a resource name  
  Exposes `public_subnet_ids`, `private_subnet_ids`, and `security_group_id`.

- **`aws_db_subnet_group.postgres`**  
  Defines an RDS subnet group named `${var.name}-db-subnet-group` that spans the VPC’s private subnets.

- **`aws_db_parameter_group.custom_postgres`**  
  Creates a PostgreSQL parameter group (`family = "postgres17"`) with SSL enforcement disabled (`rds.force_ssl = 0`).

- **`aws_db_instance.postgres`**  
  Provisions the production RDS instance:  
  - **Engine**: `postgres`  
  - **DB name/port**: `var.db_name`, `var.db_port`  
  - **High availability**: `multi_az`, backup retention, deletion protection  
  - **Networking**: uses the DB subnet group and VPC security group  
  - **Sizing**: `instance_class`, `allocated_storage`, `storage_type`  
  - **Credentials**: `var.db_username`, `var.db_password`  
  - **Lifecycle**: `skip_final_snapshot`, `deletion_protection`

- **`aws_secretsmanager_secret.db_credentials`**  
  Creates a Secrets Manager secret (`${var.name}-postgres-rds-credentials`) for storing the RDS master credentials.

- **`aws_secretsmanager_secret_version.db_credentials`**  
  Populates the secret with a JSON object containing:  
  `username`, `password`, `engine`, `host`, `port`, and `dbname`. Depends on the RDS instance to retrieve connection details.

- **`aws_eks_cluster.huyen_prod_eks`**  
  Provisions an EKS cluster named `${var.name}-eks`:  
  - **Role ARN**: `var.eks_cluster_role_arn`  
  - **VPC config**: attaches both public and private subnets  
  - **Endpoint access**: both private and public enabled  
  - **Tags**: applies `var.common_tags`

- **`aws_eks_node_group.managed_nodes`**  
  Creates a managed node group for the EKS cluster:  
  - **Cluster name**: references the EKS cluster  
  - **Node role ARN**: `var.eks_node_role_arn`  
  - **Subnets**: public subnet IDs  
  - **Scaling**: `desired_size`, `min_size`, `max_size` from variables  
  - **Instance types**: `var.eks_node_instance_types`  
  - **Remote access**: optional SSH key `var.ec2_ssh_key_name`  
  - **Tags**: merges `var.common_tags` with a Name tag  
  - **Dependency**: waits for the EKS cluster to be created first  

### 3.5 Production resource

#### Directory structure

- **`prod/argocd`**  
  - `argocd-cm-plugin.yml`  
    Argo CD ConfigMap enabling the KSOPS plugin for encrypted secrets.  
  - `argo-cd-repo-server-ksops-patch.yml`  
    Patch to inject KSOPS support into the Argo CD Repo Server deployment.  
  - `kustomization.yml`  
    Kustomize overlay that bundles the above Argo CD customizations.  
  - `readme.md`  
    Documentation explaining how to apply and customize the Argo CD setup.

- **`prod/certmanager`**  
  - `cluster-issuer.yml`  
    Defines a ClusterIssuer for cert-manager (. Let’s Encrypt settings).  
  - `certificate.yml`  
    Certificate resources for application domains.  
  - `kustomization.yml`  
    Kustomize overlay for cert-manager CRDs and issuance resources.

- **`prod/helm`**  
  - `readme.md`  
    Instructions for adding Helm repositories and installing core charts (Ingress-NGINX, cert-manager, metrics-server, kube-prometheus-stack).

- **`prod/ingress`**  
  - `proxy-ingress.yml`  
    Ingress resource routing `/proxy` to the backend proxy service.  
  - `web-ingress.yml`  
    Ingress resource routing `/` to the web frontend.  
  - `kustomization.yml`  
    Kustomize overlay grouping the two Ingress manifests.

- **`prod/manifest`**  
  Organizes Kubernetes manifests by component, each with its own Kustomize base:
  - **`barista/`**  
    - `barista-deploy.yml`, `barista-svc.yml`, `barista-hpa.yml`, `kustomization.yml`  
    Deployment, Service, and HPA for the Barista service.
  - **`counter/`**, **`kitchen/`**, **`product/`**, **`proxy/`**, **`web/`**  
    Same pattern: each folder contains `*-deploy.yml`, `*-svc.yml`, `*-hpa.yml`, plus `kustomization.yml`.
  - **`rabbitmq/`**  
    - `rabbitmq-deploy.yml`, `rabbitmq-svc.yml`, `rabbitmq-hpa.yml`, `rabbitmq-pv.yml`, `rabbitmq-pvc.yml`, `kustomization.yml`  
    Includes PV/PVC for persistent queue storage.
  - **`coffeeshop-config.yml`**  
    ConfigMap with shared application settings (environment variables, feature flags).
  - **`secret/`**  
    - `docker-secret.yml`, `ksops-secret.yml`, `postgres-secret.yml`, `rabbitmq-secret.yml`, `kustomization.yml`  
    Credentials for Docker registry, KSOPS decryption, RDS, and RabbitMQ.
  - **Top-level `kustomization.yml`**  
    Assembles all sub-folders into a single overlay for the production environment.

#### Helm chart installation

```bash
# Ingress-NGINX
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.metrics.enabled=true \
  --set controller.metrics.serviceMonitor.enabled=true \
  --set controller.metrics.serviceMonitor.additionalLabels.release="kube-prometheus-stack"

# cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.12.0 \
  --set installCRDs=true

# metrics-server
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update
helm install metrics-server metrics-server/metrics-server --namespace kube-system

# kube-prometheus-stack
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring
```

## 4. The homepage of the application
### 4.1 Homepage

![homepage](/images/homepage.png)

### 4.2 Counter

![counter](/images/counter.png)

### 4.3 Order list

![orderlist](/images/orderlist.png)

## 5. User guideline

## 5.1 **Development environment**
## 5.1.1 Resource

## Prerequisites
- Docker & Docker Compose installed  
- Environment variables defined in a `.env` file or shell:
  ```bash
  RABBITMQ_DEFAULT_USER=…
  RABBITMQ_DEFAULT_PASS=…
  APP_NAME=coffeeshop
  PG_URL=…
  PG_DSN_URL=…
  RABBITMQ_URL=…
  PRODUCT_CLIENT_URL=http://proxy:5000

  # If using docker hub with private repository, add more fields (For automation in terraform). 
  # Use docker login command when deploy manually 
  DOCKER_USER=
  DOCKER_PASS=
  ```
- Ports `5672`, `15672`, `5000–5002`, `8888` free on host

## Directory Structure
```text
.
├── docker-compose.yml
├── .env
├── push-image.sh
└── nginx.conf
```
## 0. About images
- You can build up docker image from the references repo or use the script in /dev to get the public repo and push to your own repository.

## 1. Deploying the Stack

1. Copy `.env.example` to `.env` and fill in your credentials.  
2. Start the services:
   ```bash
   docker-compose up -d
   ```
3. Verify containers are healthy:
   ```bash
   docker-compose ps
   docker inspect --format='{{json .State.Health.Status}}' rabbitmq
   ```

## 2. Services Description

### rabbitmq
- **Image:** `meraviglioso8/rabbitmq:dev-latest`  
- **Ports:** `5672` (AMQP), `15672` (UI)  
- **Volume:** `rabbitmq_data:/var/lib/rabbitmq`  
- **Healthcheck:** via `rabbitmqctl status`  

### product (gRPC on 5001)
- Depends on RabbitMQ  
- Exposes port `5001`  

### counter (gRPC on 5002)
- Depends on `product` & `rabbitmq`  
- Requires: `PG_URL`, `PG_DSN_URL`, `RABBITMQ_URL`, `PRODUCT_CLIENT_URL`  

### barista, kitchen
- Subscribe to `rabbitmq`  
- Use `PG_URL`, `PG_DSN_URL`, `RABBITMQ_URL`  

### proxy (HTTP on 5000)
- Gateway for gRPC services  
- Configured via `GRPC_PRODUCT_HOST`, `GRPC_COUNTER_HOST`  

### web (HTTP on 8888)
- Frontend UI  
- Reverse-proxy path `/proxy`  

### watchtower
- Monitors and auto-updates all containers every 5 minutes  

## 3. Networking & Volumes
- **Network:** `coffeeshop-net` (bridge)  
- **Volume:** `rabbitmq_data` persists RabbitMQ data  

## 4. Accessing the System
- **RabbitMQ UI:** http://localhost:15672  
- **gRPC endpoints:**  
  - Product: `localhost:5001`  
  - Counter: `localhost:5002`  
- **API Gateway:** http://localhost:5000  
- **Web UI:** http://localhost:8888  

## 5. Nginx Reverse-Proxy
Place `nginx.conf` under `nginx/` and start Nginx:
```bash
docker run -d \
  --name coffeeshop-nginx \
  -p 80:80 \
  -v $(pwd)/nginx/nginx.conf:/etc/nginx/nginx.conf:ro \
  --network coffeeshop-net \
  nginx:latest
```

**Key routes:**
- `/` → proxies to `web` on port 8888  
- `/proxy/` → strips `/proxy/` and forwards to `proxy` on port 5000  

## 6. Logs & Monitoring
View service logs:
```bash
docker-compose logs -f rabbitmq
docker-compose logs -f proxy
```
Watchtower logs show update activity.

## 7. Teardown
```bash
docker-compose down --volumes
docker rm -f coffeeshop-nginx
```

## 5.1.2. IaC (Include automate deploy docker compose in EC2 and NGINX)
## 1. Provision State Backend & SSH Keys

### 1.1 Navigate to the `s3-backend` directory

    bash
    cd infra/bootstrap

### 1.2 Inspect `main.tf`

    hcl
    provider "aws" {
      region = "us-west-2"
    }

    resource "aws_s3_bucket" "tfstate" {
      bucket = "huyen-tfstate-backend"
      tags   = { Name = "Huyen Terraform State Bucket" }
    }

    resource "aws_s3_bucket_versioning" "tfstate" {
      bucket = aws_s3_bucket.tfstate.id
      versioning_configuration { status = "Enabled" }
    }

    resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
      bucket = aws_s3_bucket.tfstate.id
      rule {
        apply_server_side_encryption_by_default {
          sse_algorithm = "AES256"
        }
      }
    }

    resource "aws_key_pair" "ssh_key_dev" {
      key_name   = "huyen_ssh_key_dev"
      public_key = file("~/.ssh/id_ed25519_dev.pub")
      tags = {
        Name        = "huyen_ssh_key_dev"
        Environment = "dev"
        Owner       = "huyen-tran"
      }
    }

    resource "aws_key_pair" "ssh_key_prod" {
      key_name   = "huyen_ssh_key_prod"
      public_key = file("~/.ssh/id_ed25519_prod.pub")
      tags = {
        Name        = "huyen_ssh_key_prod"
        Environment = "prod"
        Owner       = "huyen-tran"
      }
    }

### 1.3 Deploy

    bash
    terraform init
    terraform plan
    terraform apply

_Verify in the AWS Console:_

- S3 bucket `huyen-tfstate-backend` exists with versioning & AES256 encryption  
- EC2 key pairs `huyen_ssh_key_dev` and `huyen_ssh_key_prod` are imported  


## 2. Provision Development Environment

### 2.1 Navigate to the `dev` directory

```bash
cd ../infra-dev
```

### 2.2 Configure Variables
- For better clarity, I suggest using tfvars file. Fill the template below and using -var-file= option to include
```hcl
region = ""
 
# EC2 Instance Settings
instance_name = ""
ami           = ""
instance_type = ""
key_name      = ""
name = ""
 
cidr_block = ""
 
public_subnet_cidrs = [
]
 
private_subnet_cidrs = [
]
 
security_group_name = ""
 
security_group_description = ""
 
security_group_ingress = [
  {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
  {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
    {
    description = "Allow DB"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
]
 
security_group_egress = [
  {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
]
 
 
common_tags = {
  Environment = ""
  Owner       = ""
}
 
#Free-Tier RDS PostgreSQL settings
db_name                = 
db_password            = 
db_username            = 
db_instance_class      = 
db_allocated_storage   = 
db_skip_final_snapshot = 
db_deletion_protection = 
db_port                   = 
db_multi_az               = 
db_backup_retention_period = 
db_storage_type           = 
db_publicly_accessible    = 
```
### 2.3 Inspect `main.tf`

#### Backend configuration

```hcl
terraform {
    backend "s3" {
    bucket  = "huyen-tfstate-backend"
    key     = "dev/terraform.tfstate"
    region  = "us-west-2"
    encrypt = true
    }
}
```
#### VPC module usage

```hcl
module "custom_vpc" {
    source                     = "./modules/vpc"
    cidr_block                 = var.cidr_block
    public_subnet_cidrs        = var.public_subnet_cidrs
    private_subnet_cidrs       = var.private_subnet_cidrs
    security_group_name        = var.security_group_name
    security_group_description = var.security_group_description
    security_group_ingress     = var.security_group_ingress
    security_group_egress      = var.security_group_egress
    common_tags                = var.common_tags
    name                       = var.name
}
```

### 2.4 Deploy

```bash
terraform init
terraform plan
terraform apply
```

_Verify:_

- VPC, subnets, and security group are created  
- EC2 instance is running with Docker & NGINX installed  
- RDS PostgreSQL instance exists in private subnets  
- AWS Secrets Manager has the DB credentials entry  


## 3. Common Tasks

- **Update configuration**:  
      terraform plan  
      terraform apply  

- **Destroy environment**:  
      terraform destroy  

- **Rotate SSH keys**: update your local public key files, then re-run the s3-backend deployment steps.  

## 5.2. **Production environment**
## 5.2.1 **Resource**
### Directory Structure

```
prod
├── argocd
│   ├── agocd-cm-plugin.yml
│   ├── argo-cd-repo-server-ksops-patch.yml
│   ├── kustomization.yml
│   └── readme.md
├── certmanager
│   ├── certificate.yml
│   ├── cluster-issuer.yml
│   └── kustomization.yml
├── helm
│   └── readme.md
├── ingress
│   ├── kustomization.yml
│   ├── proxy-ingress.yml
│   └── web-ingress.yml
├── manifest
│   ├── barista
│   │   ├── barista-deploy.yml
│   │   ├── barista-hpa.yml
│   │   ├── barista-svc.yml
│   │   └── kustomization.yml
│   ├── coffeeshop-config.yml
│   ├── counter
│   │   ├── counter-deploy.yml
│   │   ├── counter-hpa.yml
│   │   ├── counter-svc.yml
│   │   └── kustomization.yml
│   ├── kitchen
│   │   ├── kitchen-deploy.yml
│   │   ├── kitchen-hpa.yml
│   │   ├── kitchen-svc.yml
│   │   └── kustomization.yml
│   ├── kustomization.yml
│   ├── product
│   │   ├── kustomization.yml
│   │   ├── product-deploy.yml
│   │   ├── product-hpa.yml
│   │   └── product-svc.yml
│   ├── proxy
│   │   ├── kustomization.yml
│   │   ├── proxy-deploy.yml
│   │   ├── proxy-hpa.yml
│   │   └── proxy-svc.yml
│   ├── rabbitmq
│   │   ├── kustomization.yml
│   │   ├── rabbitmq-deploy.yml
│   │   ├── rabbitmq-hpa.yml
│   │   ├── rabbitmq-pv.yml
│   │   ├── rabbitmq-pvc.yml
│   │   └── rabbitmq-svc.yml
│   ├── secret
│   │   ├── docker-secret.yml
│   │   ├── ksops-secret.yml
│   │   ├── kustomization.yml
│   │   ├── postgres-secret.yml
│   │   └── rabbitmq-secret.yml
│   ├── secret-and-more
│   │   ├── postgres-secret.yml
│   │   └── rabbitmq-secret.yml
│   └── web
│       ├── kustomization.yml
│       ├── web-deploy.yml
│       ├── web-hpa.yml
│       └── web-svc.yml
```

---

## Helm Setup and Installation

1. **Install ingress-nginx controller:**

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.metrics.enabled=true \
  --set controller.metrics.serviceMonitor.enabled=true \
  --set controller.metrics.serviceMonitor.additionalLabels.release="kube-prometheus-stack"
```

2. **Install cert-manager for managing certificates:**

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.12.0 \
  --set installCRDs=true
```

3. **Install Metrics Server for Kubernetes metrics:**

```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

helm install metrics-server metrics-server/metrics-server --namespace kube-system

kubectl get pods -n kube-system | grep metrics-server
```

4. **Install Prometheus stack for monitoring:**

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring
```

---

## Usage Notes

- Use the `kustomization.yml` files to deploy or update resources via `kubectl apply -k <directory>`.  
- Organize your deployment pipeline to apply manifests in dependency order, e.g., secrets first, then services, then ingress.  
- Helm charts are managed separately for critical components such as ingress-nginx, cert-manager, metrics-server, and monitoring stack.  
- Monitor Helm releases and Kubernetes resources regularly for health and updates.

## 5.2.2. **Using Argo CD to Deploy Production Resources**

## Prerequisites

- Argo CD installed and accessible (web UI and CLI)  
- Kubernetes cluster with access configured (`kubectl`)  
- Git repository containing your `prod/` manifests and kustomizations  
- Access to modify Argo CD applications  


## Step-by-Step Deployment

### 1. Connect to Argo CD CLI (optional)

Log in via CLI to interact with Argo CD:

```bash
argocd login <ARGOCD_SERVER> --username admin --password <PASSWORD>
```

### 2. Create a new Argo CD Application

Define an application that points to your Git repo and the production path.

```bash
argocd app create coffeeshop-prod \
  --repo https://github.com/your-org/your-repo.git \
  --path prod/manifest \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated \
  --auto-prune
```

- `--sync-policy automated`: Enables automatic syncing of manifests on Git changes  
- `--auto-prune`: Removes resources deleted from Git repo  

### 3. Add other production folders as separate applications (optional)

If you want to manage parts independently, create apps for `argocd/`, `certmanager/`, `ingress/`, etc.

Example:

```bash
argocd app create ingress-nginx \
  --repo https://github.com/your-org/your-repo.git \
  --path prod/ingress \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace ingress-nginx \
  --sync-policy automated
```

### 4. Sync the Application

To manually sync and deploy:

```bash
argocd app sync coffeeshop-prod
```

Or let Argo CD auto-sync based on policy.

### 5. Monitor Application Status

Check the status of your app:

```bash
argocd app get coffeeshop-prod
```

Or use the Argo CD web UI to view health, history, and logs.

### 6. Update Manifests via Git

- Make changes to manifests in your Git repo under `prod/`  
- Push commits to your main branch  
- Argo CD detects changes and automatically syncs to the cluster  

## Tips

- Use `argocd app diff <app-name>` to preview changes before syncing  
- Leverage Argo CD’s RBAC to manage team access  
- Configure health checks and resource hooks in your manifests for better deployment control  
- Use ApplicationSets for multi-cluster or multiple environment deployments  
## 5.2.3. **IaC**
### Production Environment — User Guide

## Prerequisites

- Terraform installed (v1.x recommended)  
- AWS CLI configured with credentials and proper permissions  
- SSH key pair available for EKS node access  
- Required Terraform variables configured (e.g., in `terraform.tfvars`)

---

## Key Components

- **AWS Provider:** Configured with target region.  
- **S3 Backend:** Remote state stored in `huyen-tfstate-backend` bucket under `prod/terraform.tfstate`.  
- **VPC Module:** Creates VPC with public and private subnets, security groups.  
- **RDS PostgreSQL:** Database instance with subnet group and custom parameter group disabling SSL.  
- **Secrets Manager:** Stores DB credentials securely.  
- **EKS Cluster:** Kubernetes cluster running in the defined VPC.  
- **EKS Node Group:** Managed node group with auto-scaling and optional SSH access.


## Deployment Steps

1. **Configure variables:**  
   Fill all necessary variables in your `terraform.tfvars` file. (optional)

- Template
```
region = ""
 
# EC2 Instance Settings
name = ""
 
cidr_block = ""
 
public_subnet_cidrs = [
]
 
private_subnet_cidrs = [
]
 
security_group_name = ""
 
security_group_description = ""
 
security_group_ingress = [
  {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
  {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
    {
    description = "Allow DB"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
      {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
]
 
security_group_egress = [
  {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
]
 
common_tags = {
  Environment = ""
  Owner       = ""
}
 
#Free-Tier RDS PostgreSQL settings
db_name                = 
db_password            = 
db_username            = 
db_instance_class      = 
db_allocated_storage   = 
db_skip_final_snapshot = 
db_deletion_protection = 
db_port                   = 
db_multi_az               = 
db_backup_retention_period = 
db_storage_type           = 
db_publicly_accessible    = 
 
eks_cluster_role_arn =
eks_node_role_arn    =
 
eks_node_desired_capacity =
eks_node_max_capacity     =
eks_node_min_capacity     =
 
eks_node_instance_types = ["t3.medium"]
 
ec2_ssh_key_name = "huyen_ssh_key_prod"
```
2. **Initialize Terraform:**  
   Run:
   ```bash
   terraform init
   ```

3. **Plan deployment:**  
   To preview changes:
   ```bash
   terraform plan -var-file="terraform.tfvars"
   ```

4. **Apply changes:**  
   To create/update resources:
   ```bash
   terraform apply -var-file="terraform.tfvars"
   ```

5. **Verify resources:**  
   - Check S3 bucket for state file.  
   - Confirm VPC and subnets are created in AWS Console.  
   - Confirm RDS instance is running and accessible privately.  
   - Confirm Secrets Manager contains DB credentials.  
   - Confirm EKS cluster and node group are active.



## Post-deployment

- **Access RDS Endpoint:**  
  Use the output `rds_endpoint` and `rds_port` for connecting your applications.

- **Use Secrets Manager:**  
  Retrieve DB credentials securely from Secrets Manager rather than hardcoding.

- **Manage EKS Nodes:**  
  SSH access to nodes is enabled if `ec2_ssh_key_name` is configured.


## Maintenance

- **Scaling:**  
  Adjust EKS node group size by modifying `eks_node_desired_capacity`, `max_size`, and `min_size`.

- **Updates:**  
  Update module versions or resource parameters, then rerun `terraform apply`.

- **Secret Rotation:**  
  Update DB credentials in Secrets Manager and rotate passwords securely.

- **Backup:**  
  RDS backup retention is configurable via `db_backup_retention_period`.


## Destruction

To destroy all created resources:

```bash
terraform destroy -var-file="terraform.tfvars"
```


## Notes

- Ensure that your AWS IAM user/role has sufficient permissions for all AWS resources used.  
- Avoid committing sensitive variables like passwords in source control. Use environment variables or encrypted files.  
- Monitor the health and logs of EKS nodes and RDS instance regularly for performance and security.


