include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/labs/01-single-web-server/modules/services/webserver-cluster"
}

inputs = {
  cluster_name           = "webservers_prod"
  db_remote_state_bucket = "noidilin-tf-state"
  db_remote_state_key    = "labs/01-single-web-server/prod/data-stores/mysql/terraform.tfstate"

  min_size = 2
  max_size = 10
}
