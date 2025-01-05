# scripts/setup-vault-approle-auth.sh

# enable approle auth
vault auth enable approle

# create a policy for the database credentials
vault policy write approle - <<EOF
path "secret/data/database/postgres" {
    capabilities = ["read"]
}
EOF

# create a role using the postgres policy
vault write auth/approle/role/postgres \
    token_ttl=1h \
    token_policies=approle

# get the role-id
ROLE_ID=$(vault read -format=json auth/approle/role/postgres/role-id | jq -r ".data.role_id")

# get the secret-id
SECRET_ID=$(VAULT_FORMAT=json vault write -f auth/approle/role/postgres/secret-id | jq -r ".data.secret_id")

# create a secret for the approle
kubectl create secret generic vault-approle \
  	--from-literal=role-id="${ROLE_ID}" \
  	--from-literal=secret-id="${SECRET_ID}"
