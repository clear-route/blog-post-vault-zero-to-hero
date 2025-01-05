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
vault read auth/approle/role/postgres/role-id

# get the secret-id
vault write -f auth/approle/role/postgres/secret-id
