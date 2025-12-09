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

1. **Check the [issue tracker](https://github.com/battletech45/relay/issues)** to see if the bug has already been reported
2. If you find a closed issue that matches your problem, open a new issue and include a link to the original

When creating a bug report, include:

- A clear, descriptive title
- Steps to reproduce the issue
- Expected behavior vs actual behavior
- Screenshots if applicable
- Your environment (OS, Flutter version, etc.)

### Suggesting Features 💡

Feature requests are welcome! Before suggesting:

1. Check if the feature is already on our [Roadmap](README.md#roadmap)
2. Search existing issues to avoid duplicates

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

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.9.2 or higher)
- An IDE with Flutter support (VS Code, Android Studio, or IntelliJ)
- Git

### Setup Steps

1. **Fork and clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/relay.git
   cd relay
   ```

2. **Add the upstream remote**
   ```bash
   git remote add upstream https://github.com/battletech45/relay.git
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

3. **Test your changes**
   ```bash
   flutter analyze
   flutter test
   ```

4. **Commit with a meaningful message**
   ```bash
   git commit -m "Add: brief description of your changes"
   ```

5. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Open a Pull Request** against the `main` branch

### PR Requirements

- [ ] Code passes `flutter analyze` with no errors
- [ ] All existing tests pass
- [ ] New features include appropriate tests (when applicable)
- [ ] Documentation is updated if needed
- [ ] Commit messages are clear and descriptive

## Style Guidelines

### Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use the project's `analysis_options.yaml` for linting rules
- Run `flutter analyze` before committing

### Commit Messages

Use clear, descriptive commit messages:

- **Add:** for new features
- **Fix:** for bug fixes
- **Update:** for non-breaking changes
- **Remove:** for removed features
- **Docs:** for documentation changes
- **Refactor:** for code refactoring

Examples:
```
Add: environment variable autocomplete in request editor
Fix: collection filter not updating on selection change
Docs: update README with new installation instructions
```

### Architecture

Follow the existing clean architecture pattern:

```
lib/
├── core/           # Shared utilities, models, services
├── features/       # Feature modules
│   └── feature_name/
│       ├── data/           # Data layer
│       ├── domain/         # Business logic
│       └── presentation/   # UI layer
└── ui/             # Shared UI components
```

## Questions?

Feel free to open an issue with your question or reach out through GitHub Discussions.

---

Thank you for contributing to Röle! 🚀
