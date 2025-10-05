# Visualization Examples - Setup Guide

## Quick Setup (3 steps)

### Step 1: Navigate to this directory
```bash
cd examples/viz
```

### Step 2: Start Julia with local environment
```bash
julia --project=.
```

### Step 3: Setup dependencies (first time only)
```julia
using Pkg
Pkg.develop(path="../..")  # Link OnlineStatsChains parent package
Pkg.instantiate()          # Install JSServe, JSON3, Colors
```

### Step 4: Run examples!
```julia
include("run_viewer.jl")  # Browser opens automatically! 🎉
```

## What This Does

The `Project.toml` in this directory:
- ✅ Manages viz-specific dependencies (JSServe, JSON3, Colors)
- ✅ Isolates from main package dependencies
- ✅ Links to parent OnlineStatsChains package via `develop`

## After First Setup

Next time you just need:
```bash
cd examples/viz
julia --project=.
```

```julia
include("run_viewer.jl")
# or any other example...
```

## Troubleshooting

### "OnlineStatsChains not found"
You forgot to link the parent package:
```julia
using Pkg
Pkg.develop(path="../..")
```

### "JSServe not found"
Install dependencies:
```julia
using Pkg
Pkg.instantiate()
```

### Start fresh
Remove Manifest and reinstall:
```julia
rm("Manifest.toml")
using Pkg
Pkg.develop(path="../..")
Pkg.instantiate()
```

## Why This Approach?

**Benefits:**
- ✅ Isolated dependencies per example type
- ✅ No pollution of main package environment
- ✅ Easy to reproduce
- ✅ Others can run examples without affecting their setup
- ✅ Clear what dependencies each example needs

**vs. Main package `--project`:**
- Main package loads ALL test dependencies
- This approach only loads viz dependencies
- Faster, cleaner, more focused

## All Example Files

- `run_viewer.jl` ⭐ Main demo
- `simple_viewer_demo.jl` - Interactive tutorial
- `viewer_basic.jl` - Basic visualization
- `viewer_realtime.jl` - Real-time monitoring
- `viewer_custom_style.jl` - Themes
- `viewer_layouts.jl` - Layout comparison
- `viewer_export.jl` - Export to JSON

See [README.md](README.md) for details on each example.
