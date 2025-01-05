# Intro
This is a fictional story of an app team that recently got ripped apart after a security audit for hardcoding database credentials.
Here is how they adopted HashiCorp Vault and went from hardcoding sensitive data in code to a fully dynamic scalable secrets management solution.

# How to use this repository
## Prerequisites
- docker
- kubectl
- kind/minikube
- helm
- curl
- jq

# The Application
The application is for the sake of simplicity fairly simple in [~100LOC](./demo-app/main.go]: A Web-App that takes a couple of env vars and connects to a postgres database and displays the credentials and the status of the database connection via a webserver on port `:9090`.
The app is containerized, meaning throughout this post, the app will be deployed in a Kubernetes cluster.

Once the `demo-app` is deployed and working `Postgres` credentials provided using environment variables a webserver on port `9090` will display a short status page:

```bash
> curl http://localhost:9090
<html>
<head>
<title>Demo-App</title>
</head>
<body>
DB: 172.17.0.1:5432<br>User: postgres<br>Password: P@ssw0rd<br>Ping: true<br></body>
</html>
```

# The Setup
## Repository
```bash
git clone https://clear-route/blog-post-vault-zero-to-hero.git && cd blog-post-vault-zero-to-hero.git
```


## Vault
<!--- {{ file "scripts/setup-vault.sh" | code "bash" }} --->
```bash
# Start Vault Container
docker run --rm \
    --cap-add=IPC_LOCK \
	--name vault \
	-p 8200:8200 \
	-e VAULT_DEV_ROOT_TOKEN_ID=root \
	-e VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 \
	hashicorp/vault

# Source connection env vars
. envrc && vault status

```

## Kubernetes (`kind`)
<!--- {{ file "scripts/setup-kind.sh" | code "bash" }} --->
```bash
kind create cluster \
	--name vault-from-zero-to-hero \
	--config scripts/kind-config.yml

```

## postgres
<!--- {{ file "scripts/setup-postgres.sh" | code "bash" }} --->
```bash
docker run --rm --name postgres \
    -p 5432:5432 \
	-e POSTGRES_USER=postgres \
	-e POSTGRES_PASSWORD=P@ssw0rd \
	-e POSTGRES_DB=vault \
	postgres

```


# The journey from zero to hero
## Act 01: Status Quo - Hardcoded static Credentials
The status quo couldn`t be worse and Im not even kidding. Never to this - not even in development.
The team provided the database credentials to their App by creating a Kubernetes Secret that contains the database credentials from a referenced secret via environment variables:

<!--- {{ file "manifests/demo-app-hardcoded.yaml" | code "yaml" }} --->
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  labels:
    app: demo-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
        - name: vault-from-zero-to-hero
          image: falcosuessgott/vault-from-zero-to-hero
          ports:
            - containerPort: 9090
          env:
            # This is bad - do not do this!
            - name: DB_HOST
              value: "172.17.0.1" # fix this using host.docker.internal
            - name: DB_PORT
              value: "5432"
            - name: DB_USER
              value: postgres
            - name: DB_PASSWORD
              value: P@ssw0rd
            - name: DB_NAME
              value: vault

```

To no ones surprise, during an Audit, the security team found the hardcoded credentials in a Git Repository and flagged the application.
This is where our story begins, of adopting Vault to optimize secrets management for containerized applications.

### Summary
- no secrets mgmt solution at all
- static hardcoded credentials exposed in code

## Act 02: Static Credentials from HashiCorp Vault - a little better
After the audit, the team was no longer allowed to hardcode the database credentials in `Kubernetes` manifests.
They want to adopt a central secrets management solution. Luckily the Infrastructure Team already maintains a `HashiCorp Vault` cluster for internal use.

The team did some research about Vault and learned, that they can store the database credentials in Vaults `KVv2` secrets engine.
After getting access a team member put the credentials in the already existing  a `Kvv2` engine `secrets`:

![img](./img/02-vault-secrets.png)

Now all they had to do, was to specify the Vault Secret in the Kubernetes manifest, rigth?

### External Secrets Manager Setup
They did some more researching and learned about the [`External Secrets Manager`](https://external-secrets.io/latest/) - a `Kubernetes` operator that populates `Kubernetes` Secrets from various Provider, such as HashiCorp Vault.

The installation was fairly easy. They simply had to use the helm chart to install the operator:
<!--- {{ file "scripts/setup-esm.sh" | code "bash" }} --->
```bash
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

```

Furthermore, the [docs](https://external-secrets.io/latest/provider/hashicorp-vault/) stated to create a CRD of type `SecretStore` CRD that specifies the connection to the Vault and the path to the `KVv2` engine:
<!--- {{ file "manifests/esm-secret-store.yml" | code "yaml" }} --->
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: http://172.17.0.1:8200
      path: secret
      version: v2
      auth:
        tokenSecretRef:
          name: vault-token
          key: token
---
apiVersion: v1
kind: Secret
metadata:
  name: vault-token
data:
  token: cm9vdA== # "root"

```

Lastly, an `ExternalSecret` CRD was created that references the `SecretStore` and specifies the path to the secret in the Vault:
<!--- {{ file "manifests/esm-external-secret.yml" | code "yaml" }} --->
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: postgres-creds
spec:
  refreshInterval: "1h"
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: postgres-creds
  data:
    - secretKey: DB_HOST
      remoteRef:
        key: database/postgres
        property: DB_HOST
    - secretKey: DB_PORT
      remoteRef:
        key: database/postgres
        property: DB_PORT
    - secretKey: DB_USER
      remoteRef:
        key: database/postgres
        property: DB_USER
    - secretKey: DB_PASSWORD
      remoteRef:
        key: database/postgres
        property: DB_PASSWORD
    - secretKey: DB_NAME
      remoteRef:
        key: database/postgres
        property: DB_NAME

```

Once the manifests were applied, they could see that a `Kubernetes` Secret named `postgres-creds` was populated containing the database credentials from Vault:

```bash
kubectl get secret postgres-creds -o json | jq '.data | map_values(@base64d)'
Alias tip: k get secret postgres-creds -o json | jq '.data | map_values(@base64d)'
{
  "DB_HOST": "172.17.0.1",
  "DB_NAME": "vault",
  "DB_PASSWORD": "P@ssw0rd",
  "DB_PORT": "5432",
  "DB_USER": "postgres"
}
```

### Using the External Secrets Manager secret
This is great! Now, all that was left to do, was to reference the `postgres-creds` secret in the applications deployment manifest using [`envFrom`](https://kubernetes.io/docs/tasks/inject-data-application/distribute-credentials-secure/#configure-all-key-value-pairs-in-a-secret-as-container-environment-variables):
<!--- {{ file "manifests/demo-app-k8s-secret.yaml" | code "yaml" }} --->
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  labels:
    app: demo-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
        - name: vault-from-zero-to-hero
          image: falcosuessgott/vault-from-zero-to-hero
          ports:
            - containerPort: 9090
          envFrom:
            - secretRef:
                name: postgres-creds

```

```bash
> curl http://localhost:9090
<html>
<head>
<title>Demo-App</title>
</head>
<body>
DB: 172.17.0.1:5432<br>User: postgres<br>Password: P@ssw0rd<br>Ping: true<br></body>
</html>
```

### Summary
The team was happy, they adopted Vault as Secrets Management Solution and no longer had to hardcode the database credentials in the Kubernetes manifests.
All the findings from the audit were resolved and the team could focus on developing new features.

## Act 03: Static Credentials from HashiCorp Vault using Approle Auth - a little better
There was still room for improvement. The security team was happy the team got rid of the plaintext credentials in the manifests.
But they criticized that they base64-hardcoded the `Vault` token in the `External Secrets Manager` manifest ... and they were right.

### Approle Authentication
The team worked together with the Infrastructure team that maintained `Vault`. Together they decided to use the [`Approle`](https://developer.hashicorp.com/vault/docs/auth/approle) method.
`Approle` is a authentication method that allows machines or apps to authenticate with Vault using a role-id and secret-id.
The Vault-team provided them with the `Approle` credentials, which ones authenticated, would have read-only access to the `database/postgres` path:

<!--- {{ file "scripts/setup-approle-auth.sh" | code "bash" }} --->
```bash
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

```

The team updated the `SecretStore` CRD to now use the `AppRole` authentication:
<!--- {{ file "manifests/esm-secret-store-approle.yml" | code "yaml" }} --->
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: http://172.17.0.1:8200
      path: secret
      version: v2
      auth:
        appRole:
          roleId: 3b836ce4-7769-0f54-2d1f-ccba336f66f3
          secretRef:
            name: vault-approle
            key: secret-id
---
apiVersion: v1
kind: Secret
metadata:
  name: vault-approle
data:
  secret-id: NjlkZjNkZjItNWZjOS05MDQxLTcxNTEtMmVlMThhMDJhNWEw

```

### Summary
Thinking they resolved the Security teams concerns about a the hardcoded token they sought their feedback about the latest changes.
While the Security team was happy that they now use an authentication method which would return a `Vault` token with read-only` access to the `database/postgres` path, they still had concerns about the hardcoded `Approle` credentials in the `External Secrets Manager` manifest.

## Act 04: Static Credentials from HashiCorp Vault using Kubernetes Auth - a little better
The team would need to find something else ...
After some more research, they found out about Vaults [`Kubernetes`](https://developer.hashicorp.com/vault/docs/auth/kubernetes) auth method, which essentially uses `Kubernetes` Service Account Token.
This way, they would not longer have to hardcode any credentials!

### Kubernetes Auth
<!--- {{ file "scripts/setup-k8s-auth.sh" | code "bash" }} --->
```bash
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

```

<!--- {{ file "manifests/esm-secret-store-k8s.yml" | code "yml" }} --->
```yml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: http://172.17.0.1:8200
      path: secret
      version: v2
      auth:
        kubernetes:
          role: esm
          serviceAccountRef:
            name: vault-auth
          secretRef:
            name: vault-auth-token
            key: token

```


## Act 05: Dynamic DB Credentials from HashiCorp Vault using Kubernetes Auth - the best
By using the `Kubernetes` auth method the security team was happy. At no point any hardcoded credentials were used. The App-Team was also very happy with the result.
In fact they were hooked HashiCorp Vault and explored further possibilities to use Vault in their applications.
They learned about the [`Database`](https://www.vaultproject.io/docs/secrets/databases) secrets engine. and figures, now where they already use dynamic credentials from Vault, why not use dynamic credentials for the database as well?

### Dynamic Database Credentials

<!--- {{ file "scripts/setup-vault-db.sh" | code "bash" }} --->
```bash
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

```

Generating credentials:

```bash
vault read database/creds/postgres # my-postgresql-database
Key                Value
---                -----
lease_id           database/creds/postgres/74nOvKCmV6BNUjy5iWE22u4Z
lease_duration     1h
lease_renewable    true
password           89ZYmtT2qgS-OG7Avi2T
username           v-token-postgres-Zv02fNPCyfXg5gzM3Jzb-1736064877
```

By switching from static to dynamic credentials, the team did not had to rely on any Kvv2 Secrets.

The `External Secrets Manager` only works for `KVv1` & `KVv2` engines, a new operator is required in order to generate dynamic credentials from Vault.
Luckily, the team found the [`Vault Secrets Operator`](https://developer.hashicorp.com/vault/tutorials/kubernetes/vault-secrets-operator) does exactly this.
## Act 06: Injecting Dynamic DB Credentials during runtime from HashiCorp Vault using Kubernetes Auth - the best


```bash
kubectl get secret dynamic-db-postgres-creds -o json | jq '.data | map_values(@base64d)'
{
  "_raw": "{\"password\":\"L4sBX4Z-5uuyBQaNJ3aH\",\"username\":\"v-kubernet-postgres-aUT9H5AAfnhYJllEvzxl-1736066694\"}",
  "password": "L4sBX4Z-5uuyBQaNJ3aH",
  "username": "v-kubernet-postgres-aUT9H5AAfnhYJllEvzxl-1736066694"
}
```

<!--- {{ file "manifests/demo-app-dynamic-db.yaml" | code "yaml" }} --->
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  labels:
    app: demo-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
        - name: vault-from-zero-to-hero
          image: falcosuessgott/vault-from-zero-to-hero
          ports:
            - containerPort: 9090
          env:
            - name: DB_HOST
              value: "172.17.0.1" # fix this using host.docker.internal
            - name: DB_PORT
              value: "5432"
            - name: DB_NAME
              value: vault
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: dynamic-db-postgres-creds
                  key: username
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: dynamic-db-postgres-creds
                  key: password

```


## Act 05

<!--- {{ file "manifests/demo-app-vai.yaml" | code "yaml" }} --->
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  labels:
    app: demo-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/agent-inject-secret-db-creds: "database/creds/postgres"
        vault.hashicorp.com/agent-inject-template-db-creds: |
          {{- with secret "database/creds/postgres" -}}
          postgres://{{ .Data.username }}:{{ .Data.password }}@postgres:5432/appdb?sslmode=disable
          {{- end }}
        vault.hashicorp.com/role: "vai"
        vault.hashicorp.com/tls-skip-verify: "true"
    spec:
      serviceAccountName: vault-auth
      containers:
        - name: vault-from-zero-to-hero
          image: falcosuessgott/vault-from-zero-to-hero
          command:
            ['sh', '-c']
          args:
            ['source /vault/secrets/db-creds && /demo-app']
          ports:
            - containerPort: 9090
          env:
            - name: DB_HOST
              value: "172.17.0.1" # fix this using host.docker.internal
            - name: DB_PORT
              value: "5432"
            - name: DB_NAME
              value: vault

```

# Where to go now from here
- vaults PKI to automatic TLS
- vaults transit engine for encryption at rest before writing to DB

# Conclusion


# Appendix
