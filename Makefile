default: help

.PHONY: help
help: ## list makefile targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: postgres
postgres: ## start postgres container
	./scripts/setup-postgres.sh

.PHONY: vault
vault: ## start vault container
	./scripts/setup-vault.sh

.PHONY: kind
kind: ## start a local kind cluster
	./scripts/setup-kind.sh

.PHONY: clean
clean: ## clean up all resources
	./scripts/cleanup.sh || true

.PHONY: part-01
part-01: clean postgres vault kind ## run part 01 - hardcoded credentials
	# deploy app
	kubectl apply -f manifests/demo-app-hardcoded.yaml

	# verify its working
	kubectl exec $(kubectl get po -l app=demo-app -o jsonpath='{.items[*].metadata.name}') -- curl -s localhost:9090

.PHONY: part-02
part-02: clean postgres vault kind ## run part 02 - esm with token auth
	# setup vault
	vault kv put secret/database/postgres username=postgres password=P@ssw0rd

	# setup esm
	./scripts/setup-esm.sh
	kubectl apply -f manifests/esm-secret-store-token.yml
	kubectl apply -f manifests/esm-external-secret.yml

	# deploy app
	kubectl apply -f manifests/demo-app-k8s-secret.yaml

	# verify its working
	kubectl exec $(kubectl get po -l app=demo-app -o jsonpath='{.items[*].metadata.name}') -- curl -s localhost:9090

.PHONY: part-03
part-03: clean postgres vault kind ## run part 03 - esm with approle auth
	# setup vault
	vault kv put secret/database/postgres username=postgres password=P@ssw0rd
	./scripts/setup-vault-approle-auth.sh

	# setup esm
	./scripts/setup-esm.sh
	kubectl apply -f manifests/esm-secret-store-approle.yml
	kubectl apply -f manifests/esm-external-secret.yml

	# deploy app
	kubectl apply -f manifests/demo-app-k8s-secret.yaml

	# verify its working
	kubectl exec $(kubectl get po -l app=demo-app -o jsonpath='{.items[*].metadata.name}') -- curl -s localhost:9090

.PHONY: part-04
part-04: clean postgres vault kind ## run part 04 - esm with k8s auth
	# setup vault
	vault kv put secret/database/postgres username=postgres password=P@ssw0rd
	kubectl apply -f manifests/vault-crb.yml
	./scripts/setup-vault-k8s-auth.sh

	# setup esm
	./scripts/setup-esm.sh
	kubectl apply -f manifests/esm-secret-store-k8s.yml
	kubectl apply -f manifests/esm-external-secret.yml

	# deploy app
	kubectl apply -f manifests/demo-app-k8s-secret.yaml

	# verify its working
	kubectl exec $(kubectl get po -l app=demo-app -o jsonpath='{.items[*].metadata.name}') -- curl -s localhost:9090

.PHONY: part-05
part-05: clean postgres vault kind ## run part 05 - vso with dynamic db credentials
	# setup vault
	./scripts/setup-vault-db.sh
	kubectl apply -f manifests/vault-crb.yml
	./scripts/setup-vault-k8s-auth.sh

	# setup vso
	./scripts/setup-vso.sh
	kubectl apply -f manifests/vso.yaml

	# deploy app
	kubectl apply -f manifests/demo-app-vso-dynamic-db.yaml

	# verify its working
	kubectl exec $(kubectl get po -l app=demo-app -o jsonpath='{.items[*].metadata.name}') -- curl -s localhost:9090

.PHONY: part-06
part-06: clean postgres vault kind ## run part 06 - vai with dynamic db credentials
	# setup vault
	./scripts/setup-vault-db.sh
	kubectl apply -f manifests/vault-crb.yml
	./scripts/setup-vault-k8s-auth.sh

	# setup vai
	./scripts/setup-vai.sh

	# deploy app
	kubectl apply -f manifests/demo-app-vai.yaml

	# verify its working
	kubectl exec $(kubectl get po -l app=demo-app -o jsonpath='{.items[*].metadata.name}') -c vault-from-zero-to-hero -- curl -s localhost:9090

	# scale deployment
	kubectl scale deployment demo-app --replicas=5

	# verify
	for pod in $(kubectl get po -l app=demo-app -o jsonpath='{.items[*].metadata.name}'); do echo $pod && kubectl exec $pod -c vault-from-zero-to-hero -- curl -s localhost:9090; done
