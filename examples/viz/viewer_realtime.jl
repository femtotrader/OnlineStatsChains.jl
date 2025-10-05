# Real-time Viewer Example
# Demonstrates real-time visualization with live data updates

using OnlineStatsChains
using OnlineStats
using JSServe, JSON3, Colors, NanoDates

println("Setting up real-time monitoring DAG...")

# Create a DAG for monitoring streaming data
dag = StatDAG()
add_node!(dag, :raw_signal, Mean())
add_node!(dag, :ema_fast, Mean())  # Fast exponential moving average
add_node!(dag, :ema_slow, Mean())  # Slow exponential moving average
add_node!(dag, :variance, Variance())

# Create processing pipeline
connect!(dag, :raw_signal, :ema_fast)
connect!(dag, :raw_signal, :ema_slow)
connect!(dag, :raw_signal, :variance)

println("\nStarting real-time visualization...")
println("This will open a web browser with live updates.")
println("\nWatch for:")
println("  - Nodes flashing orange when updated")
println("  - Values changing in real-time")
println("  - Connection status indicator")
println("\nControls:")
println("  - Click 'Pause' to freeze updates")
println("  - Click 'Resume' to continue")
println("  - Use zoom/pan to explore")

# Enable real-time mode with 10 updates per second
viewer = display(dag,
                realtime=true,
                update_rate=10,
                layout=:force,
                theme=:dark,
                title="Real-time Signal Monitoring")

println("\nFeeding simulated streaming data...")
println("Watch the values update in the visualization!")
println("Press Ctrl+C to stop.\n")

# Simulate a noisy signal
function generate_signal(t)
    # Base signal: 100 + slow sine wave
    base = 100 + 10 * sin(t / 10)
    # Add noise
    noise = randn() * 2
    return base + noise
end

try
    t = 0
    while true
        # Generate and feed new data point
        signal = generate_signal(t)
        fit!(dag, :raw_signal => signal)

        # Print current values every 10 iterations
        if t % 10 == 0
            println("t=$t: Signal=$(round(signal, digits=2)), " *
                   "EMA_fast=$(round(value(dag, :ema_fast), digits=2)), " *
                   "EMA_slow=$(round(value(dag, :ema_slow), digits=2))")
        end

        t += 1
        sleep(0.1)  # 10 Hz update rate
    end
catch e
    if isa(e, InterruptException)
        println("\n\nStopping real-time updates...")
        println("Final values:")
        println("  Raw signal mean: ", value(dag, :raw_signal))
        println("  Fast EMA: ", value(dag, :ema_fast))
        println("  Slow EMA: ", value(dag, :ema_slow))
        println("  Variance: ", value(dag, :variance))
    else
        rethrow(e)
    end
end
