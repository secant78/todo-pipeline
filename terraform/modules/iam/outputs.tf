output "execution_role_arn"      { value = aws_iam_role.ecs_execution.arn }
output "execution_role_id"       { value = aws_iam_role.ecs_execution.id }
output "task_role_arn"           { value = aws_iam_role.ecs_task.arn }
output "github_actions_role_arn" { value = aws_iam_role.github_actions.arn }
output "rotator_role_arn"        { value = aws_iam_role.secret_rotator.arn }
output "rotator_role_id"         { value = aws_iam_role.secret_rotator.id }
