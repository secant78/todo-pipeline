# Import existing IAM roles so Terraform adopts them rather than failing with
# EntityAlreadyExists when state is empty.  Safe to leave in permanently —
# import blocks are a no-op once the resource is already in state.

import {
  to = module.iam.aws_iam_role.ecs_execution
  id = "todo-dev-ecs-execution"
}

import {
  to = module.iam.aws_iam_role.ecs_task
  id = "todo-dev-ecs-task"
}

import {
  to = module.iam.aws_iam_role.github_actions
  id = "todo-dev-github-actions"
}

import {
  to = module.iam.aws_iam_role.secret_rotator
  id = "todo-dev-secret-rotator"
}
