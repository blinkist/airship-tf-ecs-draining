terraform {
  required_version = ">= 0.12"
}

data "aws_iam_policy_document" "lambda_ecs_drain_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# IAM Role for the lambda function
resource "aws_iam_role" "lambda_ecs_drain_role" {
  count              = var.create ? 1 : 0
  name               = "${var.name}-lambda-ecs-drain-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_ecs_drain_role.json
}

# IAM Role AmazonEC2ContainerServiceRole policy attachment
resource "aws_iam_role_policy_attachment" "amazon_ec2container_service_role" {
  count      = var.create ? 1 : 0
  role       = aws_iam_role.lambda_ecs_drain_role[0].id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

data "aws_iam_policy_document" "lambda_drain_policy" {
  statement {
    actions = [
      "autoscaling:CompleteLifecycleAction",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceAttribute",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeHosts",
      "ecs:ListContainerInstances",
      "ecs:SubmitContainerStateChange",
      "ecs:SubmitTaskStateChange",
      "ecs:DescribeContainerInstances",
      "ecs:UpdateContainerInstancesState",
      "ecs:ListTasks",
      "ecs:DescribeTasks",
      "sns:Publish",
      "sns:ListSubscriptions"
    ]

    resources = ["*"]
  }
}

# IAM Role policy for the handling of the lifecycle
resource "aws_iam_role_policy" "lambda_drain_policy" {
  count  = var.create ? 1 : 0
  name   = "${var.name}-lambda-drain-policy"
  role   = aws_iam_role.lambda_ecs_drain_role[0].name
  policy = data.aws_iam_policy_document.lambda_drain_policy.json

}

# Publishing the lambda function
resource "aws_lambda_function" "drain_lambda_function" {
  count            = var.create ? 1 : 0
  filename         = "${path.module}/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")
  function_name    = "${var.name}-lambda-ecs-drain"
  role             = aws_iam_role.lambda_ecs_drain_role[0].arn
  description      = "${var.name}-lambda-ecs-drain"
  handler          = "index.lambda_handler"
  runtime          = "python2.7"
  timeout          = 300

  lifecycle {
    ignore_changes = [filename, last_modified]
  }
}

