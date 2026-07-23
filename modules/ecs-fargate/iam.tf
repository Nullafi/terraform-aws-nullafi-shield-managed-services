# ------------------------------------------------------------------------------
# ECS task execution role (pull images, write logs) and task role (app permissions)
# ------------------------------------------------------------------------------

# Execution role – used by ECS to pull images and write logs
resource "aws_iam_role" "execution" {
  name = "${var.name_prefix}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-execution"
  })
}

resource "aws_iam_role_policy_attachment" "execution_ecr" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "execution_custom" {
  for_each = var.execution_role_policy_arns

  role       = aws_iam_role.execution.name
  policy_arn = each.value
}

# ECS Exec – required for aws ecs execute-command (exec into running tasks)
resource "aws_iam_role_policy" "execution_ecs_exec" {
  name = "ecs-exec"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*" # ssmmessages APIs do not support resource-level permissions
      }
    ]
  })
}

# Task role – used by the running task (application permissions)
resource "aws_iam_role" "task" {
  name = "${var.name_prefix}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-task"
  })
}

# Optional: attach custom task role policy ARNs (e.g. S3, Secrets Manager)
resource "aws_iam_role_policy_attachment" "task_custom" {
  for_each = var.task_role_policy_arns

  role       = aws_iam_role.task.name
  policy_arn = each.value
}
