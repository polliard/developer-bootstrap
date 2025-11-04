# ==========================================
# 🛠️  Development Bootstrap Makefile
# ==========================================

SHELL := /bin/bash

# ----- Variables -----
WORKSPACE    := $(HOME)/Workspace
BACKUP_DIR   := $(HOME)/.backups
CODE_USER    := $(HOME)/Library/Application\ Support/Code/User
NAME         ?= ExampleProject

DOTNET_TOOLS := dotnet-ef dotnet-format
SEC_TOOLS    := trivy grype hadolint
BREW_PKGS    := git jq python3 go node openjdk openvpn
INFRA_TOOLS  := opentofu
LANGS        := swift dotnet go py ts

# ==========================================
# 📦 Bootstrap Targets
# ==========================================

.PHONY: all install verify clean backup nuke vscode tofu dotnet swift go py ts xcode

all: install verify

install: backup brew tofu dotnet xcode swift go py ts vscode sec-tools
	@echo "✅ All components installed."

verify:
	@echo "🔍 Verifying binaries..."
	@for bin in brew jq git python3 go node tofu dotnet swift; do \
	  if ! command -v $$bin >/dev/null 2>&1; then \
	    echo "❌ Missing $$bin"; exit 1; \
	  fi; \
	done
	@echo "💠 Checking .NET SDKs:"
	@if command -v dotnet >/dev/null 2>&1; then \
	  dotnet --list-sdks | grep "8\." || echo "⚠️ Only .NET 8.x LTS should be installed."; \
	else \
	  echo "❌ .NET not found"; \
	fi
	@echo "✅ Verification complete."

backup:
	@mkdir -p $(BACKUP_DIR)
	@tar czf $(BACKUP_DIR)/backup_$$(date +%Y%m%d_%H%M%S).tar.gz $(HOME)/bin $(CODE_USER) || true
	@echo "💾 Backup created at $(BACKUP_DIR)"

nuke:
	@echo "⚠️ Removing all developer tools..."
	@brew uninstall --force $(BREW_PKGS) $(INFRA_TOOLS) $(SEC_TOOLS) || true
	@rm -rf $(HOME)/.dotnet $(HOME)/.swiftpm $(HOME)/.nuget $(HOME)/.npm $(HOME)/.tox || true
	@echo "🧹 Environment cleaned."

brew:
	@if ! command -v brew >/dev/null 2>&1; then \
	  echo "🍺 Installing Homebrew..."; \
	  /bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile; \
	  eval "$(/opt/homebrew/bin/brew shellenv)"; \
	fi
	@brew update

tofu:
	@echo "🌱 Installing OpenTofu..."
	@brew install opentofu || true
	@if ! grep -q 'alias terraform=' $(HOME)/.zshrc 2>/dev/null; then \
	  echo "alias terraform='tofu'" >> $(HOME)/.zshrc; \
	fi

dotnet:
	@echo "💠 Installing .NET 8 LTS..."
	@brew uninstall --cask dotnet-sdk@6 || true
	@brew uninstall --cask dotnet-sdk@9 || true
	@brew install --cask dotnet-sdk@8 || true
	@for t in $(DOTNET_TOOLS); do \
	  dotnet tool install -g $$t || dotnet tool update -g $$t || true; \
	done
	@echo "✅ .NET 8 LTS setup complete."

xcode:
	@echo "🧰 Checking for Xcode command-line tools..."
	@if ! xcode-select -p >/dev/null 2>&1; then \
	  xcode-select --install; \
	fi
	@sudo xcodebuild -license accept || true
	@echo "✅ Xcode toolchain ready."

swift:
	@echo "🦅 Setting up Swift toolchain..."
	@brew install swiftlint swiftformat || true
	@echo "✅ Swift ready."

go:
	@echo "🐹 Installing Go..."
	@brew install go || true
	@echo "✅ Go ready."

py:
	@echo "🐍 Installing Python..."
	@brew install python3 || true
	@pip3 install pytest behave coverage || true
	@echo "✅ Python ready."

ts:
	@echo "🪄 Installing Node & TypeScript..."
	@brew install node || true
	@npm install -g typescript jest cucumber prettier || true
	@echo "✅ TypeScript ready."

sec-tools:
	@echo "🔒 Installing security tools..."
	@brew install $(SEC_TOOLS) || true
	@echo "✅ Security tools installed."

vscode:
	@echo "🧩 Installing VS Code extensions..."
	@if ! command -v code >/dev/null 2>&1; then \
	  echo "⚠️ VS Code CLI not found (enable via Command Palette)."; \
	else \
	  code --install-extension ms-dotnettools.csdevkit || true; \
	  code --install-extension ms-dotnettools.csharp || true; \
	  code --install-extension formulahendry.dotnet-test-explorer || true; \
	  code --install-extension kreativgeist.csharpextensions || true; \
	  code --install-extension jmrog.vscode-nuget-package-manager || true; \
	  code --install-extension sswg.swift || true; \
	  code --install-extension vknabel.vscode-swiftlint || true; \
	fi
	@echo "✅ VS Code configured."

# ==========================================
# 🧱 Project Scaffolding
# ==========================================

new:%:
	@echo "🔧 Creating $* project named $(NAME)..."
	@$(MAKE) "scaffold-$*" NAME="$(NAME)"

scaffold-swift:
	@mkdir -p $(WORKSPACE)/$(NAME)
	@cd $(WORKSPACE)/$(NAME) && swift package init --type executable
	@touch $(WORKSPACE)/$(NAME)/Tests/$(NAME)Tests/ExampleTests.swift
	@echo "reports/" > $(WORKSPACE)/$(NAME)/.gitignore
	@$(MAKE) common-scaffold LANG=swift

scaffold-dotnet:
	@mkdir -p $(WORKSPACE)/$(NAME)
	@cd $(WORKSPACE)/$(NAME) && dotnet new webapi -n $(NAME)
	@cd $(WORKSPACE)/$(NAME) && dotnet new xunit -n $(NAME).Tests
	@$(MAKE) common-scaffold LANG=dotnet

scaffold-go:
	@mkdir -p $(WORKSPACE)/$(NAME)
	@cd $(WORKSPACE)/$(NAME) && go mod init $(NAME)
	@echo 'package main\nimport "fmt"\nfunc main(){fmt.Println("Hello from $(NAME)!")}' > $(WORKSPACE)/$(NAME)/main.go
	@echo 'package main\nimport "testing"\nfunc TestExample(t *testing.T){}' > $(WORKSPACE)/$(NAME)/main_test.go
	@$(MAKE) common-scaffold LANG=go

scaffold-py:
	@mkdir -p $(WORKSPACE)/$(NAME)/tests
	@cd $(WORKSPACE)/$(NAME) && python3 -m venv venv && source venv/bin/activate && pip install pytest behave
	@echo 'def test_example(): assert True' > $(WORKSPACE)/$(NAME)/tests/test_example.py
	@$(MAKE) common-scaffold LANG=py

scaffold-ts:
	@mkdir -p $(WORKSPACE)/$(NAME)
	@cd $(WORKSPACE)/$(NAME) && npm init -y && npm install --save-dev jest cucumber prettier
	@echo 'test("example", () => expect(true).toBe(true));' > $(WORKSPACE)/$(NAME)/test.spec.ts
	@$(MAKE) common-scaffold LANG=ts

# ----- Shared project setup -----
common-scaffold:
	@mkdir -p $(WORKSPACE)/$(NAME)/reports
	@cd $(WORKSPACE)/$(NAME) && echo "init:\n\t@echo 'Setting up $(LANG) project...'\n\nbuild:\n\t@echo 'Building...'\n\n test:\n\t@echo 'Running tests...'\n\nbdd:\n\t@echo 'Running BDD tests...'\n\ndocker-build:\n\tdocker build -t $(NAME):latest .\n\ndocker-run:\n\tdocker run --rm $(NAME):latest\n\ndocker-test:\n\t@echo 'Running tests in container...'\n\ndocker-scan:\n\ttrivy image $(NAME):latest && grype $(NAME):latest\n" > Makefile
	@cd $(WORKSPACE)/$(NAME) && echo "FROM cgr.dev/chainguard/wolfi-base\nWORKDIR /app\nCOPY . .\nRUN adduser -D appuser\nUSER appuser\nCMD [\"/bin/sh\"]" > Dockerfile
	@cd $(WORKSPACE)/$(NAME) && git init -q && git add . && git commit -m "Initial scaffold for $(LANG) project" >/dev/null
	@code $(WORKSPACE)/$(NAME)
	@echo "✅ $(LANG) project scaffolded at $(WORKSPACE)/$(NAME)"
