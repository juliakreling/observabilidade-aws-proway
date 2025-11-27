resource "aws_security_group" "sg_monitoramento" {
  name        = "julia-sg-monitoramento"
  description = "Permite Prometheus, Grafana, e monitamento"
  vpc_id      = var.vpc_id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr_ssh]
  }

  # Node Exporter
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr_observability]
  }

  # Ping Exporter
  ingress {
    from_port   = 9427
    to_port     = 9427
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr_observability]
  }

  # Prometheus
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr_observability]
  }

  # Grafana
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr_observability]
  }

  # Outbound liberado
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_instance" "ec2-monitoramento-julia" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.sg_monitoramento.id]
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true


  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

    USER_NAME="${var.instance_username}"
    USER_HOME="/home/${var.instance_username}"
    REPO_URL="${var.repo_url}"
    REPO_DIR="$(basename -s .git "$REPO_URL")"

    if [ ! -d "$USER_HOME" ]; then
      USER_HOME="/root"
      USER_NAME="root"
    fi

    echo "[INFO] Atualizando pacotes..."
    apt-get update -y
    apt-get install -y git docker.io docker-compose-plugin

    echo "[INFO] Habilitando Docker..."
    systemctl enable docker
    systemctl start docker

    cd "$USER_HOME"

    # Clona repositório na home do admin
    if [ ! -d "$REPO_DIR" ]; then
        echo "[INFO] Clonando repositório..."
        git clone "$REPO_URL" "$REPO_DIR"
    else
        echo "[INFO] Repositório já existe. Atualizando..."
        cd "$REPO_DIR"
        git pull
        cd "$USER_HOME"
    fi

    # Acessa diretório do projeto
    cd "$REPO_DIR"

    echo "[INFO] Subindo Docker Compose..."
    docker compose up -d

    # Corrige permissões para admin usar depois
    chown -R "$USER_NAME":"$USER_NAME" "$USER_HOME/$REPO_DIR"

    echo "[INFO] Setup concluído!"
    EOF


  tags = {
    Name = "instance-julia-monitoramento"
  }
}
