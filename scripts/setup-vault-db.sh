# scripts/setup-vault-db.sh

# enable database secrets engine
vault secrets enable database

# create a database
vault write database/config/demo-app-db \
    plugin_name="postgresql-database-plugin" \
    allowed_roles="postgres" \
    connection_url="postgresql://{{username}}:{{password}}@host.docker.internal:5432/vault" \
    username="postgres" \
    password="P@ssw0rd"

# create a role
vault write database/roles/postgres \
    db_name="demo-app-db" \
    creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
        GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
    default_ttl="1h" \
    max_ttl="24h"
