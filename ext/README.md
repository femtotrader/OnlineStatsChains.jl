# Package Extensions

This directory contains package extensions for OnlineStatsChains.jl using Julia's package extension system (Julia 1.9+).

## What are Package Extensions?

Package extensions allow optional integration with other packages without adding them as required dependencies. The extension code only loads when the user explicitly installs and imports the target package.

## Available Extensions

### OnlineStatsChainsRocketExt

**Status:** ✅ Implemented
**Target Package:** [Rocket.jl](https://github.com/biaslab/Rocket.jl)
**Purpose:** Reactive programming integration

Provides seamless integration with Rocket.jl for reactive programming capabilities:

- `StatDAGActor`: Feed Rocket.jl Observables into DAG nodes
- `StatDAGObservable`: Convert DAG nodes into Observables
- `to_observable()`: Create Observables from DAG nodes
- `to_observables()`: Create multiple Observables
- `observable_through_dag()`: Build reactive pipelines

**Usage:**
```julia
using OnlineStatsChains
using Rocket  # Activates the extension

dag = StatDAG()
add_node!(dag, :prices, Mean())

# Feed observable into DAG
prices = from([100, 102, 101, 103])
actor = StatDAGActor(dag, :prices)
subscribe!(prices, actor)
```

**Documentation:** See [docs/src/rocket_integration.md](../docs/src/rocket_integration.md)
**Tests:** See [test/test_rocket_integration.jl](../test/test_rocket_integration.jl)
**Specification:** See [specs/rocket_integration.md](../specs/rocket_integration.md)

## How Extensions Work

1. **Declaration** in `Project.toml`:
   ```toml
   [weakdeps]
   Rocket = "df971d30-c9d6-4b37-b8ff-e965b2cb3a40"

   [extensions]
   OnlineStatsChainsRocketExt = "Rocket"
   ```

2. **Implementation** in `ext/OnlineStatsChainsRocketExt.jl`:
   - Extension module that loads only when both packages are available
   - Implements integration code using APIs from both packages
   - Exports additional functions/types available when extension is loaded

3. **Activation**:
   ```julia
   using OnlineStatsChains
   using Rocket  # Extension auto-loads
   ```

4. **Testing**:
   - Tests check if extension is loaded before running
   - Separate CI job tests with extension package installed
   - Core tests run without extension packages

## Adding New Extensions

To add a new extension:

1. **Update Project.toml**:
   ```toml
   [weakdeps]
   NewPackage = "uuid-here"

   [extensions]
   OnlineStatsChainsNewPackageExt = "NewPackage"
   ```

2. **Create extension module** `ext/OnlineStatsChainsNewPackageExt.jl`:
   ```julia
   module OnlineStatsChainsNewPackageExt

   using OnlineStatsChains
   using NewPackage

   # Implementation here...

   end
   ```

3. **Add tests** in `test/test_newpackage_integration.jl`

4. **Add CI job** in `.github/workflows/CI.yml`

5. **Document** in `docs/src/newpackage_integration.md`

6. **Specify** in `specs/newpackage_integration.md`

## Requirements

- Julia 1.10+ (LTS version)
- Package extensions are natively supported
- No need for Requires.jl or conditional loading

## References

- [Julia Package Extensions Documentation](https://pkgdocs.julialang.org/v1/creating-packages/#Conditional-loading-of-code-in-packages-(Extensions))
- [OnlineStatsChains.jl Documentation](../docs/)
- [Specifications](../specs/)
