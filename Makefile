# Development entry points. Plain make so the dev loop needs no extra package.
#
# All real work lives in scripts/ -- these targets are thin wrappers, so the
# same commands run identically in CI.

.PHONY: help link install uninstall run restart log lint lint-slug lint-layers lint-qml brand test clean

SHELL := /bin/bash
SLUG  := $(shell jq -r .slug branding.json)
UNIT  := $(SLUG).service

help: ## Show available targets
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | sort | \
	 awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

brand: ## Regenerate all generated files (branding, qmldir, widget index)
	@scripts/gen-branding.sh
	@scripts/gen-qmldir.sh
	@scripts/gen-widget-index.sh

link: ## Symlink the shell into place (development; edits are live)
	@scripts/install.sh --link

install: ## Copy the shell into place (frozen install)
	@scripts/install.sh --copy

uninstall: ## Remove everything the manifest owns
	@scripts/install.sh --uninstall

run: brand ## Run the shell in the foreground against the working tree
	@QML2_IMPORT_PATH="$(CURDIR)/shell:$$QML2_IMPORT_PATH" \
	 quickshell -n -p shell/shell.qml

restart: ## Restart the installed systemd user unit
	@systemctl --user restart $(UNIT)

log: ## Follow the shell's journal
	@journalctl --user -u $(UNIT) -f

lint: lint-slug lint-layers lint-qml ## Run every lint

lint-slug: ## Fail if the project name is hardcoded anywhere
	@scripts/lint-slug.sh

lint-layers: ## Fail on imports that violate the dependency ladder
	@scripts/lint-layers.sh

lint-qml: brand ## Run qmllint over the shell
	@scripts/lint-qml.sh

clean: ## Remove generated files
	@rm -f shell/core/Branding.qml

test: brand ## Run the QML test suite
	@scripts/test.sh
