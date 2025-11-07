#!/bin/bash

set -e

cp /etc/prometheus/prometheus.yml.tpl /etc/prometheus/prometheus.yml

if [ -z "$SUPABASE_ACCESS_TOKEN" ]; then
  echo "Setting up single-project monitoring."

  if [ -z "$SUPABASE_PROJECT_REF" ]; then
    echo "\$SUPABASE_PROJECT_REF is not set. Exiting."
    exit 1
  fi

  if [ -z "$SUPABASE_SERVICE_ROLE_KEY" ]; then
    echo "\$SUPABASE_SERVICE_ROLE_KEY is not set. Exiting."
    exit 1
  fi

  cat /etc/prometheus/prometheus.target.yml.tpl >> /etc/prometheus/prometheus.yml

  sed -i "s/__SUPABASE_PROJECT_REF__/$SUPABASE_PROJECT_REF/g" /etc/prometheus/prometheus.yml
  sed -i "s/__SUPABASE_SERVICE_ROLE_KEY__/$SUPABASE_SERVICE_ROLE_KEY/g" /etc/prometheus/prometheus.yml
else 
  echo "Setting up multi-project monitoring."

  FILTER='.[] | .id'
  if [ -n "$SUPABASE_ORGANIZATION_ID" ]; then
    FILTER=".[] | select(.organization_id == \"$SUPABASE_ORGANIZATION_ID\") | .id"
  fi

  PROJECT_REFS=$(curl -sX 'GET' 'https://api.supabase.com/v1/projects' \
    -H 'accept: application/json' \
    -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" | jq -r "$FILTER")

  for PROJECT_REF in $PROJECT_REFS; do
    echo "Setting up project $PROJECT_REF"

    API_KEYS_RESPONSE=$(curl -sX 'GET' "https://api.supabase.com/v1/projects/$PROJECT_REF/api-keys" \
      -H 'accept: application/json' \
      -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN")

    if [[ $API_KEYS_RESPONSE == *"Failed to fetch project service details"* ]]; then
      echo "Error: Could not retrieve API keys for project $PROJECT_REF. Project might be paused. Skipping."
      continue
    fi

    SERVICE_ROLE_KEY=$(echo "$API_KEYS_RESPONSE" | jq -r '.[] | select(.name == "service_role") | .api_key')

    cat /etc/prometheus/prometheus.target.yml.tpl >> /etc/prometheus/prometheus.yml

    sed -i "s/__SUPABASE_PROJECT_REF__/$PROJECT_REF/g" /etc/prometheus/prometheus.yml
    sed -i "s/__SUPABASE_SERVICE_ROLE_KEY__/$SERVICE_ROLE_KEY/g" /etc/prometheus/prometheus.yml
  done
fi

# Configure Azure PostgreSQL if enabled
if [ "$AZURE_POSTGRES_ENABLED" = "true" ]; then
  echo "Setting up Azure PostgreSQL monitoring."
  
  if [ -z "$AZURE_POSTGRES_NAME" ]; then
    echo "\$AZURE_POSTGRES_NAME is not set. Skipping Azure PostgreSQL monitoring."
  elif [ -z "$AZURE_POSTGRES_HOST" ]; then
    echo "\$AZURE_POSTGRES_HOST is not set. Skipping Azure PostgreSQL monitoring."
  elif [ -z "$AZURE_POSTGRES_USER" ]; then
    echo "\$AZURE_POSTGRES_USER is not set. Skipping Azure PostgreSQL monitoring."
  elif [ -z "$AZURE_POSTGRES_PASSWORD" ]; then
    echo "\$AZURE_POSTGRES_PASSWORD is not set. Skipping Azure PostgreSQL monitoring."
  else
    cat /etc/prometheus/azure-postgres.target.yml.tpl >> /etc/prometheus/prometheus.yml
    
    sed -i "s/__AZURE_POSTGRES_NAME__/$AZURE_POSTGRES_NAME/g" /etc/prometheus/prometheus.yml
    sed -i "s/__AZURE_POSTGRES_HOST__/$AZURE_POSTGRES_HOST/g" /etc/prometheus/prometheus.yml
    sed -i "s/__AZURE_POSTGRES_PORT__/$AZURE_POSTGRES_PORT/g" /etc/prometheus/prometheus.yml
    sed -i "s/__AZURE_POSTGRES_USER__/$AZURE_POSTGRES_USER/g" /etc/prometheus/prometheus.yml
    sed -i "s/__AZURE_POSTGRES_PASSWORD__/$AZURE_POSTGRES_PASSWORD/g" /etc/prometheus/prometheus.yml
  fi
fi

mkdir -p /data/grafana/data 
mkdir -p /data/grafana/plugins 
mkdir -p /data/prometheus

if [ "$PASSWORD_PROTECTED" = "true" ]; then
  export GF_AUTH_ANONYMOUS_ENABLED="false"

  export GF_AUTH_BASIC_ENABLED="true"
  export GF_AUTH_DISABLE_LOGIN_FORM=""
  export GF_AUTH_DISABLE_SIGNOUT_MENU=""

  export GF_SECURITY_ADMIN_PASSWORD="$GRAFANA_PASSWORD"

  cd /usr/share/grafana && grafana cli admin reset-admin-password "$GRAFANA_PASSWORD"
fi

/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
