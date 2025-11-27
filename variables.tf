variable "vpc_id" {
  type        = string
  description = "ID da VPC onde a instância será criada."
  default     = "vpc-06786ee7f7a163059"
}

variable "subnet_id" {
  type        = string
  description = "Subnet pública para a instância de monitoramento."
  default     = "subnet-0306135ddda99d608"
}

variable "key_name" {
  type        = string
  description = "Par de chaves para acesso SSH."
  default     = "julia-key"
}

variable "ami_id" {
  type        = string
  description = "AMI usada para a instância (ajuste conforme região)."
  default     = "ami-0b0012dad04fbe3d7" # Debian AMI
}

variable "instance_type" {
  type        = string
  description = "Tipo da instância EC2."
  default     = "t2.micro"
}

variable "allowed_cidr_ssh" {
  type        = string
  description = "CIDR permitido para SSH. Prefira restringir ao seu IP."
  default     = "0.0.0.0/0"
}

variable "allowed_cidr_observability" {
  type        = string
  description = "CIDR permitido para Prometheus/Grafana/exporters."
  default     = "0.0.0.0/0"
}

variable "instance_username" {
  type        = string
  description = "Usuário padrão da AMI (ex.: admin, ubuntu)."
  default     = "admin"
}

variable "repo_url" {
  type        = string
  description = "Repositório Git com o stack de observabilidade."
  default     = "https://github.com/Machado-tec/observabilidade-aws-proway.git"
}
