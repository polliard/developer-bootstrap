# 🧱 Developer Bootstrap for macOS
### Unified VS Code + TDD/BDD + Infrastructure Environment

This project provides a **complete, reproducible developer environment** on macOS.  
It unifies multiple languages — Go, Python, C#, JavaScript/TypeScript — and Infrastructure-as-Code tooling into a single, consistent stack centered around **Visual Studio Code**.

It is designed to:
- Replace JetBrains IDEs with VS Code.
- Support Test-Driven (TDD) and Behavior-Driven (BDD) workflows.
- Manage consistent formatting, linting, and security scanning across projects.
- Safely back up and rebuild your entire toolchain.

---

## ⚙️ Quick Start

```bash
git clone <your-org-or-repo-url> dev-bootstrap
cd dev-bootstrap

# Back up your current setup first
make backup

# (Optional) Nuke existing toolchains (creates backup automatically)
make nuke

# Install full environment
make install

# Verify installation and versions
make verify
```

Then open VS Code:
```bash
code .
```

---

## 🧩 What’s Installed

| Category | Tools |
|-----------|-------|
| **Languages** | Go, Python 3, Node + TypeScript, .NET SDK |
| **Infrastructure** | OpenTofu (Terraform replacement), Bicep, Azure CLI, kubectl, Helm, Kustomize |
| **Lint / Format** | Prettier, ESLint, Black, Ruff, Isort, GolangCI-Lint, dotnet-format |
| **Security / Quality** | TFLint, TFsec, Checkov, Hadolint, ShellCheck |
| **Testing / TDD / BDD** | Pytest + Behave (Python), Ginkgo/Gomega (Go), xUnit + SpecFlow (.NET), Jest/Mocha/Cucumber (JS/TS) |
| **VS Code Integration** | Extensions + settings for all languages and infra |

---

## 🧭 Makefile Commands

| Command | Description |
|----------|-------------|
| `make backup` | Back up current VS Code and language environments to `~/.backups/<timestamp>` |
| `make nuke` | Backs up then removes brew-installed language runtimes and global packages |
| `make install` | Installs everything (brew, language stacks, infra tools, VS Code setup) |
| `make clean-caches` | Removes pip/go/npm/pre-commit caches |
| `make precommit` | Installs or updates git pre-commit hooks |
| `make verify` | Checks for required binaries before showing version info |

> 💡 You can rerun `make install` anytime; it’s idempotent.

---

## 💻 VS Code Integration

After `make install`:
1. Launch **VS Code** (`code .`).
2. Extensions in `extensions.json` are auto-installed.
3. Settings from `settings.json` enable:
   - Format-on-Save  
   - Auto-fix lint errors  
   - Organized imports  
   - Built-in Test Explorer  
4. Run or debug tests inline by clicking the test icons next to each test or using the sidebar **Testing** panel.

---

## 🧪 Test-Driven Development (TDD)

### 🐍 Python
```bash
pytest
pytest -v --maxfail=1 --disable-warnings
```
Frameworks: **pytest**, **hypothesis**  
Integrated in VS Code via the Python Test Explorer.

---

### 🐹 Go
```bash
gotestsum --format short-verbose ./...
```
Frameworks: **go test**, **Ginkgo/Gomega**  
Files ending in `_test.go` are automatically detected in VS Code.

---

### 💠 C# / .NET
```bash
dotnet test
```
Frameworks: **xUnit** (TDD) and **SpecFlow** (BDD).  
To generate living documentation:
```bash
livingdoc test-assembly <YourTestProject>.dll -t <YourTestProject>.dll
```

---

### 🟢 JavaScript / TypeScript
```bash
npm test          # Jest (default)
npm run test:bdd  # Cucumber if used
```
Frameworks: **Jest**, **Mocha/Chai**, **Cucumber**  
VS Code’s Jest extension highlights results inline.

---

## 🧬 Behavior-Driven Development (BDD)

BDD frameworks are preinstalled for each ecosystem:

| Language | Framework | Feature File Example |
|-----------|------------|----------------------|
| Python | Behave | `features/example.feature` |
| Go | Ginkgo/Gomega | `_test.go` |
| .NET | SpecFlow | `Features/Login.feature` |
| JS/TS | @cucumber/cucumber | `features/example.feature` |

Example Gherkin file:
```gherkin
Feature: User Login
  Scenario: Valid user logs in successfully
    Given a registered user
    When they log in with valid credentials
    Then they should see the dashboard
```

Run examples:
```bash
behave
ginkgo -v
dotnet test
npx cucumber-js
```

---

## 🏗 Infrastructure & DevOps

### OpenTofu (Terraform replacement)
Installed via Homebrew with an alias:
```bash
alias terraform='tofu'
```
You can still run:
```bash
terraform plan
terraform apply
```
and it will use OpenTofu under the hood.

### Linting & Security
Pre-commit hooks run automatically on commit:
- **tflint**, **tfsec**, **checkov** — IaC linting & scanning
- **hadolint** — Dockerfile linting
- **yamllint** — YAML hygiene
- **shellcheck** — bash script validation

### Azure & Kubernetes
```bash
az login
kubectl get pods
helm install myapp ./chart
```

---

## 🔍 Pre-Commit Hooks

Installed automatically via `make precommit`.  
They enforce consistent formatting, linting, and security scanning for every language:

- `black`, `isort`, `ruff` — Python  
- `golangci-lint` — Go  
- `eslint`, `prettier` — JS/TS  
- `dotnet format` — C#  
- `tflint`, `tfsec`, `checkov` — Infra  
- `hadolint`, `shellcheck`, `yamllint`, `markdownlint` — Containers, scripts, docs

To re-install or update:
```bash
make precommit
```

---

## 🧼 Rebuild or Reset

If your environment drifts, rebuild cleanly:
```bash
make backup
make nuke
make install
make verify
```

All backups are stored under:
```
~/.backups/dev-bootstrap-<timestamp>/
```

---

## 🧠 Notes

- `terraform` is aliased to `tofu` automatically.  
  Open a new terminal or `source ~/.zshrc` to enable it immediately.  
- Docker Desktop is left intact — you can continue using it normally.  
- `make install` is safe to re-run; it updates existing tools instead of reinstalling from scratch.
- Run `make help` to see all available targets.

---

## 🤝 Contributing

To extend support for new languages or CI/CD tools:
1. Add your brew/pip/npm/go/dotnet packages to the relevant section of the `Makefile`.  
2. Add recommended VS Code extensions to `extensions.json`.  
3. Add relevant formatters or linters to `.pre-commit-config.yaml`.  
4. Re-run `make install && make verify`.

---

## 🧭 License

This repository is distributed under your organization’s internal tooling or MIT license (adjust as needed).

---

**Welcome to your unified dev environment.**  
One `make install`, and you’re home.
