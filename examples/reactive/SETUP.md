# Reactive Examples - Setup Guide

## Quick Setup (3 steps)

### Step 1: Navigate to this directory
```bash
cd examples/reactive
```

### Step 2: Start Julia with local environment
```bash
julia --project=.
```

### Step 3: Setup dependencies (first time only)
```julia
using Pkg
Pkg.develop(path="../..")  # Link OnlineStatsChains parent package
Pkg.instantiate()          # Install Rocket.jl
```

### Step 4: Run examples!
```julia
include("reactive_demo.jl")  # See reactive patterns in action! 🚀
```

## What This Does

The `Project.toml` in this directory:
- ✅ Manages reactive-specific dependencies (Rocket.jl)
- ✅ Isolates from visualization and test dependencies
- ✅ Links to parent OnlineStatsChains package via `develop`

## After First Setup

Next time you just need:
```bash
cd examples/reactive
julia --project=.
```

```julia
include("reactive_demo.jl")
# or any other example...
```

## For Thread Safety Example

The thread safety demo requires multiple threads:
```bash
julia --project=. --threads=4
```

```julia
include("thread_safety_demo.jl")
```

## Troubleshooting

### "OnlineStatsChains not found"
You forgot to link the parent package:
```julia
using Pkg
Pkg.develop(path="../..")
```

### "Rocket not found"
Install dependencies:
```julia
using Pkg
Pkg.instantiate()
```

### Extension not loading
Make sure you import Rocket:
```julia
using Rocket  # This triggers the extension
```

Check if extension loaded:
```julia
Base.get_extension(OnlineStatsChains, :OnlineStatsChainsRocketExt)
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
- ✅ Only loads Rocket.jl (not JSServe, JSON3, Colors)
- ✅ Fast startup for reactive examples
- ✅ Clear separation of concerns
- ✅ Easy to reproduce
- ✅ No dependency conflicts

## All Example Files

- `reactive_demo.jl` ⭐ Main demo - Observable/Actor patterns
- `thread_safety_demo.jl` - Concurrent updates
- `unsubscribe_demo.jl` - Subscription cleanup

See [README.md](README.md) for details on each example.
