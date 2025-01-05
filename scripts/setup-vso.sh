# install the VSO Helm chart
helm repo add hashicorp https://helm.releases.hashicorp.com

# fetch charts
helm repo update

# install the VSO Helm chart
helm install \
    --version 0.9.1 \
    --create-namespace \
    --namespace vso \
    vso hashicorp/vault-secrets-operator

# create a policy
vault policy write vso - <<EOF
path "database/creds/postgres" {
    capabilities = ["read"]
}
EOF

# create a kubernetes role
vault write auth/kubernetes/role/vso \
    bound_service_account_names=vault-auth \
    bound_service_account_namespaces=default \
    policies=vso \
    ttl=1h
