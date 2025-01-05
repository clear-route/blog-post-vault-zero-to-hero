# enable kubernetes auth method
vault auth enable kubernetes

# Get the service account token and CA cert
K8S_JWT_TOKEN=$(kubectl get secret vault-auth-token -o jsonpath="{.data.token}" | base64 -d)
K8S_CA_CERT=$(kubectl get secret vault-auth-token -o jsonpath="{['data']['ca\.crt']}" | base64 -d)

# configure the kubernetes auth method
vault write auth/kubernetes/config \
    token_reviewer_jwt="$K8S_JWT_TOKEN" \
    kubernetes_host=https://host.docker.internal:6443 \
    kubernetes_ca_cert="$K8S_CA_CERT"

# create a kubernetes role
vault write auth/kubernetes/role/esm \
    bound_service_account_names=vault-auth \
    bound_service_account_namespaces=default \
    policies=postgres \
    ttl=1h
