  - job_name: azure-postgres-__AZURE_POSTGRES_NAME__
    scheme: https
    metrics_path: "/metrics"
    basic_auth:
      username: __AZURE_POSTGRES_USER__
      password: __AZURE_POSTGRES_PASSWORD__
    static_configs:
      - targets: ["__AZURE_POSTGRES_HOST__:__AZURE_POSTGRES_PORT__"]
    metric_relabel_configs:
      - source_labels: [__name__]
        target_label: azure_postgres_name
        replacement: __AZURE_POSTGRES_NAME__
      - source_labels: [__name__]
        target_label: database_type
        replacement: azure_postgres
