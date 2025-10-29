# Makefile — macOS VS Code + TDD/BDD + Infra Bootstrap
SHELL := /bin/bash
BACKUP_DIR := $(HOME)/.backups/dev-bootstrap-$(shell date +"%Y%m%d%H%M%S")
CODE_USER := $(HOME)/Library/Application Support/Code/User
GOBIN ?= $(HOME)/go/bin

# ---------- BREW PACKAGES ----------
# Core languages & CLIs
BREW_PKGS = \
  go python3 node jq yq git gh \
  azure-cli bicep \
  kubectl helm kustomize \
  opentofu tflint tfsec tofuenv\
  hadolint shellcheck \
  act \
  cmake pkg-config openssl@3

# Some tools are casks (GUI or big SDKs)
BREW_CASKS = \
  dotnet-sdk \
  visual-studio-code

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

# ---------- .NET TOOLS ----------
DOTNET_TOOLS = \
  dotnet-format \
  dotnet-reportgenerator-globaltool \
  SpecFlow.Plus.LivingDoc.CLI

# ==================================
# Public targets
# ==================================

help:
	@echo ""
	@echo "Targets:"
	@echo "  make backup        Back up current dev settings to $(BACKUP_DIR)"
	@echo "  make install       Install/upgrade tooling + VS Code config"
	@echo "  make clean-caches  Clean caches (npm/pip/pre-commit/go)"
	@echo "  make nuke          FULL remove of selected toolchains (keeps backups)"
	@echo "  make precommit     Install/refresh git pre-commit hooks"
	@echo "  make verify        Quick smoke test of toolchain versions"
	@echo ""

# Back up VS Code + language globals + brew list
backup:
	@echo "📦 Backing up current environment to: $(BACKUP_DIR)"
	@mkdir -p "$(BACKUP_DIR)"
	# Homebrew state
	@brew bundle dump --file="$(BACKUP_DIR)/Brewfile" --force || true
	@brew list >"$(BACKUP_DIR)/brew-list.txt" || true
	@brew list --cask >"$(BACKUP_DIR)/brew-cask-list.txt" || true
	# VS Code settings and extensions
	@mkdir -p "$(BACKUP_DIR)/vscode"
	@cp -a "$(CODE_USER)/." "$(BACKUP_DIR)/vscode/" 2>/dev/null || true
	@code --list-extensions >"$(BACKUP_DIR)/vscode/extensions.txt" 2>/dev/null || true
	# Node globals
	@npm list -g --depth=0 >"$(BACKUP_DIR)/npm-globals.txt" 2>/dev/null || true
	# Python env notes
	@python3 -V >"$(BACKUP_DIR)/python-version.txt" 2>/dev/null || true
	@pip3 list >"$(BACKUP_DIR)/pip3-list.txt" 2>/dev/null || true
	# Go binaries snapshot
	@mkdir -p "$(BACKUP_DIR)/gobin"
	@ls -1 "$(GOBIN)" >"$(BACKUP_DIR)/gobin/ls.txt" 2>/dev/null || true
	@echo "✅ Backup complete."

# Non-destructive cleanup of caches
clean-caches:
	@echo "🧹 Cleaning caches…"
	@rm -rf "$(HOME)/Library/Caches/pip" 2>/dev/null || true
	@rm -rf "$(HOME)/.cache/pip" "$(HOME)/.cache/pre-commit" 2>/dev/null || true
	@npm cache clean --force 2>/dev/null || true
	@go clean -cache -modcache -testcache 2>/dev/null || true
	@echo "✅ Caches cleaned."

# Full remove of selected stacks (USE WITH CARE)
# Leaves Docker Desktop alone (per your request).
nuke: backup
	@echo "⚠️  This will remove language runtimes & globals installed via Homebrew."
	@read -p "Type 'NUKE' to continue: " CONFIRM; \
	if [ "$$CONFIRM" != "NUKE" ]; then echo "Aborted."; exit 1; fi
	# Uninstall brew pkgs (ignore failures)
	@for p in $(BREW_PKGS); do brew uninstall --ignore-dependencies $$p || true; done
	# Uninstall brew casks (keep Docker Desktop untouched)
	@for c in $(BREW_CASKS); do brew uninstall --cask $$c || true; done
	# Remove Node globals we manage
	@npm ls -g --depth=0 >/dev/null 2>&1 && npm remove -g $(NPM_PKGS) || true
	# Remove Python packages (only those we installed)
	@pip3 uninstall -y $(PY_PKGS) || true
	# Remove Go tool binaries we installed
	@for tool in gopls staticcheck golangci-lint gotestsum ginkgo; do rm -f "$(GOBIN)/$$tool" 2>/dev/null || true; done
	# Remove .NET tools
	@for t in $(DOTNET_TOOLS); do dotnet tool uninstall -g $$t || true; done
	# Reset VS Code user settings (backed up already)
	@rm -rf "$(CODE_USER)" 2>/dev/null || true
	@echo "🧨 Nuke complete. You can now run 'make install'."

# Full install (idempotent)
install: brew vscode tools node python go dotnet infra precommit configure
	@echo "✅ Install complete. Open VS Code with 'code .'"

brew:
	@echo "🍺 Installing/Updating Homebrew packages…"
	@brew update
	@brew tap hashicorp/tap || true
	@brew install $(BREW_PKGS)
	@brew install --cask $(BREW_CASKS)

vscode:
	@echo "🧩 Installing VS Code extensions…"
	@if ! command -v code >/dev/null 2>&1; then \
	  echo "VS Code CLI 'code' not found. Open VS Code → Command Palette → 'Shell Command: Install 'code' command'"; \
	fi
	@jq -r '.recommendations[]' extensions.json | while read ext; do \
	  code --install-extension $$ext || true; \
	done
	@mkdir -p "$(CODE_USER)"
	@cp -f settings.json "$(CODE_USER)/settings.json"

tools:
	@echo "🔧 Base CLI polish…"
	@gh auth status >/dev/null 2>&1 || true

node:
	@echo "🟢 Installing global Node tooling…"
	@npm install -g $(NPM_PKGS)

python:
	@echo "🐍 Installing Python tooling…"
	@pip3 install --upgrade pip
	@pip3 install -g $(PY_PKGS)
	# Ensure pipx is ready if we want to isolate heavy CLIs later
	@pipx ensurepath || true

go:
	@echo "🐹 Installing Go tools…"
	@for pkg in $(GO_TOOLS); do \
	  echo "go install $$pkg"; \
	  go install $$pkg; \
	done

dotnet:
	@echo "💠 Installing .NET LTS (8.x) only..."
	# Remove any STS or preview versions
	@brew install --cask dotnet-sdk@10 || true
	# Install LTS 8.x SDK
	@brew install --cask dotnet-sdk@8 || true
	# Symlink 8.x SDK as the default if not already
	@if [ ! -e "/usr/local/share/dotnet/dotnet" ]; then \
	  sudo ln -sfn "/usr/local/share/dotnet/dotnet" /usr/local/bin/dotnet || true; \
	fi
	# Install or update global .NET tools
	@for t in $(DOTNET_TOOLS); do \
	  dotnet tool install -g $$t || dotnet tool update -g $$t || true; \
	done
	@echo "✅ Installed .NET 8/10 LTS and required global tools."

infra:
	@echo "🏗️  Installing and configuring infra tooling (tofu/tflint/tfsec/checkov/hadolint/shellcheck/helm/kubectl)…"
	@if [ -x "$$(brew --prefix)/bin/tofu" ]; then \
	  echo "alias terraform='tofu'" >> ~/.zshrc; \
	  echo "alias terraform='tofu'" >> ~/.bashrc; \
	  echo "🔗 Added terraform → tofu alias to your shell profiles."; \
	fi
	tofuenv install 1.10.6
	tofuenv use 1.10.6

precommit:
	@echo "⚙️  Installing pre-commit hooks…"
	@pre-commit install
	@pre-commit autoupdate || true

configure:
	@echo "🧽 Final editor hygiene…"
	@touch .editorconfig
	@echo "root = true\n[*]\nend_of_line = lf\ninsert_final_newline = true\ncharset = utf-8\nindent_style = space\nindent_size = 2" > .editorconfig

verify:
	@echo "🔎 Verifying installed toolchain..."
	@echo ""

	@echo "🟢 Checking core language runtimes:"
	@command -v node >/dev/null 2>&1 && node -v || echo "❌ Node not found"
	@command -v npm >/dev/null 2>&1 && npm -v || echo "❌ npm not found"
	@command -v python3 >/dev/null 2>&1 && python3 -V || echo "❌ Python not found"
	@command -v go >/dev/null 2>&1 && go version || echo "❌ Go not found"
	@command -v dotnet >/dev/null 2>&1 && dotnet --info | head -n 5 || echo "❌ .NET not found"
	@echo ""

	@echo "🏗️  Checking infra & devops tooling:"
	@command -v tofu >/dev/null 2>&1 && tofu version | head -n 1 || echo "❌ OpenTofu not found"
	@command -v tflint >/dev/null 2>&1 && tflint --version | head -n 1 || echo "❌ TFLint not found"
	@command -v tfsec >/dev/null 2>&1 && tfsec --version | head -n 1 || echo "❌ TFsec not found"
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

	@echo "✅ Verification complete."
