ENV=.env
-include $(ENV)

all : setup, set-env, set-test, set-prod, migrate, run-test, help
.PHONY : all
.DEFAULT_GOAL := help

setup: ## install dependencies into container.
	@echo "Installing dependencies"
	docker-compose run --rm nest yarn --skip-integrity-check --network-concurrency 1

set-dev: ## define NODE_ENV AS development (NODE_ENV=development)
	@$(call set_env,"development")

set-test: ## define NODE_ENV AS testing (NODE_ENV=testing)
	@$(call set_env,"testing")

set-prod: ## define NODE_ENV AS production (NODE_ENV=production)
	@$(call set_env,"production")

migrate:  ## run yarn migration:up alias for yarn migration:up
	@echo "Migrating database"
	docker-compose run nest yarn migration:up

run-test:
	@echo "Runing unit tests"
	docker-compose down && docker-compose up -d


help:  ## display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

# helpers
define set_env ## helper for define NODE_END
 $(eval $@_NODE_ENV = $(1))
	sed -i -r "s#^(NODE_ENV=).*#\1$(1)#" $(ENV)
endef
