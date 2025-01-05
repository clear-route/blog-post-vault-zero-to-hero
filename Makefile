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
