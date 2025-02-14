resource "aws_lb" "back" {
  name               = "backend"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]
}

# Target Group
resource "aws_lb_target_group" "back-tg" {
  name        = "back-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.ecs_vpc.id
  target_type = "ip"
}

# Listener for ALB
resource "aws_lb_listener" "back_listener" {
  load_balancer_arn = aws_lb.back.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.back-tg.arn
  }
}


# ECS Task Definition
resource "aws_ecs_task_definition" "back-task" {
  family                   = "backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = "512"
  cpu                      = "256"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = "545009827818.dkr.ecr.us-east-1.amazonaws.com/backend:latest"
      cpu       = 256
      memory    = 512
      essential = true

      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "DB_HOST", value = "books.c9uocwc00hqh.us-east-1.rds.amazonaws.com" },
        { name = "PORT", value = "3306" },
        { name = "DB_USERNAME", value = "admin" },
        { name = "DB_PASSWORD", value = "veeranarni" }
      ]
    }
  ])
}


# ECS Service
resource "aws_ecs_service" "back-ecs_service" {
  name            = "backend-ecs-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.back-task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public_subnet1.id, aws_subnet.public_subnet2.id]
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.back-tg.arn
    container_name   = "backend"
    container_port   = 80
  }
}