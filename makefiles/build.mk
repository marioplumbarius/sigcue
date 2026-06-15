.PHONY: build build-release install package open

# ============================================================================
# BUILD TARGETS
# ============================================================================

build:
	@echo "Building $(SCHEME) [$(CONFIG)]..."
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-derivedDataPath $(BUILD_DIR) \
		build

# Builds Release variant; explicitly depends on build target
build-release: CONFIG := Release
build-release: build

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

# Launch the installed app
open:
	@if [ -d "$(INSTALLED_APP)" ]; then \
		open "$(INSTALLED_APP)"; \
	else \
		echo "Error: $(APP_NAME) not found in $(APPS_DIR)"; \
		exit 1; \
	fi
