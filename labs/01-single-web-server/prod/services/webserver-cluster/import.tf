import {
  id = "sgr-05cdebd0568be008b"
  to = module.webserver_cluster.aws_vpc_security_group_ingress_rule.web_instance_allow_server_port
}

import {
  id = "sgr-0e60b577f4b526ce4"
  to = module.webserver_cluster.aws_vpc_security_group_ingress_rule.web_alg_allow_http_inbound
}

import {
  id = "sgr-0b6bcfe656c61c4fa"
  to = module.webserver_cluster.aws_vpc_security_group_egress_rule.web_alb_allow_all_outbound
}
