output "db_endpoint"          { value = aws_db_instance.this.endpoint }
output "db_name"              { value = aws_db_instance.this.db_name }
output "db_username"          { value = aws_db_instance.this.username }
output "db_port"              { value = 5432 }
output "db_password_secret_arn" { value = aws_db_instance.this.master_user_secret[0].secret_arn }
