# scripts/cleanup.sh

# Delete kind cluster
kind delete cluster --name vault-from-zero-to-hero

# Stop and remove docker images
docker stop vault postgres
docker rm vault postgres
