# Críticas e correções propostas (DevOps)

## Entendimento rápido do objetivo
Stack de observabilidade em containers (Node Exporter, Ping Exporter, Prometheus e Grafana) orquestrado por Docker Compose e preparado para ser iniciado automaticamente em uma instância EC2 via Terraform/user_data.

## Problemas encontrados
- **Grave – user_data quebra na EC2**: instala apenas `docker-compose` (v1) mas executa `docker compose up -d` (CLI v2). Na maioria das imagens Debian/Ubuntu isso falha por falta do plugin `docker-compose-plugin`. Além disso, o script clona outro repositório (`Machado-tec/Aula-Observabilidade`) em vez deste diretório, o que pode subir um stack diferente do entregável atual. Também assume que o usuário `admin` existe na AMI escolhida (nem sempre é verdade; em Debian geralmente é `admin`, em Ubuntu é `ubuntu`).
- **Grave – Segurança**: o security group expõe SSH, Node Exporter, Ping Exporter, Prometheus e Grafana para **0.0.0.0/0** (linhas 6–44 de `resource.tf`). Isso é desnecessário e aumenta a superfície de ataque; Prometheus/Grafana deveriam ser restritos (bastion/VPN ou pelo menos CIDR corporativo). Não há autenticação/HTTPS na borda.
- **Porta Grafana inconsistente**: README orienta 3000, mas o `docker-compose.yml` publica 3300:3000 e o SG libera 3300. Essa divergência gera confusão e dashboards/links padrão assumem 3000.
- **Artefatos de estado no versionamento**: `plan.out` contém `tfstate` e `tfplan` zipados; isso expõe estado/infra e não deve ser commitado. Falta backend remoto (S3/Dynamo) para locking e não há `terraform.tfvars`/variáveis parametrizando IDs sensíveis.
- **Configuração rígida e pouco reusável**: VPC, subnet, key pair, AMI e usuário estão hardcoded em `resource.tf`. Sem variáveis ou módulos, só funciona na conta/rede da autora.
- **Credenciais padrão do Grafana**: compose define `admin/admin` em texto claro. Mesmo em ambiente de estudo, vale usar variáveis via `.env` ou secret file e exigir troca imediata.
- **Ping exporter**: o YAML usa uma lista de mapas com IP como chave; é válido, mas a forma mais comum/documentada é um mapa simples. Sugiro simplificar para reduzir risco de erro de indentação.
- **Pequenas inconsistências**: `depends_on` do ping-exporter no exporter é desnecessário; falta diretório `exporter/textfile` para o collector (será criado pelo Docker, mas vale versionar vazio com `.gitkeep`); README fala em pasta `obs/` mas a raiz já contém o compose; `.gitignore` traz itens de Dynamics AL irrelevantes e não ignora `plan.out`.

## Correções sugeridas (aplicar ou ajustar conforme política)

### 1) user_data compatível com Docker Compose v2 e repositório correto
```bash
apt-get update -y
apt-get install -y git docker.io docker-compose-plugin
# ...
cd /home/admin
REPO_DIR="observabilidade-aws-proway"
if [ ! -d "$REPO_DIR" ]; then
  git clone https://github.com/<seu-usuario>/observabilidade-aws-proway.git "$REPO_DIR"
else
  cd "$REPO_DIR" && git pull && cd ..
fi
cd "$REPO_DIR"
docker compose up -d
```
- Se a AMI usar usuário `ubuntu`, troque `/home/admin` por `/home/ubuntu` e ajuste o `chown`.

### 2) Restringir portas e alinhar Grafana
- No `docker-compose.yml`, publique Grafana em 3000 para bater com o README:
```yaml
  grafana:
    ports:
      - "3000:3000"
```
- No `resource.tf`, altere a regra da porta 3300 para 3000 e restrinja `cidr_blocks` (ex.: IP fixo/Bastion/VPN). Ideal: limitar SSH também.

### 3) Higienizar estado Terraform e adicionar backend
- Remova `plan.out` do repositório e adicione ao `.gitignore`:
```
plan.out
*.tfplan
*.zip
```
- Configure backend remoto (S3 + DynamoDB lock) e crie variáveis para `vpc_id`, `subnet_id`, `key_name`, `ami`, `instance_type`, `allowed_cidr_ssh`, `allowed_cidr_http`.

### 4) Simplificar `ping_exporter.yml`
```yaml
targets:
  192.168.1.1:
    alias: router
  8.8.8.8:
    alias: google

ping:
  interval: 5s
  timeout: 4s
  history-size: 5
  payload-size: 64
```

### 5) Credenciais do Grafana
- Use `.env` ou secrets para `GF_SECURITY_ADMIN_PASSWORD` e force troca inicial:
```yaml
  grafana:
    env_file: .env
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SECURITY_ADMIN_PASSWORD__FILE=/run/secrets/grafana_admin_password
    secrets:
      - grafana_admin_password

secrets:
  grafana_admin_password:
    file: ./secrets/grafana_admin_password
```

### 6) Outras melhorias rápidas
- Adicionar `.gitkeep` em `exporter/textfile` e `prometheus/data` para evitar criação tardia.
- Ajustar README para refletir caminhos reais (raiz do repo) e porta do Grafana.
- Remover `depends_on` desnecessário do ping-exporter e considerar `restart: unless-stopped` já aplicado.
- Adicionar Makefile/Scripts (`make up`, `make down`, `make logs`) conforme o checklist ainda não cumprido.

## Como validar localmente (sem AWS)
1. `docker compose build` para garantir que Dockerfiles estão ok.
2. `docker compose up -d` e verificar:
   - `curl http://localhost:9100/metrics` → métricas do node-exporter.
   - `curl http://localhost:9427/metrics | grep ping_rtt` → métricas de ping.
   - `curl http://localhost:9090/-/ready` → Prometheus pronto.
   - Acessar `http://localhost:3000` (ou 3300 se mantiver) → datasource Prometheus já provisionado e dashboard “Node Exporter – Visão rápida” carregando métricas.
3. `terraform fmt` + `terraform validate` (depois de ajustar backend/variáveis) para garantir sintaxe. Em ambiente real, `terraform plan/apply` com credenciais AWS válidas.

## Síntese
O objetivo do projeto está claro e a estrutura dos containers é coerente, mas a execução automática na EC2 falhará (Docker Compose v2 ausente e repositório incorreto) e a exposição ampla das portas é o maior risco. Alinhar porta do Grafana, parametrizar Terraform, higienizar estado e endereçar credenciais são os passos críticos para ter um ambiente funcional e seguro.
