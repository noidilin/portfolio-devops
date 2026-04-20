module "webserver_cluster" {
  source = "../../../modules/services/webserver-cluster"

  min_size               = 2
  max_size               = 4
  cluster_name           = "stage"
  db_remote_state_bucket = "noidilin-tf-state"
  db_remote_state_key    = "labs/01-single-web-server/stage/data-stores/mysql/terraform.tfstate"
}
