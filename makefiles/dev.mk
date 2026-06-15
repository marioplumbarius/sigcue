.PHONY: dev release

# ============================================================================
# CONVENIENCE SHORTCUTS FOR LOCAL DEVELOPMENT
# ============================================================================

# Debug variant: fast iteration during development; includes debug symbols and skips optimizations
dev: CONFIG := Debug
dev: install

# Release variant: optimized build for distribution testing and performance validation before shipping
release: CONFIG := Release
release: install
