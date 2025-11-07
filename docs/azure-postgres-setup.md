# Azure PostgreSQL Monitoring Setup

Este documento explica como configurar o monitoramento do Azure PostgreSQL no Grafana.

## Variáveis de Ambiente Necessárias

Adicione as seguintes variáveis ao seu arquivo `.env` ou `docker-compose.yml`:

```bash
# Azure PostgreSQL Configuration
AZURE_POSTGRES_ENABLED=true
AZURE_POSTGRES_NAME=my-azure-postgres
AZURE_POSTGRES_HOST=your-azure-postgres-server.postgres.database.azure.com
AZURE_POSTGRES_PORT=5432
AZURE_POSTGRES_USER=your_username
AZURE_POSTGRES_PASSWORD=your_password
```

## Configuração do Azure PostgreSQL

### 1. Habilitar Métricas no Azure

Para que o Prometheus possa coletar métricas do PostgreSQL, você precisa:

1. **Instalar o postgres_exporter** no servidor onde está rodando o PostgreSQL
2. **Configurar o postgres_exporter** para expor métricas na porta 9187
3. **Permitir acesso** do Prometheus ao postgres_exporter

### 2. Instalação do postgres_exporter

```bash
# Download do postgres_exporter
wget https://github.com/prometheus-community/postgres_exporter/releases/download/v0.15.0/postgres_exporter-0.15.0.linux-amd64.tar.gz

# Extrair e instalar
tar xvfz postgres_exporter-0.15.0.linux-amd64.tar.gz
sudo cp postgres_exporter-0.15.0.linux-amd64/postgres_exporter /usr/local/bin/

# Criar usuário para o exporter
sudo useradd --no-create-home --shell /bin/false postgres_exporter

# Configurar permissões
sudo chown postgres_exporter:postgres_exporter /usr/local/bin/postgres_exporter
```

### 3. Configuração do postgres_exporter

Crie o arquivo `/etc/postgres_exporter/postgres_exporter.conf`:

```bash
# Configuração do postgres_exporter
export DATA_SOURCE_NAME="postgresql://username:password@localhost:5432/database_name?sslmode=disable"
```

### 4. Criar serviço systemd

Crie o arquivo `/etc/systemd/system/postgres_exporter.service`:

```ini
[Unit]
Description=PostgreSQL Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=postgres_exporter
Group=postgres_exporter
Type=simple
EnvironmentFile=/etc/postgres_exporter/postgres_exporter.conf
ExecStart=/usr/local/bin/postgres_exporter
Restart=always

[Install]
WantedBy=multi-user.target
```

### 5. Iniciar o serviço

```bash
sudo systemctl daemon-reload
sudo systemctl enable postgres_exporter
sudo systemctl start postgres_exporter
sudo systemctl status postgres_exporter
```

### 6. Verificar se está funcionando

```bash
curl http://localhost:9187/metrics
```

## Configuração do Firewall

Se o PostgreSQL estiver em um servidor separado, configure o firewall para permitir acesso na porta 9187:

```bash
# UFW (Ubuntu)
sudo ufw allow 9187

# Firewalld (CentOS/RHEL)
sudo firewall-cmd --permanent --add-port=9187/tcp
sudo firewall-cmd --reload
```

## Configuração do Azure Database

Se você estiver usando Azure Database for PostgreSQL, você precisará:

1. **Configurar um servidor proxy** que tenha acesso ao Azure Database
2. **Instalar o postgres_exporter** no servidor proxy
3. **Configurar a conexão** para o Azure Database

### Exemplo de configuração para Azure Database

```bash
# No servidor proxy
export DATA_SOURCE_NAME="postgresql://username@server:password@your-azure-server.postgres.database.azure.com:5432/postgres?sslmode=require"
```

## Dashboard

Após configurar tudo, você poderá acessar o dashboard do Azure PostgreSQL em:

```
http://localhost:3000/d/azure-postgres/azure-postgresql-monitoring
```

O dashboard inclui métricas como:

- Database Efficiency
- Active Connections
- Write/Read Operations per second
- Deadlocks per second
- Cache Hit Ratio
- Database Size
- Average Transaction Time

## Troubleshooting

### Verificar se o postgres_exporter está rodando

```bash
sudo systemctl status postgres_exporter
```

### Verificar logs

```bash
sudo journalctl -u postgres_exporter -f
```

### Testar conexão com o PostgreSQL

```bash
psql -h your-azure-server.postgres.database.azure.com -U username -d postgres
```

### Verificar métricas

```bash
curl http://localhost:9187/metrics | grep pg_
```
