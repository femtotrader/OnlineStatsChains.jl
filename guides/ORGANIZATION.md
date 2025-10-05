# OnlineStatsChains - Project Organization

## 📁 Directory Structure

```
OnlineStatsChains/
│
├── src/                          # Core package source code
│   ├── OnlineStatsChains.jl     # Main module
│   ├── types.jl                  # StatDAG, Node, Edge types
│   ├── dag_algorithms.jl         # Graph algorithms (cycle detection, etc.)
│   ├── propagation.jl            # Value propagation logic
│   ├── fit.jl                    # fit! implementations
│   └── utilities.jl              # Helper functions, observers
│
├── ext/                          # Package extensions (Julia 1.10+)
│   ├── OnlineStatsChainsRocketExt.jl   # Rocket.jl integration
│   └── OnlineStatsChainsViewerExt.jl   # Visualization extension
│
├── test/                         # Test suite
│   ├── runtests.jl              # Main test runner
│   ├── test_*.jl                # @testitem tests (TestItemRunner)
│   ├── test_rocket_integration.jl     # Classic @testset (weakdeps)
│   ├── test_viewer_extension.jl       # Classic @testset (weakdeps)
│   └── test_aqua.jl             # Quality assurance tests
│
├── examples/                     # Usage examples
│   ├── README.md                # Examples index
│   ├── viz/                     # 🎨 Visualization examples
│   │   ├── README.md           # Detailed viz guide
│   │   ├── run_viewer.jl       # ⭐ Main demo
│   │   ├── simple_viewer_demo.jl  # Interactive tutorial
│   │   ├── viewer_basic.jl
│   │   ├── viewer_realtime.jl
│   │   ├── viewer_custom_style.jl
│   │   ├── viewer_layouts.jl
│   │   └── viewer_export.jl
│   ├── filtered_edges_demo.jl   # Edge filtering
│   ├── reactive_demo.jl         # Rocket.jl integration
│   ├── thread_safety_demo.jl    # Concurrent updates
│   └── unsubscribe_demo.jl      # Observable cleanup
│
├── docs/                         # Documentation (Documenter.jl)
│   ├── make.jl
│   └── src/
│       ├── index.md
│       ├── quickstart.md
│       ├── api.md
│       ├── visualization.md      # 🎨 Viewer guide
│       ├── rocket_integration.md
│       ├── examples.md
│       ├── ai-generated.md
│       ├── installation.md
│       └── tutorials/
│           ├── basic.md
│           ├── advanced.md
│           └── performance.md
│
├── specs/                        # Detailed specifications (EARS format)
│   ├── README.md
│   ├── specs.md                 # Core specification
│   ├── viewer_extension.md      # 🎨 Viewer spec
│   ├── rocket_integration.md
│   └── EXTENSIONS_OVERVIEW.md
│
├── guides/                       # Quick reference guides
│   └── VIEWER_QUICKSTART.md     # 🎨 Viewer quick start
│
├── Project.toml                  # Package manifest
├── install_viewer.jl            # One-time setup script
└── README.md                     # Main package README

```

## 🎨 Visualization Extension

### Location
- **Extension code:** `ext/OnlineStatsChainsViewerExt.jl`
- **Examples:** `examples/viz/`
- **Documentation:** `docs/src/visualization.md`
- **Specification:** `specs/viewer_extension.md`
- **Quick start:** `guides/VIEWER_QUICKSTART.md`

### Dependencies (weak)
- JSServe - Web server
- JSON3 - JSON serialization
- Colors - Color handling

### Quick Start
```julia
# Install dependencies (one-time)
include("install_viewer.jl")

# Run demo (after restart)
include("examples/viz/run_viewer.jl")
```

## 🔄 Rocket.jl Extension

### Location
- **Extension code:** `ext/OnlineStatsChainsRocketExt.jl`
- **Examples:** `examples/reactive_demo.jl`, `examples/unsubscribe_demo.jl`
- **Documentation:** `docs/src/rocket_integration.md`
- **Tests:** `test/test_rocket_integration.jl`

### Dependencies (weak)
- Rocket - Reactive programming

## 📦 Package Extensions System

OnlineStatsChains uses Julia 1.10+ package extensions for optional features:

**Core (always available):**
- DAG construction and management
- Value propagation
- Edge filters and transformers
- Evaluation strategies

**Extensions (require additional packages):**
- **Viewer:** Interactive web visualization (JSServe, JSON3, Colors)
- **Rocket:** Reactive programming integration (Rocket.jl)

**Why extensions?**
- Zero dependencies for core functionality
- Optional features don't bloat the package
- Install only what you need

## 🧪 Testing Strategy

### Test Types

1. **@testitem tests** (TestItemRunner)
   - Core functionality
   - Located in `test/test_*.jl`
   - Run in parallel

2. **Classic @testset tests**
   - Extensions with weakdeps
   - `test_rocket_integration.jl`
   - `test_viewer_extension.jl`
   - Conditionally included

3. **Quality assurance**
   - `test_aqua.jl` - Aqua.jl checks
   - Ensures package quality

### Running Tests
```julia
using Pkg
Pkg.test("OnlineStatsChains")
```

## 📚 Documentation Structure

### For Users
1. **README.md** - Quick overview
2. **guides/VIEWER_QUICKSTART.md** - Get started fast
3. **docs/src/** - Complete documentation
4. **examples/** - Practical code examples

### For Developers
1. **specs/** - Detailed specifications (EARS format)
2. **src/** - Well-commented source code
3. **test/** - Test suite examples

## 🎯 Key Files

### Setup & Installation
- `Project.toml` - Package configuration
- `install_viewer.jl` - Viewer setup script

### Main Entry Points
- `src/OnlineStatsChains.jl` - Main module
- `examples/viz/run_viewer.jl` - Visualization demo
- `examples/reactive_demo.jl` - Reactive demo

### Documentation
- `docs/src/visualization.md` - Viewer guide
- `examples/viz/README.md` - Viz examples
- `guides/VIEWER_QUICKSTART.md` - Quick start

## 🔧 Development Workflow

### Adding Features
1. **Core features** → `src/`
2. **Extensions** → `ext/`
3. **Tests** → `test/`
4. **Examples** → `examples/` or `examples/viz/`
5. **Docs** → `docs/src/`
6. **Specs** → `specs/`

### Adding Visualization Examples
1. Create file in `examples/viz/`
2. Update `examples/viz/README.md`
3. Test with `include("examples/viz/your_example.jl")`
4. Consider adding to `guides/VIEWER_QUICKSTART.md`

## 📖 Documentation Hierarchy

```
README.md                          # Package overview
├── guides/VIEWER_QUICKSTART.md   # Quick start
├── examples/README.md            # Examples index
│   └── examples/viz/README.md    # Viz examples
├── docs/src/                     # Full documentation
│   ├── index.md
│   ├── quickstart.md
│   ├── visualization.md          # Detailed viz guide
│   └── ...
└── specs/                        # Technical specs
    ├── specs.md                  # Core spec
    └── viewer_extension.md       # Viz spec
```

## 🎨 Visualization File Map

```
Viewer Extension Files:

Implementation:
  ext/OnlineStatsChainsViewerExt.jl   (~600 lines)

Tests:
  test/test_viewer_extension.jl        (~300 lines)

Examples:
  examples/viz/run_viewer.jl           (main demo)
  examples/viz/simple_viewer_demo.jl   (tutorial)
  examples/viz/viewer_basic.jl
  examples/viz/viewer_realtime.jl
  examples/viz/viewer_custom_style.jl
  examples/viz/viewer_layouts.jl
  examples/viz/viewer_export.jl

Documentation:
  docs/src/visualization.md            (user guide)
  examples/viz/README.md               (examples guide)
  guides/VIEWER_QUICKSTART.md          (quick start)
  specs/viewer_extension.md            (specification)

Setup:
  install_viewer.jl                    (installer)
```

## 🚀 Quick Commands

```julia
# Setup
include("install_viewer.jl")          # Install viewer deps

# Visualization
include("examples/viz/run_viewer.jl") # Main demo

# Reactive
include("examples/reactive_demo.jl")  # Rocket demo

# Tests
using Pkg; Pkg.test()                 # All tests

# Docs
include("docs/make.jl")               # Build docs
```

## 📋 Best Practices

### File Organization
- ✅ Core code in `src/`
- ✅ Extensions in `ext/`
- ✅ Visualization examples in `examples/viz/`
- ✅ General examples in `examples/`
- ✅ Documentation in `docs/src/`

### Naming Conventions
- **Extensions:** `OnlineStatsChains[Feature]Ext.jl`
- **Tests:** `test_[feature].jl`
- **Examples:** `[feature]_demo.jl` or `viewer_[aspect].jl`
- **Docs:** `[feature].md`

### Documentation
- README in each major directory
- Cross-references between docs
- Examples with clear comments
- Specs for detailed requirements

---

**Last updated:** 2025-10-05
**Version:** 0.3.0 (with viewer extension)
