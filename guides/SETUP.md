# OnlineStatsChains.jl - Setup Guide

This guide helps you set up the development environment for OnlineStatsChains.jl.

## Quick Start (Julia Only)

If you only want to use or develop the package without commit hooks:

```bash
# Clone the repository
git clone https://github.com/femtotrader/OnlineStatsChains.jl.git
cd OnlineStatsChains.jl

# Install Julia dependencies
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Run tests
julia --project=. -e 'using Pkg; Pkg.test()'

# Build documentation
cd docs
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. make.jl
```

## Full Development Setup (with Pre-commit Hooks)

For contributors who want the complete development environment:

### Prerequisites

1. **Julia 1.10+**
   - Download from [julialang.org](https://julialang.org/downloads/)
   - Verify: `julia --version`

2. **Git**
   - Usually pre-installed on macOS/Linux
   - Windows: Download from [git-scm.com](https://git-scm.com/)
   - Verify: `git --version`

3. **Python 3.7+** (for pre-commit hooks)
   - macOS/Linux: Often pre-installed
   - Windows: Download from [python.org](https://www.python.org/downloads/)
   - Verify: `python --version` or `python3 --version`

### Installation Steps

#### 1. Clone and Setup Julia

```bash
git clone https://github.com/femtotrader/OnlineStatsChains.jl.git
cd OnlineStatsChains.jl
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

#### 2. Install Pre-commit (Python)

**Option A - Using pip:**
```bash
pip install pre-commit
# or
pip3 install pre-commit
```

**Option B - Using conda:**
```bash
conda install -c conda-forge pre-commit
```

**Option C - Using homebrew (macOS):**
```bash
brew install pre-commit
```

Verify installation:
```bash
pre-commit --version
```

#### 3. Install Git Hooks

```bash
# Install pre-commit hook (runs before commits)
pre-commit install

# Install commit-msg hook (validates commit messages)
pre-commit install --hook-type commit-msg
```

You should see:
```
pre-commit installed at .git/hooks/pre-commit
pre-commit installed at .git/hooks/commit-msg
```

#### 4. Run Hooks Manually (Optional)

Test the hooks on all files:
```bash
pre-commit run --all-files
```

### What the Hooks Do

#### Pre-commit Hook
- ✅ Remove trailing whitespace
- ✅ Ensure files end with newline
- ✅ Validate YAML/TOML files
- ✅ Prevent large files (>5MB)
- ✅ Check for merge conflicts

#### Commit-msg Hook
- ✅ Validate conventional commit format

### Making Commits

Commits must follow [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Good commits
git commit -m "feat: add new feature"
git commit -m "fix: correct bug in propagation"
git commit -m "docs: update README"

# Bad commits (will be rejected)
git commit -m "made some changes"
git commit -m "WIP"
git commit -m "Update file.jl"
```

Valid types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

### Bypassing Hooks (Not Recommended)

If you absolutely need to skip hooks:
```bash
git commit --no-verify -m "your message"
```

### Updating Hooks

Keep hooks up to date:
```bash
pre-commit autoupdate
```

## Testing

### Run All Tests

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Expected output:
```
Test Summary:                             | Pass  Total
OnlineStatsChains.jl - BDD Specifications |   72     72
Integration with OnlineStats.jl           |   26     26
Testing OnlineStatsChains tests passed
```

### Run Specific Test File

```bash
julia --project=. test/runtests.jl
julia --project=. test/test_integration_onlinestats.jl
```

## Building Documentation

```bash
cd docs
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. make.jl
```

Documentation will be built to `docs/build/`.

Open in browser:
- `docs/build/index.html`

## Troubleshooting

### Pre-commit Issues

**"command not found: pre-commit"**
- Make sure Python is installed: `python --version`
- Install pre-commit: `pip install pre-commit`
- Check PATH includes Python scripts directory

**Hooks not running**
```bash
# Reinstall hooks
pre-commit uninstall
pre-commit install
pre-commit install --hook-type commit-msg
```

**Hooks fail on first run**
```bash
# Run manually to see detailed errors
pre-commit run --all-files
```

### Julia Issues

**"Package not found"**
```bash
# Reinstall dependencies
julia --project=. -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'
```

**Tests fail**
```bash
# Update dependencies
julia --project=. -e 'using Pkg; Pkg.update()'
```

### Git Issues

**Wrong branch**
```bash
# Switch to main branch
git checkout main
```

**Uncommitted changes**
```bash
# See what changed
git status

# Discard changes
git restore <file>

# Or stash for later
git stash
```

## Getting Help

- **Issues**: [GitHub Issues](https://github.com/femtotrader/OnlineStatsChains.jl/issues)
- **Discussions**: [GitHub Discussions](https://github.com/femtotrader/OnlineStatsChains.jl/discussions)
- **Documentation**: [Online Docs](https://femtotrader.github.io/OnlineStatsChains.jl/)

## Next Steps

1. Read [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines
2. Check open issues for tasks to work on
3. Read the [documentation](docs/src/index.md)
4. Run examples from [docs/src/examples.md](docs/src/examples.md)

Happy coding! 🎉
