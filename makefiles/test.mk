.PHONY: test lint setup-git-hooks

# ============================================================================
# DEVELOPMENT TOOLS
# ============================================================================

test:
	@echo "Running tests..."
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-derivedDataPath $(BUILD_DIR) \
		test

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
