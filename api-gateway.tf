# API Gateway
resource "aws_api_gateway_rest_api" "main" {
  name        = "${local.name}-api"
  description = "Fastfood API Gateway with Lambda authentication"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.common_tags
}

# Cognito Authorizer
resource "aws_api_gateway_authorizer" "cognito" {
  name          = "${local.name}-cognito-authorizer"
  type          = "COGNITO_USER_POOLS"
  rest_api_id   = aws_api_gateway_rest_api.main.id
  provider_arns = [aws_cognito_user_pool.main.arn]
}

# API Gateway Resource for authentication
resource "aws_api_gateway_resource" "auth" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "auth"
}

# API Gateway Resource for login
resource "aws_api_gateway_resource" "login" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.auth.id
  path_part   = "login"
}

# API Gateway Resource for protected routes
resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "api"
}

# API Gateway Resource for health check
resource "aws_api_gateway_resource" "health" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "health"
}

# API Gateway Resource for pedidos
resource "aws_api_gateway_resource" "pedidos" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "pedidos"
}

# API Gateway Resource for produtos
resource "aws_api_gateway_resource" "produtos" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "produtos"
}

# API Gateway Resource for clientes
resource "aws_api_gateway_resource" "clientes" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "clientes"
}

# API Gateway Method for login
resource "aws_api_gateway_method" "login" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.login.id
  http_method   = "POST"
  authorization = "NONE"
}

# Lambda Function for authentication
resource "aws_lambda_function" "auth" {
  filename         = "lambda-auth.zip"
  function_name    = "${local.name}-auth"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.lambda_auth.output_base64sha256
  runtime          = "python3.11"
  timeout          = 30

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      COGNITO_USER_POOL_ID = aws_cognito_user_pool.main.id
      COGNITO_CLIENT_ID    = aws_cognito_user_pool_client.main.id
      DB_HOST              = var.db_endpoint
      DB_NAME              = var.db_name
      DB_USERNAME          = var.db_username
      DB_PASSWORD          = var.db_password
      JWT_SECRET           = var.jwt_secret
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_auth,
  ]

  tags = local.common_tags
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

# API Gateway Integration
resource "aws_api_gateway_integration" "login" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.login.id
  http_method = aws_api_gateway_method.login.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.auth.invoke_arn
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "main" {
  depends_on = [
    aws_api_gateway_integration.login,
    aws_api_gateway_integration.health_integration,
    aws_api_gateway_integration.pedidos_get_integration,
    aws_api_gateway_integration.pedidos_post_integration,
    aws_api_gateway_integration.produtos_get_integration,
    aws_api_gateway_integration.produtos_post_integration,
    aws_api_gateway_integration.clientes_get_integration,
    aws_api_gateway_integration.clientes_post_integration,
    aws_api_gateway_vpc_link.main
  ]

  rest_api_id = aws_api_gateway_rest_api.main.id

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = "prod"

  tags = local.common_tags
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_auth" {
  name              = "/aws/lambda/${local.name}-auth"
  retention_in_days = 14

  tags = local.common_tags
}

# Security Group for Lambda
resource "aws_security_group" "lambda" {
  name_prefix = "${local.name}-lambda-"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-lambda-sg"
  })
}

# Security Group Rule for Lambda to access RDS
# Security Group Rule for Lambda to RDS
# Note: This rule is commented out due to permission issues
# The RDS security group should allow inbound connections from Lambda security group
# resource "aws_security_group_rule" "lambda_to_rds" {
#   type                     = "egress"
#   from_port                = 5432
#   to_port                  = 5432
#   protocol                 = "tcp"
#   source_security_group_id = var.rds_security_group_id
#   security_group_id        = aws_security_group.lambda.id
# }

# IAM Role for Lambda - Using existing LabRole
# Note: Using existing LabRole due to IAM permission restrictions
# resource "aws_iam_role" "lambda_auth" {
#   name = "${local.name}-lambda-auth-role"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "lambda.amazonaws.com"
#         }
#       }
#     ]
#   })
#   tags = local.common_tags
# }

# IAM Policy for Lambda VPC access - Using LabRole
# resource "aws_iam_role_policy_attachment" "lambda_auth_vpc" {
#   role       = aws_iam_role.lambda_auth.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
# }

# IAM Policy for Lambda RDS access - Using LabRole
# resource "aws_iam_role_policy" "lambda_auth_rds" {
#   name = "${local.name}-lambda-auth-rds-policy"
#   role = aws_iam_role.lambda_auth.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "rds:DescribeDBInstances",
#           "rds:DescribeDBClusters"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }

# IAM Policy for Lambda Cognito access - Using LabRole
# Note: Commented out due to permission restrictions
# The LabRole should already have the necessary Cognito permissions
# resource "aws_iam_role_policy" "lambda_auth_cognito" {
#   name = "${local.name}-lambda-auth-cognito-policy"
#   role = data.aws_iam_role.lab_role.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "cognito-idp:InitiateAuth",
#           "cognito-idp:AdminInitiateAuth",
#           "cognito-idp:AdminGetUser",
#           "cognito-idp:AdminCreateUser",
#           "cognito-idp:AdminUpdateUserAttributes",
#           "cognito-idp:AdminSetUserPassword",
#           "cognito-idp:AdminConfirmSignUp",
#           "cognito-idp:AdminResendConfirmationCode",
#           "cognito-idp:ListUsers",
#           "cognito-idp:AdminListGroupsForUser"
#         ]
#         Resource = aws_cognito_user_pool.main.arn
#       }
#     ]
#   })
# }

# API Gateway Methods for protected routes

# Health check method (no auth required)
resource "aws_api_gateway_method" "health_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.health.id
  http_method   = "GET"
  authorization = "NONE"
}

# Network Load Balancer for VPC Link
resource "aws_lb" "nlb" {
  name                       = "${local.name}-nlb"
  internal                   = true
  load_balancer_type         = "network"
  subnets                    = aws_subnet.private[*].id
  enable_deletion_protection = false
  tags                       = local.common_tags
}

# NLB Target Group
resource "aws_lb_target_group" "nlb" {
  name        = "${local.name}-nlb-tg"
  port        = var.app_port
  protocol    = "TCP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    port                = "traffic-port"
    protocol            = "TCP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = local.common_tags
}

# NLB Listener
resource "aws_lb_listener" "nlb" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb.arn
  }

  tags = local.common_tags
}

# VPC Link for internal NLB access
resource "aws_api_gateway_vpc_link" "main" {
  name        = "${local.name}-vpc-link"
  target_arns = [aws_lb.nlb.arn]
  tags        = local.common_tags
}

# Health check integration with NLB
resource "aws_api_gateway_integration" "health_integration" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.health.id
  http_method = aws_api_gateway_method.health_get.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "GET"
  uri                     = "http://${aws_lb.nlb.dns_name}/api/health"
  connection_type         = "VPC_LINK"
  connection_id           = aws_api_gateway_vpc_link.main.id
}

# Pedidos methods (protected with Cognito)
resource "aws_api_gateway_method" "pedidos_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.pedidos.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_method" "pedidos_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.pedidos.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

# Pedidos integrations with ALB
resource "aws_api_gateway_integration" "pedidos_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.pedidos.id
  http_method = aws_api_gateway_method.pedidos_get.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "GET"
  uri                     = "http://${aws_lb.main.dns_name}/api/pedidos"
}

resource "aws_api_gateway_integration" "pedidos_post_integration" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.pedidos.id
  http_method = aws_api_gateway_method.pedidos_post.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "POST"
  uri                     = "http://${aws_lb.main.dns_name}/api/pedidos"
}

# Produtos methods (protected with Cognito)
resource "aws_api_gateway_method" "produtos_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.produtos.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_method" "produtos_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.produtos.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

# Produtos integrations with ALB
resource "aws_api_gateway_integration" "produtos_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.produtos.id
  http_method = aws_api_gateway_method.produtos_get.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "GET"
  uri                     = "http://${aws_lb.main.dns_name}/api/produtos"
}

resource "aws_api_gateway_integration" "produtos_post_integration" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.produtos.id
  http_method = aws_api_gateway_method.produtos_post.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "POST"
  uri                     = "http://${aws_lb.main.dns_name}/api/produtos"
}

# Clientes methods (protected with Cognito)
resource "aws_api_gateway_method" "clientes_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.clientes.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_method" "clientes_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.clientes.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

# Clientes integrations with ALB
resource "aws_api_gateway_integration" "clientes_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.clientes.id
  http_method = aws_api_gateway_method.clientes_get.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "GET"
  uri                     = "http://${aws_lb.main.dns_name}/api/clientes"
}

resource "aws_api_gateway_integration" "clientes_post_integration" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.clientes.id
  http_method = aws_api_gateway_method.clientes_post.http_method

  type                    = "HTTP_PROXY"
  integration_http_method = "POST"
  uri                     = "http://${aws_lb.main.dns_name}/api/clientes"
}

# Lambda Function for Cognito Custom Challenge
resource "aws_lambda_function" "cognito_challenge" {
  function_name    = "${local.name}-cognito-challenge"
  handler          = "index.handler"
  runtime          = "python3.9"
  role             = data.aws_iam_role.lab_role.arn
  filename         = data.archive_file.lambda_cognito_challenge.output_path
  source_code_hash = data.archive_file.lambda_cognito_challenge.output_base64sha256
  timeout          = 30
  memory_size      = 128

  tags = local.common_tags
}

# Permission for Cognito to invoke the challenge Lambda
resource "aws_lambda_permission" "cognito_challenge" {
  statement_id  = "AllowExecutionFromCognito"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cognito_challenge.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
}

# Archive file for Cognito Challenge Lambda code
data "archive_file" "lambda_cognito_challenge" {
  type        = "zip"
  output_path = "lambda-cognito-challenge.zip"
  source_dir  = "../fastfood-lambda/cognito-challenge"
  excludes    = ["__pycache__", "*.pyc", ".git*", "*.DS_Store"]
}

# Archive file for Lambda code (created by build script)
data "archive_file" "lambda_auth" {
  type        = "zip"
  output_path = "lambda-auth.zip"
  source_dir  = "../fastfood-lambda/auth"
  excludes    = ["__pycache__", "*.pyc", ".git*", "*.DS_Store"]
}
