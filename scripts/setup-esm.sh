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
