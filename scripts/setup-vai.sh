# scripts/setup-vai.sh

# install the  Helm chart
helm install vai hashicorp/vault \
    --create-namespace \
    --namespace vai \
    --set="global.tlsDisable=true" \
    --set="global.externalVaultAddr=http://172.17.0.1:8200" \
    --set="injector.enabled=true" \
    --set="server.enabled=false"

# wait for the ESM pods to be ready
kubectl wait \
   --for=condition=ready pod \
   -l app.kubernetes.io/instance=vai \
   --timeout=180s \
   -n vai

# create a policy
vault policy write vai - <<EOF
path "database/creds/postgres" {
    capabilities = ["read"]
}
EOF

# create a kubernetes role
vault write auth/kubernetes/role/vai \
    bound_service_account_names=vault-auth \
    bound_service_account_namespaces=default \
    policies=vai \
    ttl=1h
