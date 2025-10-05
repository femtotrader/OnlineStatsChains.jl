# Layout Comparison Example
# Demonstrates different layout algorithms for the same DAG

using OnlineStatsChains
using OnlineStats
using JSServe, JSON3, Colors, NanoDates

println("Creating a complex DAG for layout comparison...")

# Create a more complex DAG structure (diamond with extensions)
dag = StatDAG()

# Create nodes
add_node!(dag, :source, Mean())
add_node!(dag, :branch_a, Mean())
add_node!(dag, :branch_b, Mean())
add_node!(dag, :branch_c, Mean())
add_node!(dag, :merge_ab, Mean())
add_node!(dag, :merge_bc, Mean())
add_node!(dag, :final, Mean())

# Create diamond-like structure
connect!(dag, :source, :branch_a)
connect!(dag, :source, :branch_b)
connect!(dag, :source, :branch_c)
connect!(dag, :branch_a, :merge_ab)
connect!(dag, :branch_b, :merge_ab)
connect!(dag, :branch_b, :merge_bc)
connect!(dag, :branch_c, :merge_bc)
connect!(dag, :merge_ab, :final)
connect!(dag, :merge_bc, :final)

# Feed some data
println("Feeding data...")
fit!(dag, :source => randn(100))

println("\nDAG structure:")
println("  Nodes: ", length(dag.nodes))
println("  Edges: ", length(dag.edges))
println("  Pattern: Source → 3 branches → 2 merges → final")

println("\n" * "="^60)
println("Opening FOUR visualizations with different layouts...")
println("="^60)
println("\nThis will open 4 browser windows on different ports.")
println("Compare how each layout organizes the same DAG!\n")

# Layout 1: Hierarchical (breadthfirst)
println("1. HIERARCHICAL layout (port 8080)")
println("   - Tree-like structure")
println("   - Source at top, flows downward")
println("   - Best for: Clear parent-child relationships")
viewer1 = display(dag,
                 layout=:hierarchical,
                 port=8080,
                 theme=:light,
                 title="Layout Comparison: Hierarchical")
sleep(1)

# Layout 2: Force-directed (cose)
println("\n2. FORCE-DIRECTED layout (port 8081)")
println("   - Physics-based positioning")
println("   - Automatic spacing")
println("   - Best for: Natural clustering")
viewer2 = display(dag,
                 layout=:force,
                 port=8081,
                 theme=:light,
                 title="Layout Comparison: Force-Directed")
sleep(1)

# Layout 3: Circular
println("\n3. CIRCULAR layout (port 8082)")
println("   - Nodes around a circle")
println("   - Shows connectivity patterns")
println("   - Best for: Small to medium graphs")
viewer3 = display(dag,
                 layout=:circular,
                 port=8082,
                 theme=:dark,
                 title="Layout Comparison: Circular")
sleep(1)

# Layout 4: Grid
println("\n4. GRID layout (port 8083)")
println("   - Uniform grid arrangement")
println("   - Predictable positions")
println("   - Best for: Regular structures")
viewer4 = display(dag,
                 layout=:grid,
                 port=8083,
                 theme=:dark,
                 title="Layout Comparison: Grid")

println("\n" * "="^60)
println("All layouts are ready!")
println("="^60)

println("\nOpen these URLs to compare:")
println("  1. Hierarchical: http://127.0.0.1:8080")
println("  2. Force:        http://127.0.0.1:8081")
println("  3. Circular:     http://127.0.0.1:8082")
println("  4. Grid:         http://127.0.0.1:8083")

println("\nComparison tips:")
println("  - Which layout makes the structure clearest?")
println("  - How does each handle the merge nodes?")
println("  - Try the 'Fit to Screen' button in each")
println("  - Notice how edges cross differently in each layout")

println("\nRecommendations:")
println("  - Hierarchical: Best for this DAG (clear flow)")
println("  - Force: Good for finding natural groupings")
println("  - Circular: Shows all connections clearly")
println("  - Grid: Less optimal for this structure")

println("\nPress Ctrl+C to close all viewers.")

try
    while true
        sleep(1)
    end
catch e
    println("\nShutting down all viewers...")
end
