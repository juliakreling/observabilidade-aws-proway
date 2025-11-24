resource "aws_security_group" "sg_monitoramento" {
  name        = "julia-sg-monitoramento"
  description = "Permite Prometheus, Grafana, e monitamento"
  vpc_id      = "vpc-06786ee7f7a163059"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Node Exporter
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ping Exporter
  ingress {
    from_port   = 9427
    to_port     = 9427
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Prometheus
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Grafana
  ingress {
    from_port   = 3300
    to_port     = 3300
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
  ami                         = "ami-0b0012dad04fbe3d7" # Debian AMI
  instance_type               = "t2.micro"
  key_name                    = "julia-key"
  vpc_security_group_ids      = [aws_security_group.sg_monitoramento.id]
  subnet_id                   = "subnet-0306135ddda99d608"
  associate_public_ip_address = true


  user_data = <<-EOF
    #!/bin/bash
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

    echo "[INFO] Atualizando pacotes..."
    apt-get update -y
    apt-get install -y git docker.io docker-compose

    echo "[INFO] Habilitando Docker..."
    systemctl enable docker
    systemctl start docker

    # Trabalhando na home do usuário admin
    cd /home/admin

    REPO_DIR="Aula-Observabilidade"

    # Clona repositório na home do admin
    if [ ! -d "$REPO_DIR" ]; then
        echo "[INFO] Clonando repositório..."
        git clone https://github.com/Machado-tec/Aula-Observabilidade.git
    else
        echo "[INFO] Repositório já existe. Atualizando..."
        cd $REPO_DIR
        git pull
        cd ..
    fi

    # Acessa diretório do projeto
    cd $REPO_DIR

    echo "[INFO] Subindo Docker Compose..."
    docker compose up -d

    # Corrige permissões para admin usar depois
    chown -R admin:admin /home/admin/$REPO_DIR

    echo "[INFO] Setup concluído!"
    EOF


  tags = {
    Name = "instance-julia-monitoramento"
  }
}

