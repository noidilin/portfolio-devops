module "webserver_cluster" {
  source = "../../../modules/services/webserver-cluster"

  min_size               = 2
  max_size               = 10
  cluster_name           = "prod"
  db_remote_state_bucket = "noidilin-tf-state"
  db_remote_state_key    = "labs/01-single-web-server/prod/data-stores/mysql/terraform.tfstate"
}
