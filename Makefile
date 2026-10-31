# Local dev entry points — the commands in AGENTS.md, without the copy-paste.
# The real work lives in scripts/; nothing here is duplicated logic.

.PHONY: build test lint check app dmg run clean

build: ## compile the debug binaries
	swift build

test: ## run the Swift Testing suites (no models needed)
	swift test

lint: ## swiftlint with this repo's config
	@command -v swiftlint >/dev/null || { echo "swiftlint missing: brew install swiftlint"; exit 1; }
	swiftlint

check: build test lint ## what CI does on a pull request

app: ## release build + both .app bundles
	scripts/make-app.sh

dmg: ## app bundles + build/WhoRealtime.dmg
	scripts/make-dmg.sh

run: app ## build and launch the menu bar app
	open "build/WhoRealtime.app"

clean: ## drop .build and build
	rm -rf .build build
