# scripts/setup-esm.sh

# add the ESM helm chart repo
helm repo add external-secrets https://charts.external-secrets.io

# fetch the charts
helm repo update

# install the ESM helm chart
helm install external-secrets \
   external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace \
    --set installCRDs=true

# wait for the ESM pods to be ready
kubectl wait \
   --for=condition=ready pod \
   -l app.kubernetes.io/instance=external-secrets \
   --timeout=180s \
   -n external-secrets
