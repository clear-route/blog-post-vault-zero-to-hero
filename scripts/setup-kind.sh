# scripts/setup-kind.sh

# Start a Kubernetes cluster using KinD
kind create cluster \
	--name vault-from-zero-to-hero \
	--config manifests/kind-config.yml
