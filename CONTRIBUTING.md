# Contributing to Röle

First off, thank you for considering contributing to Röle! 🎉

Every contribution helps make Röle a better API testing tool for everyone. This document provides guidelines and steps for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Style Guidelines](#style-guidelines)

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior by opening an issue.

## Getting Started

- Make sure you have a [GitHub account](https://github.com/signup)
- Fork the repository on GitHub
- Clone your fork locally
- Set up your development environment (see below)

## How Can I Contribute?

### Reporting Bugs 🐛

Before creating a bug report:

1. **Check the [issue tracker](https://github.com/role-suite/role-client/issues)** to see if the bug has already been reported
2. If you find a closed issue that matches your problem, open a new issue and include a link to the original

When creating a bug report, include:

- A clear, descriptive title
- Steps to reproduce the issue
- Expected behavior vs actual behavior
- Screenshots if applicable
- Your environment (OS, Flutter version, etc.)

### Suggesting Features 💡

Feature requests are welcome! Before suggesting:

1. Search existing issues to avoid duplicates
2. Check [docs/](docs/) to confirm the feature doesn't already exist

When creating a feature request:

- Use a clear, descriptive title
- Explain why this feature would be useful
- Describe the expected behavior
- Include mockups or examples if possible

### Pull Requests 🔧

We actively welcome pull requests! Here's how:

1. Fork the repo and create your branch from `main`
2. Make your changes
3. Test your changes thoroughly
4. Update documentation if needed
5. Submit a pull request

## Development Setup

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.44.0 or higher)
- An IDE with Flutter support (VS Code, Android Studio, or IntelliJ)
- Git

### Setup Steps

1. **Fork and clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/role-client.git
   cd role-client
   ```

2. **Add the upstream remote**
   ```bash
   git remote add upstream https://github.com/role-suite/role-client.git
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the app**
   ```bash
   flutter run -d macos  # or windows, linux, chrome, etc.
   ```

5. **Run tests**
   ```bash
   flutter test
   ```

### Keeping Your Fork Updated

```bash
git fetch upstream
git checkout main
git merge upstream/main
```

## Pull Request Process

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following our style guidelines

3. **Format, analyze, and test your changes**
   ```bash
   dart format .
   flutter analyze
   flutter test
   ```

4. **Commit with a meaningful message**
   ```bash
   git commit -m "feat: add environment variable autocomplete"
   ```

5. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Open a Pull Request** against the `main` branch

### PR Requirements

CI (`.github/workflows/`) enforces these automatically, so it's worth checking them locally first:

- [ ] `dart format --output=none --set-exit-if-changed .` reports no changes
- [ ] `flutter analyze` passes with no issues (this includes `riverpod_lint`)
- [ ] `flutter test` passes
- [ ] The macOS/Windows/Linux build-check workflow would still compile (no platform-specific breakage)
- [ ] The PR title follows [Conventional Commits](https://www.conventionalcommits.org/) (see below) — checked by `pr-title.yml`
- [ ] New features include appropriate tests (when applicable)
- [ ] Documentation in [`docs/`](docs/) is updated if the change affects architecture, data model, or setup

## Style Guidelines

### Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use the project's `analysis_options.yaml` for linting rules; don't disable a rule locally without a good reason
- Run `dart format .` and `flutter analyze` before committing

### Commit Messages and PR Titles

The PR title (not every individual commit) must start with one of these [Conventional Commits](https://www.conventionalcommits.org/) types, enforced by CI:

`feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

Examples:
```
feat: add environment variable autocomplete in request editor
fix: collection filter not updating on selection change
docs: update README with new installation instructions
```

### Architecture

Röle is local-only and has no backend, so it doesn't use a repository/usecase/data-domain-presentation
split. Follow the existing structure instead:

```
lib/
├── core/       # Models, local JSON storage, HTTP execution, import/export, theme, utils
├── state/      # Riverpod notifiers — this *is* the data/business-logic layer
└── ui/         # Widgets, organized by the workbench section they belong to
                # (shell/, sidebar/, request/, environments/, history/, runner/, flows/, widgets/)
```

See [docs/02-ARCHITECTURE.md](docs/02-ARCHITECTURE.md) for the full picture, and
[docs/07-MAINTENANCE.md](docs/07-MAINTENANCE.md) for how to add a new feature within it.

## Questions?

Feel free to open an issue with your question or reach out through GitHub Discussions.

---

Thank you for contributing to Röle! 🚀
