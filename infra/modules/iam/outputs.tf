output "github_actions_role_arn"  { value = aws_iam_role.github_actions_deploy.arn }
output "github_oidc_provider_arn" { value = aws_iam_openid_connect_provider.github.arn }
output "alb_controller_role_arn"  { value = aws_iam_role.alb_controller.arn }
output "external_secrets_role_arn" { value = aws_iam_role.external_secrets.arn }
