variable "name_prefix" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_cidrs" { type = list(string) }
variable "private_subnet_cidrs" { type = list(string) }
variable "api_container_port" { type = number }

