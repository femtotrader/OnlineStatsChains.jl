# Examples

Real-world examples demonstrating OnlineStatsChains.jl.

## Financial Time Series Analysis

Track multiple technical indicators:

```julia
using OnlineStatsChains
using OnlineStatsBase

function create_trading_dag()
    dag = StatDAG()

    # Price input
    add_node!(dag, :price, Mean())

    # Technical indicators
    add_node!(dag, :sma_5, Mean())
    add_node!(dag, :sma_20, Mean())
    add_node!(dag, :volatility, Variance())
    add_node!(dag, :range, Extrema())

    # Build pipeline
    connect!(dag, :price, :sma_5)
    connect!(dag, :price, :sma_20)
    connect!(dag, :price, :volatility)
    connect!(dag, :price, :range)

    return dag
end

# Use the DAG
dag = create_trading_dag()

# Stream price data
prices = [100.0, 102.0, 101.0, 103.0, 105.0, 104.0, 106.0, 108.0]
fit!(dag, :price => prices)

# Get indicators
println("Price: ", value(dag, :price))
println("SMA(5): ", value(dag, :sma_5))
println("SMA(20): ", value(dag, :sma_20))
println("Volatility: ", value(dag, :volatility))
println("Range: ", value(dag, :range))
```

## Sensor Network Monitoring

Multi-sensor aggregation:

```julia
using OnlineStatsChains
using OnlineStatsBase

function create_sensor_network()
    dag = StatDAG()

    # Individual sensors
    add_node!(dag, :temp_1, Mean())
    add_node!(dag, :temp_2, Mean())
    add_node!(dag, :temp_3, Mean())

    # Zone aggregates
    add_node!(dag, :zone_avg, Mean())
    add_node!(dag, :zone_var, Variance())

    # Building-level stats
    add_node!(dag, :building, Mean())

    # Connect sensors to zones
    connect!(dag, [:temp_1, :temp_2, :temp_3], :zone_avg)
    connect!(dag, [:temp_1, :temp_2, :temp_3], :zone_var)

    # Connect to building
    connect!(dag, :zone_avg, :building)

    return dag
end

# Monitor sensors
dag = create_sensor_network()

# Update sensors (different sample sizes)
fit!(dag, Dict(
    :temp_1 => [20.1, 20.3, 20.2],
    :temp_2 => [19.8, 20.0, 19.9],
    :temp_3 => [20.5, 20.7]
))

println("Zone average: ", value(dag, :zone_avg))
println("Zone variance: ", value(dag, :zone_var))
println("Building temp: ", value(dag, :building))
```

## Streaming Data Pipeline

Process real-time data with lazy evaluation:

```julia
using OnlineStatsChains
using OnlineStatsBase

function create_streaming_pipeline()
    # Use lazy for efficiency
    dag = StatDAG(strategy=:lazy)

    # Raw data input
    add_node!(dag, :raw, Mean())

    # Processing stages
    add_node!(dag, :filtered, Mean())
    add_node!(dag, :normalized, Mean())

    # Analytics
    add_node!(dag, :stats, Variance())
    add_node!(dag, :summary, Extrema())

    # Build pipeline
    connect!(dag, :raw, :filtered)
    connect!(dag, :filtered, :normalized)
    connect!(dag, :normalized, :stats)
    connect!(dag, :normalized, :summary)

    return dag
end

# Process stream
dag = create_streaming_pipeline()

# Accumulate data (no propagation in lazy mode)
for batch in data_stream
    fit!(dag, :raw => batch)
end

# Trigger computation when needed
stats_value = value(dag, :stats)
summary_value = value(dag, :summary)
```

## Quality Control System

Multi-stage quality checks:

```julia
using OnlineStatsChains
using OnlineStatsBase

function create_qc_pipeline()
    dag = StatDAG()

    # Measurement inputs
    add_node!(dag, :measurement, Mean())

    # Quality metrics
    add_node!(dag, :mean_check, Mean())
    add_node!(dag, :variance_check, Variance())
    add_node!(dag, :range_check, Extrema())

    # Aggregate QC
    add_node!(dag, :qc_status, Mean())

    # Build pipeline
    connect!(dag, :measurement, :mean_check)
    connect!(dag, :measurement, :variance_check)
    connect!(dag, :measurement, :range_check)
    connect!(dag, [:mean_check, :variance_check, :range_check], :qc_status)

    return dag
end

# Run quality control
dag = create_qc_pipeline()

measurements = [10.1, 10.2, 10.15, 10.3, 10.25]
fit!(dag, :measurement => measurements)

println("Mean: ", value(dag, :mean_check))
println("Variance: ", value(dag, :variance_check))
println("Range: ", value(dag, :range_check))
println("QC Status: ", value(dag, :qc_status))
```

## Real-Time Dashboard

Live statistics update:

```julia
using OnlineStatsChains
using OnlineStatsBase

function create_dashboard()
    dag = StatDAG(strategy=:eager)

    # Data source
    add_node!(dag, :events, Mean())

    # Dashboard panels
    add_node!(dag, :count_panel, Sum())
    add_node!(dag, :avg_panel, Mean())
    add_node!(dag, :var_panel, Variance())
    add_node!(dag, :hist_panel, Hist(10))

    # Connect to all panels
    connect!(dag, :events, :count_panel)
    connect!(dag, :events, :avg_panel)
    connect!(dag, :events, :var_panel)
    connect!(dag, :events, :hist_panel)

    return dag
end

# Update dashboard
dag = create_dashboard()

# Stream events
function update_dashboard(dag, event_value)
    fit!(dag, :events => event_value)

    # Dashboard auto-updates (eager mode)
    return (
        count = value(dag, :count_panel),
        average = value(dag, :avg_panel),
        variance = value(dag, :var_panel),
        histogram = value(dag, :hist_panel)
    )
end

# Simulate events
for event in event_stream
    dashboard_data = update_dashboard(dag, event)
    display_dashboard(dashboard_data)
end
```

## Batch Analytics Pipeline

Process large datasets efficiently:

```julia
using OnlineStatsChains
using OnlineStatsBase

function create_analytics_pipeline()
    dag = StatDAG(strategy=:lazy)

    # Data inputs
    add_node!(dag, :dataset_a, Mean())
    add_node!(dag, :dataset_b, Mean())

    # Derived metrics
    add_node!(dag, :metric_1, Mean())
    add_node!(dag, :metric_2, Variance())

    # Final reports
    add_node!(dag, :report_summary, Mean())

    # Build pipeline
    connect!(dag, :dataset_a, :metric_1)
    connect!(dag, :dataset_b, :metric_1)
    connect!(dag, [:dataset_a, :dataset_b], :metric_2)
    connect!(dag, [:metric_1, :metric_2], :report_summary)

    return dag
end

# Process batch
dag = create_analytics_pipeline()

# Load large datasets
data_a = load_dataset("a.csv")
data_b = load_dataset("b.csv")

# Fit (lazy - no propagation)
fit!(dag, Dict(
    :dataset_a => data_a,
    :dataset_b => data_b
))

# Compute only what's needed
report = value(dag, :report_summary)
```

## Multi-Source Data Fusion

Combine multiple data sources:

```julia
using OnlineStatsChains
using OnlineStatsBase

function create_fusion_pipeline()
    dag = StatDAG()

    # Multiple data sources
    add_node!(dag, :sensor_a, Mean())
    add_node!(dag, :sensor_b, Mean())
    add_node!(dag, :database, Mean())

    # Fusion layers
    add_node!(dag, :fused_sensors, Mean())
    add_node!(dag, :final_estimate, Mean())

    # Build fusion
    connect!(dag, [:sensor_a, :sensor_b], :fused_sensors)
    connect!(dag, [:fused_sensors, :database], :final_estimate)

    return dag
end

# Fuse data
dag = create_fusion_pipeline()

fit!(dag, Dict(
    :sensor_a => [10.1, 10.2],
    :sensor_b => [10.15, 10.25],
    :database => [10.0, 10.1, 10.2]
))

println("Fused estimate: ", value(dag, :final_estimate))
```

## Strategy Switching Example

Dynamic strategy changes:

```julia
using OnlineStatsChains
using OnlineStatsBase

dag = StatDAG(strategy=:eager)

add_node!(dag, :input, Mean())
add_node!(dag, :output, Mean())
connect!(dag, :input, :output)

# Real-time mode (eager)
println("Real-time processing...")
for x in realtime_stream
    fit!(dag, :input => x)
    display(value(dag, :output))
end

# Switch to batch mode (lazy)
println("Switching to batch mode...")
set_strategy!(dag, :lazy)

# Process batch (no propagation)
fit!(dag, :input => batch_data)

# Compute when ready
result = value(dag, :output)
```

## See Also

- [Basic Tutorial](tutorials/basic.md) - Fundamental concepts
- [Advanced Patterns](tutorials/advanced.md) - Complex structures
- [Performance Guide](tutorials/performance.md) - Optimization
- [API Reference](api.md) - Complete documentation
