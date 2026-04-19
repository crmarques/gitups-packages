# gitups-packages Makefile
# Thin wrappers around tools/ scripts for local development.
#
# Usage:
#   make validate PKG=<name>           # schema + consistency + structure
#   make build PKG=<name>              # deterministic tarball into dist/
#   make publish PKG=<name> OWNER=<o>  # oras push to GHCR (requires oras login)
#   make index                         # regenerate index/index.json
#   make validate-all                  # validate every package
#   make build-all                     # build every package
#   make clean                         # remove dist/

PKG ?=
OWNER ?=
REGISTRY ?= ghcr.io

ALL_PKGS := $(notdir $(wildcard packages/*))

.PHONY: validate build publish index validate-all build-all clean help

help:
	@awk 'BEGIN{FS=":.*##"; printf "Targets:\n"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

validate: ## Validate PKG=<name>
	@test -n "$(PKG)" || (echo "usage: make validate PKG=<name>"; exit 2)
	tools/validate-package.sh "$(PKG)"

build: ## Build PKG=<name> tarball into dist/
	@test -n "$(PKG)" || (echo "usage: make build PKG=<name>"; exit 2)
	tools/package-build.sh "$(PKG)"

publish: build ## Publish PKG=<name> to OWNER=<ghcr-owner>
	@test -n "$(PKG)" || (echo "usage: make publish PKG=<name> OWNER=<owner>"; exit 2)
	@test -n "$(OWNER)" || (echo "usage: make publish PKG=<name> OWNER=<owner>"; exit 2)
	tools/package-publish.sh "$(PKG)" --owner "$(OWNER)" --registry "$(REGISTRY)"

index: ## Regenerate index/index.json
	tools/generate-index.sh $(if $(OWNER),--owner $(OWNER),)

validate-all: ## Validate every package
	@for p in $(ALL_PKGS); do \
	  echo "==> $$p"; \
	  tools/validate-package.sh "$$p" || exit $$?; \
	done

build-all: ## Build every package
	@for p in $(ALL_PKGS); do \
	  echo "==> $$p"; \
	  tools/package-build.sh "$$p" || exit $$?; \
	done

clean: ## Remove dist/ and any ad-hoc build output
	rm -rf dist
