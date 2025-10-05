# OnlineStatsChains.jl Extension Specifications Overview

This document provides a high-level overview of the two planned package extensions for OnlineStatsChains.jl: **Rocket.jl Integration** and **Viewer Extension**.

---

## Package Extensions Architecture

Both extensions use Julia's **package extension system** (available in Julia 1.9+, natively supported in our minimum version 1.10 LTS). This ensures:

✅ **Zero core dependencies**: Extensions don't add weight to the base package
✅ **Automatic activation**: Extensions load when users install optional dependencies
✅ **Clean separation**: Extension code lives in `ext/` directory
✅ **Weak dependencies**: Listed in `[weakdeps]` in Project.toml

---

## Extension 1: Rocket.jl Integration

**Status:** Implemented ✅
**Specification:** [rocket_integration.md](rocket_integration.md)
**Version:** 0.1.0

### Purpose
Enable reactive programming capabilities by integrating OnlineStatsChains with Rocket.jl, allowing StatDAGs to consume and produce reactive data streams.

### Key Features
- **StatDAGActor**: Feed Observable streams into DAG nodes
- **StatDAGObservable**: Convert DAG nodes into Observables
- **Bidirectional pipelines**: Observable → DAG → Observable
- **Real-time processing**: React to data streams as they arrive

### Dependencies (Weak)
- `Rocket` (for reactive programming)

### Activation
```julia
using OnlineStatsChains
using Rocket  # Activates the extension
```

### Use Cases
- Real-time sensor data processing
- Event-driven architectures
- Asynchronous data sources
- Time-series streaming analytics
- Financial market data feeds

### Example
```julia
# Create DAG
dag = StatDAG()
add_node!(dag, :prices, Mean())
add_node!(dag, :variance, Variance())
connect!(dag, :prices, :variance)

# Create reactive stream
price_stream = from([100, 102, 101, 103, 105])

# Feed stream into DAG
actor = StatDAGActor(dag, :prices)
subscribe!(price_stream, actor)

# Get result as observable
variance_obs = to_observable(dag, :variance)
subscribe!(variance_obs, logger())
```

---

## Extension 2: Viewer Extension (Planned)

**Status:** Specification Complete 📋
**Specification:** [viewer_extension.md](viewer_extension.md)
**Version:** 0.1.0

### Purpose
Provide interactive web-based visualization of StatDAG structures using Cytoscape.js, with support for both static structure inspection and real-time value propagation monitoring.

### Key Features
- **Interactive visualization**: Pan, zoom, click nodes/edges for details
- **Multiple layouts**: Hierarchical, force-directed, circular, grid
- **Real-time monitoring**: Watch values flow through the DAG
- **Node inspection**: See current values, statistics, metadata
- **Edge visualization**: Display filters, transformers, data flow
- **Export capabilities**: Save as PNG, SVG, JSON, GraphML, DOT
- **Customization**: Styles, colors, themes, layouts

### Dependencies (Weak)
- `JSServe` (web server and interactive widgets)
- `JSON3` (JSON serialization)
- `Colors` (node/edge coloring)

### Activation
```julia
using OnlineStatsChains
using JSServe  # Activates the extension
```

### Use Cases
- **Debugging**: Visualize DAG structure to understand data flow
- **Presentations**: Share interactive visualizations
- **Development**: Explore complex DAGs during design
- **Monitoring**: Watch real-time data propagation
- **Documentation**: Export diagrams for reports
- **Teaching**: Demonstrate online statistics concepts

### Planned API
```julia
# Static visualization (uses Base.display with type dispatch)
display(dag)

# Real-time visualization with custom layout
display(dag, realtime=true, layout=:force, theme=:dark)

# Feed data and watch it flow
for x in randn(100)
    fit!(dag, :source => x)
    sleep(0.05)  # Slow down to see animation
end

# Export to file
export_dag(dag, "my_dag.png", format=:png)
export_dag(dag, "my_dag.json", format=:json)

# Customize appearance
set_node_style!(dag, :source, color="green", size=50)
set_edge_style!(dag, :source, :ema, style=:dashed)
```

### Technology Stack
- **Frontend**: Cytoscape.js (JavaScript graph library)
- **Backend**: JSServe.jl (Julia web server)
- **Communication**: WebSocket (real-time updates)
- **Format**: JSON (data serialization)

---

## Comparison Table

| Feature | Rocket.jl Integration | Viewer Extension |
|---------|----------------------|------------------|
| **Status** | ✅ Implemented | 📋 Specified |
| **Purpose** | Reactive programming | Visualization |
| **Direction** | Data flow | Visual inspection |
| **Mode** | Runtime | Development/Debug |
| **Dependencies** | Rocket | JSServe, JSON3, Colors |
| **Output** | Data streams | Web UI |
| **Use case** | Production systems | Analysis/Debugging |
| **Complexity** | Medium | High |
| **Performance impact** | Minimal | GUI overhead |

---

## When to Use Which Extension

### Use Rocket.jl Integration When:
✅ You have real-time streaming data sources
✅ You need asynchronous, event-driven processing
✅ You want to integrate with other reactive systems
✅ Your application uses Observable patterns
✅ You need backpressure and flow control

### Use Viewer Extension When:
✅ You want to understand your DAG structure
✅ You need to debug value propagation
✅ You're presenting/documenting your work
✅ You want to explore different layouts
✅ You need to monitor real-time updates visually
✅ You're teaching/learning online statistics

### Use Both When:
🎯 Building a reactive system and need to monitor it
🎯 Developing complex DAGs and want real-time feedback
🎯 Creating demonstrations or educational materials

---

## Implementation Status

### Rocket.jl Integration
- [x] Specification complete
- [x] Implementation complete
- [x] Tests complete
- [x] Documentation complete
- [x] Examples complete
- [x] CI/CD configured

### Viewer Extension
- [x] Specification complete
- [ ] Implementation (planned for future version)
- [ ] Tests (planned)
- [ ] Documentation (planned)
- [ ] Examples (planned)
- [ ] CI/CD (planned)

---

## Development Roadmap

### Viewer Extension Implementation Phases

**Phase 1: Core Functionality (v0.1.0)**
- Basic `view_dag()` function
- Cytoscape.js integration
- Static visualization
- JSON serialization
- Basic layouts (hierarchical, force-directed)

**Phase 2: Real-time Updates (v0.2.0)**
- WebSocket communication
- Real-time update mechanism
- Data flow animation
- Play/pause controls

**Phase 3: Customization (v0.3.0)**
- Node/edge styling API
- Theme support
- Custom layouts
- Layout persistence

**Phase 4: Export and Polish (v0.4.0)**
- Export to various formats
- Screenshot/image export
- Performance optimizations
- Accessibility improvements

---

## Contributing

If you're interested in implementing the Viewer Extension:

1. Read the detailed specification: [viewer_extension.md](viewer_extension.md)
2. Check the main project guidelines: [CONTRIBUTING.md](../CONTRIBUTING.md)
3. Open an issue to discuss your approach
4. Start with Phase 1 (Core Functionality)
5. Follow the testing and documentation requirements

---

## Architecture Benefits

Both extensions demonstrate best practices for Julia package design:

### 🎯 Modularity
Core package remains lightweight, extensions add features on demand

### 🔌 Plug-and-Play
Just install the dependencies, extensions activate automatically

### 🧪 Testability
Extensions have independent test suites that run conditionally

### 📚 Documentation
Each extension has dedicated documentation with examples

### 🔄 Maintainability
Clear separation of concerns, easier to maintain and update

### 🚀 Performance
No overhead unless extension is actually loaded and used

---

## Questions?

For questions about:
- **Rocket.jl Integration**: See [rocket_integration.md](rocket_integration.md) or check examples in `examples/reactive_demo.jl`
- **Viewer Extension**: See [viewer_extension.md](viewer_extension.md) or open an issue
- **General package**: See [specs.md](specs.md) or main [README](../README.md)

---

**Last Updated:** 2025-10-05
**Maintained By:** OnlineStatsChains.jl contributors
