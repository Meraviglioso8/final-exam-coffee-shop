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

## 4. The homepage of the application

## 5. User guideline
