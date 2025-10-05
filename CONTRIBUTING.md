# Contributing to OnlineStatsChains.jl

Thank you for considering contributing to OnlineStatsChains.jl! This document provides guidelines for contributing to the project.

## Development Setup

### Prerequisites

- Julia 1.10 or later
- Git
- Python 3.7+ (for pre-commit hooks)

### Initial Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/femtotrader/OnlineStatsChains.jl.git
   cd OnlineStatsChains.jl
   ```

2. Install Julia dependencies:
   ```bash
   julia --project=. -e 'using Pkg; Pkg.instantiate()'
   ```

3. Install pre-commit hooks:
   ```bash
   pip install pre-commit
   pre-commit install
   pre-commit install --hook-type commit-msg
   ```

## Pre-commit Hooks

This project uses [pre-commit](https://pre-commit.com/) to ensure code quality and consistency.

### What the hooks do

The pre-commit hooks automatically:
- ✅ Validate conventional commit message format
- ✅ Remove trailing whitespace
- ✅ Ensure files end with a newline
- ✅ Check YAML and TOML files are valid
- ✅ Prevent large files (>5MB) from being committed
- ✅ Check for merge conflict markers

### Running hooks manually

```bash
# Run all hooks on all files
pre-commit run --all-files

# Run specific hook
pre-commit run trailing-whitespace --all-files

# Skip hooks for a commit (not recommended)
git commit --no-verify -m "your message"
```

### Updating hooks

```bash
pre-commit autoupdate
```

## Commit Message Guidelines

This project follows [Conventional Commits](https://www.conventionalcommits.org/) specification.

### Commit Message Format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Code style changes (formatting, missing semi-colons, etc.)
- `refactor`: Code refactoring without changing functionality
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `build`: Changes to build system or dependencies
- `ci`: Changes to CI configuration
- `chore`: Other changes that don't modify src or test files
- `revert`: Reverts a previous commit

### Examples

Good commit messages:
```
feat: add lazy evaluation strategy for large DAGs
fix: correct topological ordering for diamond patterns
docs: add tutorial for multi-input nodes
test: add integration tests for OnlineStats.jl
perf: optimize propagation for sparse updates
```

With scope:
```
feat(dag): add cycle detection with detailed error messages
fix(api): correct value() behavior in lazy mode
docs(tutorial): add performance optimization examples
```

Breaking changes:
```
feat!: change StatDAG constructor signature

BREAKING CHANGE: StatDAG() now requires explicit strategy parameter
```

## Code Style

- Follow [Julia Style Guide](https://docs.julialang.org/en/v1/manual/style-guide/)
- Use 4 spaces for indentation
- Maximum line length: 92 characters (soft limit, 120 hard limit)
- Use descriptive variable and function names
- Add docstrings to all exported functions

## Testing

Run tests before submitting:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

For specific tests:
```bash
julia --project=. test/runtests.jl
```

### Test Requirements

- All new features must include tests
- Aim for >90% code coverage
- Tests should follow BDD style (Given-When-Then)
- Use descriptive test names

## Documentation

Update documentation when:
- Adding new features
- Changing public API
- Fixing bugs that were undocumented behavior

Build documentation locally:
```bash
cd docs
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=. make.jl
```

## Continuous Integration (CI)

This project uses GitHub Actions for automated testing and deployment.

### CI Workflows

#### Tests (CI.yml)
- Runs on every push and pull request
- Tests Julia versions: 1.10, 1.11, nightly
- Tests on: Ubuntu, macOS, Windows
- Uploads coverage to Codecov

#### Documentation (Documentation.yml)
- Builds documentation on every push
- Deploys to GitHub Pages on main branch
- Verifies all examples work

#### TagBot (TagBot.yml)
- Automatically creates GitHub releases
- Triggered by Julia Registry updates
- Generates changelog from commits

#### CompatHelper (CompatHelper.yml)
- Daily checks for dependency updates
- Automatically creates PRs for updates

### CI Status

Check CI status on your PR:
- All tests must pass before merge
- Documentation must build successfully
- Coverage should not significantly decrease

View CI results:
- Click "Details" next to each check
- Review logs for any failures
- Fix issues and push updates

## Pull Request Process

1. **Fork and Branch**: Create a feature branch from `main`
   ```bash
   git checkout -b feat/my-new-feature
   ```

2. **Commit**: Use conventional commits
   ```bash
   git commit -m "feat: add my new feature"
   ```

3. **Test Locally**: Ensure all tests pass
   ```bash
   julia --project=. -e 'using Pkg; Pkg.test()'
   ```

4. **Push**: Push to your fork
   ```bash
   git push origin feat/my-new-feature
   ```

5. **PR**: Open a pull request with:
   - Clear description of changes
   - Link to related issues
   - Screenshots/examples if applicable

6. **CI Checks**: Wait for CI to complete
   - ✅ All tests must pass
   - ✅ Documentation must build
   - ✅ No significant coverage decrease

7. **Review**: Address review feedback
   - Respond to comments
   - Make requested changes
   - Push updates (CI will re-run)

## AI-Generated Code Notice

This package was initially generated using AI (Claude Code). When contributing:

- Review AI-generated code carefully
- Add tests for edge cases
- Document any assumptions or limitations
- Report issues you find

## Code Review

- Be respectful and constructive
- Focus on code quality and functionality
- Suggest improvements with examples
- Approve when satisfied

## Questions?

- Open an issue for bugs or feature requests
- Use discussions for questions
- Check existing issues before creating new ones

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing! 🎉
