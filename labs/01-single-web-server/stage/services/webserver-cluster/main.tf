module "webserver_cluster" {
  source = "../../../modules/services/webserver-cluster"

  min_size               = 2
  max_size               = 4
  cluster_name           = "stage"
  db_remote_state_bucket = "noidilin-tf-state"
  db_remote_state_key    = "labs/01-single-web-server/stage/data-stores/mysql/terraform.tfstate"
}

resource "aws_vpc_security_group_ingress_rule" "web_alg_allow_testing_inbound" {
  security_group_id = module.webserver_cluster.alb_security_group_id

  from_port   = 12345
  to_port     = 12345
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}
