variable "project" { default = "sample" }
variable "region" { default = "asia-northeast1" }
variable "zone"   { default = "asia-northeast1-a" }
variable "authorized_networks_cidr" { default = "0.0.0.0/0" }
variable "authorized_networks_name" { default = "public" }
variable "cloudbuild_repo_name" { default = "countly-server" }
