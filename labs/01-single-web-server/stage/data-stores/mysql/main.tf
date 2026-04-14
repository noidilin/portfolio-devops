resource "aws_db_instance" "mysql" {
  identifier_prefix   = "single-web-server"
  engine              = "mysql"
  allocated_storage   = 10
  instance_class      = "db.t3.micro"
  skip_final_snapshot = true
  db_name             = "single_web_server_db"

  username = var.db_username
  password = var.db_password
}
