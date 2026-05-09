terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

resource "aws_lambda_function" "forecasting" {
  filename         = var.jar_path
  source_code_hash = filebase64sha256(var.jar_path)
  function_name    = "flexibilityforecasting"
  role             = data.aws_iam_role.lab_role.arn
  handler          = "org.acme.ForecastHandler::handleRequest"
  runtime          = "java17"
  timeout          = 300
  memory_size      = 512

  environment {
    variables = {
      FLEXIBILITYEVENT_URL = var.flexibilityevent_url
      OLLAMA_URL           = var.ollama_url
    }
  }
}

resource "aws_lambda_function_url" "forecasting_url" {
  function_name      = aws_lambda_function.forecasting.function_name
  authorization_type = "NONE"
}

resource "aws_lambda_permission" "allow_public_url" {
  statement_id           = "AllowPublicFunctionURL"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.forecasting.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

variable "jar_path" {
  description = "Path to the fat JAR produced by mvn package"
  type        = string
  default     = "../../microservices/FlexibilityForecasting/target/flexibilityforecasting-1.0.0-SNAPSHOT.jar"
}

variable "flexibilityevent_url" {
  description = "Base URL of the FlexibilityEvent service"
  type        = string
}

variable "ollama_url" {
  description = "Base URL of the Ollama instance"
  type        = string
}

output "function_url" {
  value       = aws_lambda_function_url.forecasting_url.function_url
  description = "Invoke URL for FlexibilityForecasting"
}
