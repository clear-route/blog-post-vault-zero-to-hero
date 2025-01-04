default: help

.PHONY: help
help: ## list makefile targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: postgres
postgres: ## start postgres container
	docker run --rm --name postgres \
		-p 5432:5432 \
		-e POSTGRES_USER=postgres \
		-e POSTGRES_PASSWORD=P@ssw0rd \
		-e POSTGRES_DB=vault \
		postgres

.PHONY: vault
vault: ## start vault container
	docker run --rm --name vault \
		-p 8200:8200 \
		--link postgres:postgres \
		-e VAULT_DEV_ROOT_TOKEN_ID=root \
		-e VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 \
		hashicorp/vault