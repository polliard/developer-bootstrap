
# Makefile — macOS VS Code + TDD/BDD + Infra + Swift (Xcode) Bootstrap + Scaffolds
SHELL := /bin/bash
BACKUP_DIR := $(HOME)/.backups/dev-bootstrap-$(shell date +"%Y%m%d%H%M%S")
CODE_USER := $(HOME)/Library/Application\ Support/Code/User
GOBIN ?= $(HOME)/go/bin
WORKSPACE := $(HOME)/Workspace

# ---------- BREW PACKAGES (CLI/Libs) ----------
BREW_PKGS = \
  go python3 node jq yq git gh \
  azure-cli bicep \
  kubectl helm kustomize \
  opentofu tflint tfsec \
  trivy grype \
  hadolint shellcheck \
  act \
  cmake pkg-config openssl@3 \
  swiftlint swiftformat

# ---------- BREW CASKS (GUI/SDKs) ----------
BREW_CASKS = \
  visual-studio-code \
  dotnet-sdk@8

# ---------- NPM GLOBALS ----------
NPM_PKGS = \
  prettier eslint typescript typescript-language-server \
  eslint_d \
  jest jest-junit mocha chai vitest \
  @types/jest @types/node \
  cucumber @cucumber/cucumber

# ---------- PYTHON PACKAGES ----------
PY_PKGS = \
  pipx \
  black isort ruff pre-commit \
  pytest pytest-cov hypothesis \
  behave \
  checkov yamllint

# ---------- GO TOOLS ----------
GO_TOOLS = \
  golang.org/x/tools/gopls@latest \
  honnef.co/go/tools/cmd/staticcheck@latest \
  github.com/golangci/golangci-lint/cmd/golangci-lint@latest \
  gotest.tools/gotestsum@latest \
  github.com/onsi/ginkgo/v2/ginkgo@latest \
  github.com/onsi/gomega@latest

# ---------- .NET GLOBAL TOOLS ----------
DOTNET_TOOLS = \
  dotnet-format \
  dotnet-reportgenerator-globaltool \
  SpecFlow.Plus.LivingDoc.CLI

.PHONY: help backup clean-caches nuke install brew xcode dotnet vscode tools node python go infra precommit configure verify \
        new:swift new:dotnet new:go new:py new:ts \
        _ensure_path _write_project_makefile _write_common_gitignore _write_common_editorconfig \
        _write_common_dockerignore _write_docker_scan_targets

help:
	@echo ""
	@echo "Targets:"
	@echo "  make backup        Back up current dev settings to $(BACKUP_DIR)"
	@echo "  make nuke          Remove toolchains (backs up first)"
	@echo "  make install       Install/upgrade tooling + VS Code config + ~/bin/createProject"
	@echo "  make verify        Quick smoke test of toolchain versions"
	@echo "  make new:<lang> NAME=MyProj   # swift | dotnet | go | py | ts"
	@echo ""

backup:
	@echo "📦 Backing up current environment to: $(BACKUP_DIR)"
	@mkdir -p "$(BACKUP_DIR)"
	@brew bundle dump --file="$(BACKUP_DIR)/Brewfile" --force || true
	@brew list >"$(BACKUP_DIR)/brew-list.txt" || true
	@brew list --cask >"$(BACKUP_DIR)/brew-cask-list.txt" || true
	@mkdir -p "$(BACKUP_DIR)/vscode"
	@cp -a $(CODE_USER)/. "$(BACKUP_DIR)/vscode/" 2>/dev/null || true
	@code --list-extensions >"$(BACKUP_DIR)/vscode/extensions.txt" 2>/dev/null || true
	@npm list -g --depth=0 >"$(BACKUP_DIR)/npm-globals.txt" 2>/dev/null || true
	@python3 -V >"$(BACKUP_DIR)/python-version.txt" 2>/dev/null || true
	@pip3 list >"$(BACKUP_DIR)/pip3-list.txt" 2>/dev/null || true
	@mkdir -p "$(BACKUP_DIR)/gobin"
	@ls -1 "$(GOBIN)" >"$(BACKUP_DIR)/gobin/ls.txt" 2>/dev/null || true
	@echo "✅ Backup complete."

clean-caches:
	@echo "🧹 Cleaning caches…"
	@rm -rf "$(HOME)/Library/Caches/pip" 2>/dev/null || true
	@rm -rf "$(HOME)/.cache/pip" "$(HOME)/.cache/pre-commit" 2>/dev/null || true
	@npm cache clean --force 2>/dev/null || true
	@go clean -cache -modcache -testcache 2>/dev/null || true
	@echo "✅ Caches cleaned."

nuke: backup
	@echo "⚠️  This will remove language runtimes & globals installed via Homebrew."
	@read -p "Type 'NUKE' to continue: " CONFIRM; \
	if [ "$$CONFIRM" != "NUKE" ]; then echo "Aborted."; exit 1; fi
	@for p in $(BREW_PKGS); do brew uninstall --ignore-dependencies $$p || true; done
	@for c in $(BREW_CASKS); do brew uninstall --cask $$c || true; done
	@npm ls -g --depth=0 >/dev/null 2>&1 && npm remove -g $(NPM_PKGS) || true
	@pip3 uninstall -y $(PY_PKGS) || true
	@for tool in gopls staticcheck golangci-lint gotestsum ginkgo; do rm -f "$(GOBIN)/$$tool" 2>/dev/null || true; done
	@for t in $(DOTNET_TOOLS); do dotnet tool uninstall -g $$t || true; done
	@rm -rf $(CODE_USER) 2>/dev/null || true
	@echo "🧨 Nuke complete. You can now run 'make install'."

install: brew xcode dotnet vscode tools node python go infra precommit configure _ensure_path
	@echo "✅ Install complete. Open VS Code with 'code .'"

brew:
	@echo "🍺 Installing/Updating Homebrew packages…"
	@brew update
	@brew tap hashicorp/tap || true
	@brew install $(BREW_PKGS)
	@brew install --cask $(BREW_CASKS)

xcode:
	@echo "🛠  Ensuring Xcode command line tools & license…"
	@if ! xcode-select -p >/dev/null 2>&1; then \
	  echo "• Installing Xcode Command Line Tools (a popup may appear)…"; \
	  xcode-select --install || true; \
	fi
	@sudo xcodebuild -license accept || true
	@xcode-select -p >/dev/null 2>&1 && echo "✅ Xcode CLI tools present." || echo "⚠️ Please complete Xcode CLI tools installation manually."
	@swift --version || echo "⚠️ Swift not available yet; it becomes available after Xcode/CLI tools finish."

dotnet:
	@echo "💠 Installing .NET LTS (8.x) only..."
	@brew uninstall --cask dotnet-sdk@6 || true
	@brew uninstall --cask dotnet-sdk@9 || true
	@brew uninstall --cask dotnet-sdk@10 || true
	@brew install --cask dotnet-sdk@8 || true
	@for t in $(DOTNET_TOOLS); do \
	  dotnet tool install -g $$t || dotnet tool update -g $$t || true; \
	done
	@echo "✅ Installed .NET 8 LTS and required global tools."

vscode:
	@echo "🧩 Installing VS Code extensions..."
	@if ! command -v code >/dev/null 2>&1; then \
	  echo "⚠️  VS Code CLI 'code' not found. Launch VS Code → Command Palette → 'Shell Command: Install code command'"; \
	fi
	@if [ -f extensions.json ]; then \
	  jq -r '.recommendations[]' extensions.json | while read ext; do \
	    code --install-extension $$ext || true; \
	  done; \
	fi
	@code --install-extension sswg.swift || true
	@code --install-extension vknabel.vscode-swiftlint || true
	@code --install-extension ms-dotnettools.csdevkit || true
	@code --install-extension ms-dotnettools.csharp || true
	@code --install-extension formulahendry.dotnet-test-explorer || true
	@mkdir -p $(CODE_USER)
	@cp -f settings.json $(CODE_USER)/settings.json 2>/dev/null || true
	@mkdir -p .vscode
	@cat > .vscode/settings.json <<'JSON'
{
  "dotnet.defaultSolution": "YourProject.sln",
  "dotnet.sdkPath": "/usr/local/share/dotnet/sdk",
  "dotnet.sdkVersion": "8.0",
  "dotnet.defaultRuntime": "8.0",
  "dotnet-test-explorer.testProjectPath": "**/*Tests.csproj",
  "dotnet-test-explorer.autoWatch": true,
  "omnisharp.sdkPath": "/usr/local/share/dotnet/sdk/8.0.*",
  "omnisharp.useModernNet": true,
  "CSharp.enableEditorConfigSupport": true,
  "CSharp.defaultFormatter": "ms-dotnettools.csharp",
  "dotnet-test-explorer.testArguments": "--logger trx --results-directory TestResults",
  "files.exclude": { "**/bin": true, "**/obj": true }
}
JSON
	@echo "✅ VS Code configured for .NET 8 LTS & Swift development."

tools:
	@echo "🔧 Base CLI polish…"
	@gh auth status >/dev/null 2>&1 || true

node:
	@echo "🟢 Installing global Node tooling…"
	@npm install -g $(NPM_PKGS)

python:
	@echo "🐍 Installing Python tooling…"
	@pip3 install --upgrade pip
	@pip3 install $(PY_PKGS)
	@pipx ensurepath || true

go:
	@echo "🐹 Installing Go tools…"
	@for pkg in $(GO_TOOLS); do \
	  echo "go install $$pkg"; \
	  go install $$pkg; \
	done

infra:
	@echo "🏗️  Infra linters & extras ready (tofu/tflint/tfsec/checkov/hadolint/shellcheck/helm/kubectl)."
	@if [ -x "$$(brew --prefix)/bin/tofu" ]; then \
	  grep -q "alias terraform='tofu'" ~/.zshrc 2>/dev/null || echo "alias terraform='tofu'" >> ~/.zshrc; \
	  grep -q "alias terraform='tofu'" ~/.bashrc 2>/dev/null || echo "alias terraform='tofu'" >> ~/.bashrc; \
	  echo "🔗 Added terraform → tofu alias to your shell profiles."; \
	fi

precommit:
	@echo "⚙️  Installing pre-commit hooks…"
	@pre-commit install
	@pre-commit autoupdate || true

configure:
	@echo "🧽 Final editor hygiene…"
	@touch .editorconfig
	@cat > .editorconfig <<'EOF'
root = true
[*]
end_of_line = lf
insert_final_newline = true
charset = utf-8
indent_style = space
indent_size = 2
EOF
	@mkdir -p $(HOME)/bin
	@cat > $(HOME)/bin/createProject <<'SH'
#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: createProject <swift|dotnet|go|py|ts> <ProjectName>"
  exit 1
fi

LANG="$1"
NAME="$2"

BOOTSTRAP_HOME="${BOOTSTRAP_HOME:-"__BOOTSTRAP_HOME__"}"
if [[ "$BOOTSTRAP_HOME" == "__BOOTSTRAP_HOME__" ]]; then
  for p in "$HOME/dev-bootstrap" "$HOME/Developer/dev-bootstrap" "$HOME/Workspace/dev-bootstrap" "$PWD"; do
    if [[ -f "$p/Makefile" ]]; then
      BOOTSTRAP_HOME="$p"
      break
    fi
  done
fi

if [[ ! -f "$BOOTSTRAP_HOME/Makefile" ]]; then
  echo "Could not locate bootstrap Makefile. Set BOOTSTRAP_HOME env var to your bootstrap repo."
  exit 2
fi

make -C "$BOOTSTRAP_HOME" "new:${LANG}" NAME="$NAME"
SH
	@chmod +x $(HOME)/bin/createProject
	@grep -q 'export PATH=\$$HOME/bin:\$$PATH' ~/.zshrc 2>/dev/null || echo 'export PATH=$$HOME/bin:$$PATH' >> ~/.zshrc
	@grep -q 'export PATH=\$$HOME/bin:\$$PATH' ~/.bashrc 2>/dev/null || echo 'export PATH=$$HOME/bin:$$PATH' >> ~/.bashrc
	@/usr/bin/sed -i '' "s|__BOOTSTRAP_HOME__|$(PWD)|g" "$(HOME)/bin/createProject"

verify:
	@echo "🔎 Verifying installed toolchain..."
	@echo ""
	@echo "🟢 Checking core language runtimes:"
	@command -v node >/dev/null 2>&1 && node -v || echo "❌ Node not found"
	@command -v npm >/dev/null 2>&1 && npm -v || echo "❌ npm not found"
	@command -v python3 >/dev/null 2>&1 && python3 -V || echo "❌ Python not found"
	@command -v go >/dev/null 2>&1 && go version || echo "❌ Go not found"
	@command -v dotnet >/dev/null 2>&1 && dotnet --info | head -n 5 || echo "❌ .NET not found"
	@command -v swift >/dev/null 2>&1 && swift --version || echo "❌ Swift not found"
	@echo ""
	@echo "🍎 Checking Xcode toolchain:"
	@xcode-select -p >/dev/null 2>&1 && echo "Xcode path: $$(xcode-select -p)" || echo "❌ Xcode CLI tools missing"
	@command -v swiftlint >/dev/null 2>&1 && swiftlint version || echo "❌ SwiftLint not found"
	@command -v swiftformat >/dev/null 2>&1 && swiftformat --version || echo "❌ SwiftFormat not found"
	@echo ""
	@echo "🏗️  Checking infra & devops tooling:"
	@command -v tofu >/dev/null 2>&1 && tofu version | head -n 1 || echo "❌ OpenTofu not found"
	@command -v tflint >/dev/null 2>&1 && tflint --version | head -n 1 || echo "❌ TFLint not found"
	@command -v tfsec >/dev/null 2>&1 && tfsec --version | head -n 1 || echo "❌ TFsec not found"
	@command -v trivy >/dev/null 2>&1 && trivy -v | head -n 1 || echo "❌ Trivy not found"
	@command -v grype >/dev/null 2>&1 && grype version | head -n 1 || echo "❌ Grype not found"
	@command -v checkov >/dev/null 2>&1 && checkov --version || echo "❌ Checkov not found"
	@command -v kubectl >/dev/null 2>&1 && kubectl version --client --output=yaml | head -n 5 || echo "❌ kubectl not found"
	@command -v helm >/dev/null 2>&1 && helm version | head -n 1 || echo "❌ Helm not found"
	@command -v hadolint >/dev/null 2>&1 && hadolint --version || echo "❌ Hadolint not found"
	@command -v shellcheck >/dev/null 2>&1 && shellcheck --version | head -n 1 || echo "❌ ShellCheck not found"
	@command -v act >/dev/null 2>&1 && act --version || echo "❌ act not found"
	@echo ""
	@echo "🧩 Checking VS Code CLI:"
	@command -v code >/dev/null 2>&1 && code --version | head -n 1 || echo "❌ VS Code CLI not found"
	@echo ""
	@echo "💠 Checking .NET SDKs:"
	@if command -v dotnet >/dev/null 2>&1; then \
	  dotnet --list-sdks | grep "8\." || echo "⚠️ Only .NET 8.x LTS should be installed."; \
	else \
	  echo "❌ .NET not found"; \
	fi
	@echo ""
	@echo "✅ Verification complete."

# -------------------- SCAFFOLDS --------------------
_write_common_gitignore:
	@cat > "$(TARGET_DIR)/.gitignore" <<'GIT'
.vscode/
.DS_Store
node_modules/
bin/
obj/
.packages/
.env/
.venv/
__pycache__/
coverage/
reports/
GIT

_write_common_editorconfig:
	@cat > "$(TARGET_DIR)/.editorconfig" <<'EC'
root = true
[*]
end_of_line = lf
insert_final_newline = true
charset = utf-8
indent_style = space
indent_size = 2
EC

_write_common_dockerignore:
	@cat > "$(TARGET_DIR)/.dockerignore" <<'DI'
.git
.gitignore
.vscode
reports
node_modules
bin
obj
.env
.venv
DI

new:swift:
	@if [ -z "$(NAME)" ]; then read -p "Project name: " NAME; fi; \
	TARGET_DIR="$(WORKSPACE)/$${NAME}"; \
	mkdir -p "$${TARGET_DIR}"; \
	cd "$${TARGET_DIR}" && swift package init --type executable; \
	mkdir -p "$${TARGET_DIR}/Features" "$${TARGET_DIR}/reports"; \
	$(MAKE) TARGET_DIR="$${TARGET_DIR}" _write_common_gitignore _write_common_editorconfig _write_common_dockerignore; \
	cat > "$${TARGET_DIR}/Dockerfile" <<'DF'\
FROM cgr.dev/chainguard/swift:latest-dev\nWORKDIR /app\nCOPY . .\nRUN swift build -c release\nUSER 65532:65532\nCMD ["swift","run"]\
DF
	cat > "$${TARGET_DIR}/Makefile" <<'MK'\
SHELL := /bin/bash\nAPP := $(notdir $(CURDIR))\nreports := reports\ninit:\n\t@echo "Swift init complete."\nbuild:\n\tswift build\ntest:\n\tmkdir -p $(reports)\n\tswift test | tee $(reports)/swift-test.log\nbdd:\n\t@echo "Add a Swift BDD framework if desired."\nclean:\n\trm -rf .build $(reports)\ndestroy: clean\ndocker-build:\n\tdocker build -t $(APP):latest .\ndocker-run:\n\tdocker run --rm -it -p 8080:8080 $(APP):latest\ndocker-test:\n\tdocker build -t $(APP):latest . && docker run --rm $(APP):latest true\ndocker-scan:\n\thadolint Dockerfile || true\n\ttrivy image --exit-code 0 --severity MED,CRIT,HIGH $(APP):latest || true\n\tgrype $(APP):latest || true\nMK
	cd "$${TARGET_DIR}" && git init && git add . && git commit -m "Init Swift scaffold" && code "$${TARGET_DIR}"

new:dotnet:
	@if [ -z "$(NAME)" ]; then read -p "Project name: " NAME; fi; \
	TARGET_DIR="$(WORKSPACE)/$${NAME}"; \
	mkdir -p "$${TARGET_DIR}" "$${TARGET_DIR}/reports"; \
	cd "$${TARGET_DIR}" && dotnet new sln -n "$${NAME}"; \
	cd "$${TARGET_DIR}" && dotnet new webapi -n "$${NAME}.Api" --no-https; \
	cd "$${TARGET_DIR}" && dotnet new xunit -n "$${NAME}.Tests"; \
	cd "$${TARGET_DIR}" && dotnet sln add "$${NAME}.Api/$${NAME}.Api.csproj" "$${NAME}.Tests/$${NAME}.Tests.csproj"; \
	cd "$${TARGET_DIR}/$${NAME}.Tests" && dotnet add package coverlet.collector && dotnet add package SpecFlow && dotnet add package SpecFlow.xUnit; \
	mkdir -p "$${TARGET_DIR}/$${NAME}.Tests/Features"; \
	printf "Feature: Sample\n  Scenario: Adds numbers\n    Given two numbers\n    When I add them\n    Then I get a result\n" > "$${TARGET_DIR}/$${NAME}.Tests/Features/sample.feature"; \
	$(MAKE) TARGET_DIR="$${TARGET_DIR}" _write_common_gitignore _write_common_editorconfig _write_common_dockerignore; \
	cat > "$${TARGET_DIR}/Dockerfile" <<'DF'\
FROM cgr.dev/chainguard/dotnet-sdk:8\nWORKDIR /src\nCOPY . .\nRUN dotnet restore && dotnet build -c Release\nEXPOSE 8080\nUSER 65532:65532\nCMD ["dotnet","run","--project","*.Api/*.Api.csproj","--urls","http://0.0.0.0:8080"]\
DF
	cat > "$${TARGET_DIR}/Makefile" <<'MK'\
SHELL := /bin/bash\nAPP := $(notdir $(CURDIR))\nSOLUTION := $(APP).sln\nAPI := $(APP).Api/$(APP).Api.csproj\nTEST := $(APP).Tests/$(APP).Tests.csproj\nreports := reports\ninit:\n\tdotnet restore\nbuild:\n\tdotnet build -c Release\ntest:\n\tmkdir -p $(reports)\n\tdotnet test $(TEST) -c Release --collect:"XPlat Code Coverage" --logger "trx;LogFileName=$(reports)/test.trx"\nbdd:\n\t@echo "Add SpecFlow step definitions to enable BDD execution."\nclean:\n\tdotnet clean\n\trm -rf $(reports)\ndestroy: clean\ndocker-build:\n\tdocker build -t $(APP):latest .\ndocker-run:\n\tdocker run --rm -it -p 8080:8080 $(APP):latest\ndocker-test:\n\tdocker build -t $(APP):latest . && docker run --rm $(APP):latest true\ndocker-scan:\n\thadolint Dockerfile || true\n\ttrivy image --exit-code 0 --severity MED,CRIT,HIGH $(APP):latest || true\n\tgrype $(APP):latest || true\nMK
	cd "$${TARGET_DIR}" && git init && git add . && git commit -m "Init .NET scaffold" && code "$${TARGET_DIR}"

new:go:
	@if [ -z "$(NAME)" ]; then read -p "Project name: " NAME; fi; \
	TARGET_DIR="$(WORKSPACE)/$${NAME}"; \
	mkdir -p "$${TARGET_DIR}" "$${TARGET_DIR}/reports"; \
	cd "$${TARGET_DIR}" && go mod init "$${NAME}" && go get github.com/onsi/ginkgo/v2/ginkgo github.com/onsi/gomega; \
	printf "package main\nimport \"fmt\"\nfunc main(){fmt.Println(\"hello\")}\n" > "$${TARGET_DIR}/main.go"; \
	printf "package main\nimport (\"testing\"; \"github.com/onsi/gomega\")\nfunc TestTruth(t *testing.T){ gomega.NewWithT(t).Expect(1).To(gomega.Equal(1)) }\n" > "$${TARGET_DIR}/main_test.go"; \
	$(MAKE) TARGET_DIR="$${TARGET_DIR}" _write_common_gitignore _write_common_editorconfig _write_common_dockerignore; \
	cat > "$${TARGET_DIR}/Dockerfile" <<'DF'\
FROM cgr.dev/chainguard/go:latest\nWORKDIR /app\nCOPY go.mod go.sum ./\nRUN go mod download\nCOPY . .\nRUN go build -o app .\nUSER 65532:65532\nCMD ["./app"]\
DF
	cat > "$${TARGET_DIR}/Makefile" <<'MK'\
SHELL := /bin/bash\nAPP := $(notdir $(CURDIR))\nreports := reports\ninit:\n\tgo mod tidy\nbuild:\n\tgo build -o bin/$(APP) .\ntest:\n\tmkdir -p $(reports)\n\tgotestsum --format short-verbose -- -cover ./... | tee $(reports)/go-test.log\nbdd:\n\tginkgo -v ./...\nclean:\n\trm -rf bin $(reports)\ndestroy: clean\ndocker-build:\n\tdocker build -t $(APP):latest .\ndocker-run:\n\tdocker run --rm -it -p 8080:8080 $(APP):latest\ndocker-test:\n\tdocker build -t $(APP):latest . && docker run --rm $(APP):latest true\ndocker-scan:\n\thadolint Dockerfile || true\n\ttrivy image --exit-code 0 --severity MED,CRIT,HIGH $(APP):latest || true\n\tgrype $(APP):latest || true\nMK
	cd "$${TARGET_DIR}" && git init && git add . && git commit -m "Init Go scaffold" && code "$${TARGET_DIR}"

new:py:
	@if [ -z "$(NAME)" ]; then read -p "Project name: " NAME; fi; \
	TARGET_DIR="$(WORKSPACE)/$${NAME}"; \
	mkdir -p "$${TARGET_DIR}/src" "$${TARGET_DIR}/tests" "$${TARGET_DIR}/features/steps" "$${TARGET_DIR}/reports"; \
	python3 -m venv "$${TARGET_DIR}/.venv"; \
	. "$${TARGET_DIR}/.venv/bin/activate"; \
	pip install --upgrade pip pytest pytest-cov behave black ruff isort; \
	echo 'def add(a,b): return a+b' > "$${TARGET_DIR}/src/app.py"; \
	echo 'from src.app import add\ndef test_add(): assert add(1,2)==3' > "$${TARGET_DIR}/tests/test_app.py"; \
	echo 'Feature: math\n  Scenario: add\n    Given numbers\n    When I add\n    Then I see the sum' > "$${TARGET_DIR}/features/math.feature"; \
	$(MAKE) TARGET_DIR="$${TARGET_DIR}" _write_common_gitignore _write_common_editorconfig _write_common_dockerignore; \
	cat > "$${TARGET_DIR}/Dockerfile" <<'DF'\
FROM cgr.dev/chainguard/python:latest\nWORKDIR /app\nCOPY . .\nRUN python -m venv .venv && . .venv/bin/activate && pip install --upgrade pip && pip install -r /dev/null || true\nUSER 65532:65532\nCMD ["/bin/sh","-c",". .venv/bin/activate && pytest -q"]\
DF
	cat > "$${TARGET_DIR}/Makefile" <<'MK'\
SHELL := /bin/bash\nAPP := $(notdir $(CURDIR))\nVENV := .venv\nreports := reports\ninit:\n\tpython3 -m venv $(VENV)\n\t. $(VENV)/bin/activate && pip install --upgrade pip pytest pytest-cov behave black ruff isort\nbuild:\n\t@echo "Python build not required."\ntest:\n\tmkdir -p $(reports)\n\t. $(VENV)/bin/activate && pytest -q --cov=src --cov-report=term-missing --cov-report html:$(reports)/html --junitxml=$(reports)/junit.xml\nbdd:\n\t. $(VENV)/bin/activate && behave -q\nclean:\n\trm -rf $(reports) .pytest_cache\ndestroy: clean\n\trm -rf $(VENV)\ndocker-build:\n\tdocker build -t $(APP):latest .\ndocker-run:\n\tdocker run --rm -it -p 8080:8080 $(APP):latest\ndocker-test:\n\tdocker build -t $(APP):latest . && docker run --rm $(APP):latest true\ndocker-scan:\n\thadolint Dockerfile || true\n\ttrivy image --exit-code 0 --severity MED,CRIT,HIGH $(APP):latest || true\n\tgrype $(APP):latest || true\nMK
	cd "$${TARGET_DIR}" && git init && git add . && git commit -m "Init Python scaffold" && code "$${TARGET_DIR}"

new:ts:
	@if [ -z "$(NAME)" ]; then read -p "Project name: " NAME; fi; \
	TARGET_DIR="$(WORKSPACE)/$${NAME}"; \
	mkdir -p "$${TARGET_DIR}/src" "$${TARGET_DIR}/tests" "$${TARGET_DIR}/features/steps" "$${TARGET_DIR}/reports"; \
	cd "$${TARGET_DIR}" && npm init -y >/dev/null 2>&1; \
	cd "$${TARGET_DIR}" && npm i -D typescript ts-node @types/node jest ts-jest @types/jest @cucumber/cucumber eslint prettier; \
	cd "$${TARGET_DIR}" && npx tsc --init --rootDir src --outDir dist --esModuleInterop --resolveJsonModule --module commonjs --target es2020 >/dev/null; \
	echo 'export const add=(a:number,b:number)=>a+b;' > "$${TARGET_DIR}/src/app.ts"; \
	echo 'import {add} from "../src/app"; test("add",()=>{expect(add(1,2)).toBe(3)})' > "$${TARGET_DIR}/tests/app.test.ts"; \
	echo 'Feature: math\n  Scenario: add\n    Given numbers\n    When I add\n    Then I see the sum' > "$${TARGET_DIR}/features/math.feature"; \
	$(MAKE) TARGET_DIR="$${TARGET_DIR}" _write_common_gitignore _write_common_editorconfig _write_common_dockerignore; \
	cat > "$${TARGET_DIR}/package.json" <<'PJ'\
{\n  "name": "ts-app",\n  "version": "1.0.0",\n  "type": "commonjs",\n  "scripts": {\n    "build": "tsc",\n    "test": "jest --passWithNoTests",\n    "bdd": "cucumber-js"\n  }\n}\
PJ
	cat > "$${TARGET_DIR}/jest.config.js" <<'J'\
module.exports = { preset: "ts-jest", testEnvironment: "node", testMatch: ["**/tests/**/*.test.ts"] };\
J
	cat > "$${TARGET_DIR}/Dockerfile" <<'DF'\
FROM cgr.dev/chainguard/node:latest\nWORKDIR /app\nCOPY package*.json ./\nRUN npm ci || npm i\nCOPY . .\nRUN npm run build\nUSER 65532:65532\nCMD ["npm","test","--","--runInBand"]\
DF
	cat > "$${TARGET_DIR}/Makefile" <<'MK'\
SHELL := /bin/bash\nAPP := $(notdir $(CURDIR))\nreports := reports\ninit:\n\tnpm i\nbuild:\n\tnpm run build\ntest:\n\tmkdir -p $(reports)\n\tnpm test -- --json --outputFile=$(reports)/jest.json\nbdd:\n\tnpm run bdd\nclean:\n\trm -rf dist $(reports)\ndestroy: clean\ndocker-build:\n\tdocker build -t $(APP):latest .\ndocker-run:\n\tdocker run --rm -it -p 3000:3000 $(APP):latest\ndocker-test:\n\tdocker build -t $(APP):latest . && docker run --rm $(APP):latest true\ndocker-scan:\n\thadolint Dockerfile || true\n\ttrivy image --exit-code 0 --severity MED,CRIT,HIGH $(APP):latest || true\n\tgrype $(APP):latest || true\nMK
	cd "$${TARGET_DIR}" && git init && git add . && git commit -m "Init TypeScript scaffold" && code "$${TARGET_DIR}"

_ensure_path:
	@mkdir -p $(HOME)/bin
	@command -v createProject >/dev/null 2>&1 && echo "createProject found." || echo "Run 'source ~/.zshrc' to add ~/bin to PATH if needed."
