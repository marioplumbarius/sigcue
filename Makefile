.PHONY: help

# ============================================================================
# VARIABLES
# ============================================================================

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

# ============================================================================
# INCLUDES
# ============================================================================

include makefiles/build.mk
include makefiles/dev.mk
include makefiles/test.mk
include makefiles/clean.mk

# ============================================================================
# HELP
# ============================================================================

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
