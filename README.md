# Fastfood Infrastructure

Este diretório contém a infraestrutura Terraform para o projeto Fastfood, configurada para rodar na AWS usando ECS Fargate.

## Arquitetura

A infraestrutura inclui:

- **VPC** com subnets públicas e privadas
- **ECS Cluster** com Fargate para executar containers
- **Application Load Balancer** para distribuir tráfego
- **ECR Repository** para armazenar imagens Docker
- **CloudWatch Logs** para logs da aplicação
- **Security Groups** configurados para segurança

> **Nota**: O banco de dados PostgreSQL será gerenciado em outro projeto na AWS. As variáveis de ambiente para conexão com o banco podem ser configuradas quando necessário.

## Pré-requisitos

1. AWS CLI configurado com credenciais válidas
2. Terraform >= 1.0 instalado
3. Docker instalado (para build das imagens)
4. **Role IAM "LabRole" existente** com as seguintes permissões:
   - `AmazonECSTaskExecutionRolePolicy`
   - Permissões para ECR (`ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, etc.)

## Como usar

### 1. Inicializar Terraform

```bash
cd fastfood-infra
terraform init
```

### 2. Planejar a infraestrutura

```bash
terraform plan
```

### 3. Aplicar a infraestrutura

```bash
terraform apply
```

### 4. Fazer build e push da imagem Docker

```bash
# Obter URL do ECR
ECR_URL=$(terraform output -raw ecr_repository_url)

# Fazer login no ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_URL

# Build da imagem
docker build -t fastfood-app ../fastfood

# Tag da imagem
docker tag fastfood-app:latest $ECR_URL:latest

# Push da imagem
docker push $ECR_URL:latest
```

### 5. Acessar a aplicação

Após o deploy, a aplicação estará disponível no DNS do Load Balancer:

```bash
ALB_DNS=$(terraform output -raw alb_dns_name)
echo "Aplicação disponível em: http://$ALB_DNS"
```

## Variáveis

As principais variáveis podem ser configuradas no arquivo `terraform.tfvars`:

- `aws_region`: Região da AWS (padrão: us-east-1)
- `project_name`: Nome do projeto (padrão: fastfood)
- `environment`: Ambiente (padrão: dev)
- `app_count`: Número de instâncias da aplicação (padrão: 2)
- `fargate_cpu`: CPU para cada task (padrão: 256)
- `fargate_memory`: Memória para cada task (padrão: 512)

## Configuração do Banco de Dados

Quando o banco de dados estiver disponível em outro projeto:

1. Copie o arquivo `database-config.tf.example` para `database-config.tf`
2. Configure as variáveis do banco de dados no arquivo `terraform.tfvars`
3. Descomente e ajuste as configurações no arquivo `database-config.tf`
4. Execute `terraform apply` para aplicar as mudanças

## Destruir a infraestrutura

```bash
terraform destroy
```

## Estrutura de arquivos

- `main.tf`: Configurações principais e providers
- `variables.tf`: Definição de variáveis
- `vpc.tf`: Configuração da VPC, subnets e security groups
- `ecs.tf`: Configuração do ECS cluster, task definition e service
- `alb.tf`: Configuração do Application Load Balancer
- `ecr.tf`: Configuração do ECR repository
- `iam.tf`: Configuração de roles e políticas IAM
- `outputs.tf`: Outputs da infraestrutura
- `terraform.tfvars`: Valores das variáveis
- `database-config.tf.example`: Exemplo de configuração do banco de dados
- `ENVIRONMENT_VARIABLES.md`: Documentação das variáveis de ambiente
- `LABROLE_PERMISSIONS.md`: Documentação das permissões necessárias para LabRole# Teste
