.PHONY: clean uninstall

# ============================================================================
# CLEANUP
# ============================================================================

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
