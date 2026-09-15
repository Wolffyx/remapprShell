# Development entry points. Plain make so the dev loop needs no extra package.
#
# All real work lives in scripts/ -- these targets are thin wrappers, so the
# same commands run identically in CI.

.PHONY: help link install uninstall run restart log lint lint-slug lint-layers lint-qml lint-docs lint-widgets lint-tests lint-defaults docs brand test clean plugin plugin-clean

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
	@scripts/gen-colors.sh

link: ## Symlink the shell into place (development; widget edits need `rmpr reload`)
	@scripts/install.sh --link

install: ## Copy the shell into place (frozen install)
	@scripts/install.sh --copy

uninstall: ## Remove everything the manifest owns
	@scripts/install.sh --uninstall

run: brand ## Run the shell in the foreground against the working tree
# The absolute path is what makes the process say where it came from: every
# "is the shell running?" check reads the command line, and a relative
# `shell/shell.qml` names no tree at all.
	@QML2_IMPORT_PATH="$(CURDIR)/shell:$$QML2_IMPORT_PATH" \
	 quickshell -n -p "$(CURDIR)/shell/shell.qml"

restart: ## Restart the installed systemd user unit
	@systemctl --user restart $(UNIT)

log: ## Follow the shell's journal
	@journalctl --user -u $(UNIT) -f

lint: lint-slug lint-layers lint-qml lint-widgets lint-tests lint-docs lint-defaults ## Run every lint

lint-slug: ## Fail if the project name is hardcoded anywhere
	@scripts/lint-slug.sh

lint-layers: ## Fail on imports that violate the dependency ladder
	@scripts/lint-layers.sh

docs: brand ## Regenerate the configuration reference
	@scripts/gen-docs.sh

lint-widgets: ## Fail on widget mistakes qmllint cannot see
	@scripts/lint-widgets.sh

lint-defaults: ## Fail if the schema and the shipped defaults disagree
	@scripts/lint-defaults.sh

lint-docs: ## Fail if the configuration reference is out of date
	@scripts/lint-docs.sh

lint-tests: ## Fail if a QML test imports a module needing a running shell
	@scripts/lint-tests.sh

lint-qml: brand ## Run qmllint over the shell
	@scripts/lint-qml.sh

plugin: ## Build and install the window-preview plugin (needs Qt6 dev + cmake)
	@cmake -S plugin -B build/plugin -DCMAKE_BUILD_TYPE=Release
	@cmake --build build/plugin
	@cmake --install build/plugin
	@printf '\033[32m==>\033[0m window previews installed; restart the shell to pick them up\n'

plugin-clean: ## Remove the plugin's build directory and installed module
	@rm -rf build/plugin "$(HOME)/.local/lib/qt6/qml/KWinScreencast"
	@printf '\033[32m==>\033[0m window previews removed\n'

clean: ## Remove generated files
	@rm -f shell/core/Branding.qml theme/colors/*.colors

test: brand ## Run the QML test suite
	@scripts/test.sh
