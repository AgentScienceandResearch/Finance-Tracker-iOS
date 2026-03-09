PROJECT := IOSAppTemplate.xcodeproj
SCHEME := TemplateApp
DESTINATION := platform=iOS Simulator,name=iPhone 17

.PHONY: help bootstrap tools generate-project ensure-project format lint build test build-fresh test-fresh ci ci-fresh demo-no-firebase clean

help:
	@echo "Targets:"
	@echo "  bootstrap         Install/project bootstrap"
	@echo "  tools             Install xcodegen/swiftlint/swiftformat via Homebrew"
	@echo "  generate-project  Generate Xcode project from project.yml"
	@echo "  ensure-project    Generate Xcode project only if missing"
	@echo "  format            Format Swift files"
	@echo "  lint              Run SwiftLint"
	@echo "  build             Build iOS app (preserves manual Xcode edits)"
	@echo "  test              Run unit tests (preserves manual Xcode edits)"
	@echo "  build-fresh       Regenerate project, then build"
	@echo "  test-fresh        Regenerate project, then test"
	@echo "  ci                Generate, lint, build, test"
	@echo "  ci-fresh          Same as ci (explicit alias)"
	@echo "  demo-no-firebase  Build demo path without Firebase requirement"
	@echo "  clean             Clean build artifacts"

tools:
	brew install xcodegen swiftlint swiftformat || true

bootstrap:
	./scripts/bootstrap.sh

generate-project:
	xcodegen generate --spec project.yml

ensure-project:
	@if [ ! -d "$(PROJECT)" ]; then \
		echo "Xcode project missing; generating from project.yml..."; \
		$(MAKE) generate-project; \
	fi

format:
	swiftformat "App Template" "App TemplateTests"

lint:
	swiftlint --strict

build: ensure-project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -destination "$(DESTINATION)" build

test: ensure-project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -destination "$(DESTINATION)" test

ci: generate-project lint build test

build-fresh: generate-project build

test-fresh: generate-project test

ci-fresh: ci

demo-no-firebase:
	./scripts/demo-no-firebase.sh

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean
	rm -rf DerivedData
