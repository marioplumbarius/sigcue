.PHONY: build install clean test help dev release uninstall lint package setup-git-hooks

SCHEME := sigcue
PROJECT := sigcue.xcodeproj
BUILD_DIR := build
DERIVED_DATA := ~/Library/Developer/Xcode/DerivedData
APPS_DIR := /Applications
APP_NAME := sigcue.app
INSTALLED_APP := $(APPS_DIR)/$(APP_NAME)

# Default configuration
CONFIG ?= Debug

# Automatically set up git hooks on first run
_setup_hooks := $(shell git config core.hooksPath >/dev/null 2>&1 || git config core.hooksPath .githooks)

help:
	@echo "sigcue macOS App Build"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  build          Build the app (Debug by default)"
	@echo "  build-release  Build the app in Release mode"
	@echo "  install        Build and install to /Applications"
	@echo "  uninstall      Remove the app from /Applications"
	@echo "  test           Run unit tests"
	@echo "  clean          Remove build artifacts"
	@echo "  dev            Build Debug version and install"
	@echo "  release        Build Release version and install"
	@echo ""
	@echo "Options:"
	@echo "  CONFIG=Release  Use Release configuration (default: Debug)"
	@echo ""

build:
	@echo "Building $(SCHEME) [$(CONFIG)]..."
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-derivedDataPath $(BUILD_DIR) \
		build

# Convenience wrapper; allows 'make build CONFIG=Release' or 'make build-release'
build-release:
	@$(MAKE) build CONFIG=Release

test:
	@echo "Running tests..."
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-derivedDataPath $(BUILD_DIR) \
		test

# Removes existing installation to prevent conflicts; locates built app via find to handle derivedData path variance
install: build
	@echo "Installing $(APP_NAME) to $(APPS_DIR)..."
	@if [ -d "$(INSTALLED_APP)" ]; then \
		echo "Removing existing installation..."; \
		rm -rf "$(INSTALLED_APP)"; \
	fi
	@APP_PATH=$$(find $(BUILD_DIR) -name "$(APP_NAME)" -type d | head -1); \
	if [ -z "$$APP_PATH" ]; then \
		echo "Error: Failed to find built app"; \
		exit 1; \
	fi; \
	echo "Copying from $$APP_PATH"; \
	cp -R "$$APP_PATH" "$(APPS_DIR)/"
	@echo "✓ Installation complete"
	@echo "  Run with: open $(INSTALLED_APP)"

# Common shortcut for local development
dev:
	@$(MAKE) install CONFIG=Debug

# Common shortcut for distribution/testing Release builds locally
release:
	@$(MAKE) install CONFIG=Release

# Cleans both build artifacts and Xcode's derived data cache; derived data can cause stale rebuilds
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BUILD_DIR)
	rm -rf $(DERIVED_DATA)/sigcue-*
	@echo "✓ Clean complete"

# Idempotent; succeeds silently if app not installed
uninstall:
	@echo "Uninstalling $(APP_NAME)..."
	@if [ -d "$(INSTALLED_APP)" ]; then \
		rm -rf "$(INSTALLED_APP)"; \
		echo "✓ Uninstalled"; \
	else \
		echo "$(APP_NAME) not found in $(APPS_DIR)"; \
	fi

# Uses SwiftLint for style enforcement; auto-installs via Homebrew if missing
lint:
	@echo "Running SwiftLint..."
	@if ! command -v swiftlint &> /dev/null; then \
		brew install swiftlint; \
	fi
	swiftlint

# Auto-invoked on first Makefile call; stores hook path in git config so developers don't need manual setup
setup-git-hooks:
	@git config core.hooksPath .githooks
	@echo "✓ Git hooks configured"

# Only packages Release builds (Debug is for local development, not distribution)
package: build-release
	@echo "Packaging $(APP_NAME)..."
	@mkdir -p release-assets
	@APP_PATH=$$(find $(BUILD_DIR) -name "$(APP_NAME)" -type d | head -1); \
	if [ -z "$$APP_PATH" ]; then \
		echo "Error: Failed to find built app"; \
		exit 1; \
	fi; \
	cp -R "$$APP_PATH" release-assets/
	@cd release-assets && zip -r ../sigcue.zip sigcue.app
	@echo "✓ Package created: sigcue.zip"
