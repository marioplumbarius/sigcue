.PHONY: dev release

# ============================================================================
# CONVENIENCE SHORTCUTS FOR LOCAL DEVELOPMENT
# ============================================================================

# Debug variant: fast iteration during development; includes debug symbols and skips optimizations
dev: CONFIG := Debug
dev: clean-cache install

# Release variant: optimized build for distribution testing and performance validation before shipping
release: CONFIG := Release
release: clean-cache install

.PHONY: clean-cache

clean-cache:
	@echo "Cleaning Xcode cache and derived data..."
	@rm -rf $(DERIVED_DATA)
	@rm -rf $(BUILD_DIR)
	@echo "✓ Cache cleaned"
