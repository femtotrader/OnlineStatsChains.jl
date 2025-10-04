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

## Edge Transformations

### Temperature Conversion

Convert temperature units on-the-fly:

```julia
using OnlineStatsChains
using OnlineStatsBase

dag = StatDAG()

# Sensor outputs in Celsius
add_node!(dag, :celsius, Mean())
add_node!(dag, :fahrenheit, Mean())
add_node!(dag, :kelvin, Mean())

# Convert to different scales
connect!(dag, :celsius, :fahrenheit, transform = c -> c * 9/5 + 32)
connect!(dag, :celsius, :kelvin, transform = c -> c + 273.15)

# Input temperature readings
fit!(dag, :celsius => [0.0, 10.0, 20.0, 30.0, 40.0])

println("Celsius: ", value(dag, :celsius))       # 20.0°C
println("Fahrenheit: ", value(dag, :fahrenheit)) # 68.0°F
println("Kelvin: ", value(dag, :kelvin))         # 293.15K
```

### Data Cleaning Pipeline

Filter and transform data:

```julia
using OnlineStatsChains
using OnlineStatsBase

dag = StatDAG()

add_node!(dag, :raw_sensor, Mean())
add_node!(dag, :valid_only, Mean())
add_node!(dag, :calibrated, Mean())

# Filter out missing values
connect!(dag, :raw_sensor, :valid_only, filter = !ismissing)

# Apply calibration after filtering
connect!(dag, :valid_only, :calibrated, transform = x -> x * 1.05 + 0.5)

# Input with some missing values
fit!(dag, :raw_sensor => [10.0, missing, 15.0, missing, 20.0])

println("Valid readings: ", value(dag, :valid_only))    # 15.0
println("Calibrated: ", value(dag, :calibrated))        # 16.25
```

### E-Commerce Analytics

Extract metrics from transaction data:

```julia
using OnlineStatsChains
using OnlineStatsBase

# Transaction structure
struct Transaction
    price::Float64
    quantity::Int
    discount::Float64
end

dag = StatDAG()

add_node!(dag, :transactions, Mean())
add_node!(dag, :avg_price, Mean())
add_node!(dag, :avg_quantity, Mean())
add_node!(dag, :total_revenue, Mean())

# Extract different metrics
connect!(dag, :transactions, :avg_price, 
         transform = t -> t.price)

connect!(dag, :transactions, :avg_quantity, 
         transform = t -> Float64(t.quantity))

connect!(dag, :transactions, :total_revenue, 
         transform = t -> t.price * t.quantity * (1 - t.discount))

# Process transactions
transactions = [
    Transaction(100.0, 2, 0.1),
    Transaction(150.0, 1, 0.0),
    Transaction(75.0, 3, 0.2)
]

fit!(dag, :transactions => transactions)

println("Average price: ", value(dag, :avg_price))
println("Average quantity: ", value(dag, :avg_quantity))
println("Average revenue: ", value(dag, :total_revenue))
```

### Conditional Routing with Transforms

Route data based on conditions:

```julia
using OnlineStatsChains
using OnlineStatsBase

dag = StatDAG()

add_node!(dag, :temperature, Mean())
add_node!(dag, :high_alert, Mean())
add_node!(dag, :normal, Mean())
add_node!(dag, :low_alert, Mean())

# High temperature alert (>30°C) - convert to Fahrenheit
connect!(dag, :temperature, :high_alert,
         filter = t -> t > 30,
         transform = t -> t * 9/5 + 32)

# Normal range (10-30°C) - keep as is
connect!(dag, :temperature, :normal,
         filter = t -> 10 <= t <= 30)

# Low temperature alert (<10°C) - flag with negative
connect!(dag, :temperature, :low_alert,
         filter = t -> t < 10,
         transform = t -> -t)

# Stream temperature data
fit!(dag, :temperature => [5.0, 15.0, 25.0, 35.0, 8.0, 32.0])

println("High alerts (°F): ", value(dag, :high_alert))  # Avg of 95°F, 89.6°F
println("Normal temps: ", value(dag, :normal))          # Avg of 15, 25
println("Low alerts: ", value(dag, :low_alert))         # Avg of -5, -8
```

### Multi-Input Feature Engineering

Combine multiple inputs with transformations:

```julia
using OnlineStatsChains
using OnlineStatsBase

dag = StatDAG()

add_node!(dag, :price, Mean())
add_node!(dag, :volume, Mean())
add_node!(dag, :momentum, Mean())

# Calculate momentum: price * volume
connect!(dag, [:price, :volume], :momentum,
         transform = inputs -> inputs[1] * inputs[2])

# Update with coordinated data
fit!(dag, Dict(
    :price => [100.0, 105.0, 103.0],
    :volume => [1000.0, 1200.0, 900.0]
))

println("Average price: ", value(dag, :price))
println("Average volume: ", value(dag, :volume))
println("Average momentum: ", value(dag, :momentum))
```

### Log Transform Pipeline

Apply logarithmic transformations:

```julia
using OnlineStatsChains
using OnlineStatsBase

dag = StatDAG()

add_node!(dag, :population, Mean())
add_node!(dag, :log_population, Mean())
add_node!(dag, :growth_rate, Mean())

# Log transform
connect!(dag, :population, :log_population,
         transform = p -> log10(p))

# Calculate growth rate (only for positive changes)
connect!(dag, :log_population, :growth_rate,
         filter = x -> x > 0)

# Population data
fit!(dag, :population => [1000.0, 1100.0, 1210.0, 1331.0])

println("Mean population: ", value(dag, :population))
println("Mean log(pop): ", value(dag, :log_population))
println("Growth rate: ", value(dag, :growth_rate))
```

## See Also

- [Basic Tutorial](tutorials/basic.md) - Fundamental concepts
- [Advanced Patterns](tutorials/advanced.md) - Complex structures
- [Performance Guide](tutorials/performance.md) - Optimization
- [API Reference](api.md) - Complete documentation
