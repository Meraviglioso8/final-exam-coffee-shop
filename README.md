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
#### CICDCD Pipeline
- Path: [.github/workflows/pipeline.yml](.github/workflows/pipeline.yml)
- Workflow: 

![cicd-workflow](/images/cicd-dev-workflow.png)


## 3. Component description

## 4. The homepage of the application

## 5. User guideline
