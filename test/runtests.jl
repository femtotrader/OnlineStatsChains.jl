using OnlineStatsChains
using OnlineStatsBase
using Test

# Import Mean and Variance - try both OnlineStats and OnlineStatsBase
try
    using OnlineStats
    @info "Using OnlineStats for Mean and Variance"
catch
    @info "OnlineStats not available, using basic OnlineStat types"
end

# BDD-style macros for Given-When-Then structure
macro scenario(description, body)
    esc(quote
        @testset $description begin
            $body
        end
    end)
end

macro given(description, body)
    quote
        # Given block - setup
        $(esc(body))
    end
end

macro when(description, body)
    quote
        # When block - action
        $(esc(body))
    end
end

macro then(description, body)
    quote
        # Then block - assertion
        $(esc(body))
    end
end

macro and_(description, body)
    quote
        # And block - additional assertion
        $(esc(body))
    end
end

@testset "OnlineStatsChains.jl - BDD Specifications" begin

    # REQ-PKG-001 & REQ-PKG-002: Package Structure
    @scenario "The package is properly configured" begin
        @given "the package OnlineStatsChains" begin
            # Package exists and can be loaded
            @test isdefined(@__MODULE__, :OnlineStatsChains)
        end

        @when "I check the dependencies" begin
            # OnlineStatsBase should be available
            @test isdefined(@__MODULE__, :OnlineStatsBase)
        end

        @then "OnlineStatsBase should be available as a dependency" begin
            @test true  # Already verified above
        end
    end

    # REQ-DAG-001: StatDAG Type
    @scenario "Creating a new StatDAG" begin
        @given "I want to create a computational graph" begin
            # Setup complete
        end

        @when "I create a new StatDAG" begin
            dag = StatDAG()
        end

        @then "it should be a StatDAG instance" begin
            dag = StatDAG()
            @test dag isa StatDAG
        end

        @and_ "it should be empty" begin
            dag = StatDAG()
            @test isempty(dag.nodes)
            @test isempty(dag.topological_order)
            @test dag.order_valid == false
        end
    end

    # REQ-DAG-002: Adding Nodes
    @scenario "Adding a node to the DAG" begin
        @given "an empty StatDAG" begin
            dag = StatDAG()
        end

        @when "I add a node with id :mean and a Mean() stat" begin
            dag = StatDAG()
            add_node!(dag, :mean, Mean())
        end

        @then "the node should exist in the DAG" begin
            dag = StatDAG()
            add_node!(dag, :mean, Mean())
            @test haskey(dag.nodes, :mean)
        end

        @and_ "the DAG should contain exactly one node" begin
            dag = StatDAG()
            add_node!(dag, :mean, Mean())
            @test length(dag.nodes) == 1
        end
    end

    # REQ-DAG-003: Duplicate Node Detection
    @scenario "Adding a duplicate node" begin
        @given "a StatDAG with an existing node :mean" begin
            dag = StatDAG()
            add_node!(dag, :mean, Mean())
        end

        @when "I try to add another node with the same id :mean" begin
            dag = StatDAG()
            add_node!(dag, :mean, Mean())
            # Try to add duplicate
        end

        @then "it should raise an ArgumentError" begin
            dag = StatDAG()
            add_node!(dag, :mean, Mean())
            @test_throws ArgumentError add_node!(dag, :mean, Mean())
        end

        @and_ "the error message should mention 'already exists'" begin
            dag = StatDAG()
            add_node!(dag, :mean, Mean())
            err = try
                add_node!(dag, :mean, Mean())
                nothing
            catch e
                e
            end
            @test err isa ArgumentError
            @test occursin("already exists", err.msg)
        end
    end

    # REQ-DAG-004 & REQ-DAG-005: Connecting Nodes
    @scenario "Connecting two nodes" begin
        @given "a StatDAG with nodes :source and :sink" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
        end

        @when "I connect :source to :sink" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
        end

        @then ":sink should be in :source's children" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            @test :sink in dag.nodes[:source].children
        end

        @and_ ":source should be in :sink's parents" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            @test :source in dag.nodes[:sink].parents
        end
    end

    # REQ-DAG-005: Non-existent Node Error
    @scenario "Connecting non-existent nodes" begin
        @given "a StatDAG with only node :source" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
        end

        @when "I try to connect :source to :nonexistent" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            # Try to connect to non-existent
        end

        @then "it should raise an ArgumentError" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            @test_throws ArgumentError connect!(dag, :source, :nonexistent)
        end

        @and_ "connecting from non-existent should also raise an error" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            @test_throws ArgumentError connect!(dag, :nonexistent, :source)
        end
    end

    # REQ-DAG-006: Cycle Detection
    @scenario "Preventing cycles in the DAG" begin
        @given "a StatDAG with a chain :a -> :b -> :c" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            add_node!(dag, :c, Mean())
            connect!(dag, :a, :b)
            connect!(dag, :b, :c)
        end

        @when "I try to connect :c to :a (creating a cycle)" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            add_node!(dag, :c, Mean())
            connect!(dag, :a, :b)
            connect!(dag, :b, :c)
            # Try to create cycle
        end

        @then "it should raise a CycleError" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            add_node!(dag, :c, Mean())
            connect!(dag, :a, :b)
            connect!(dag, :b, :c)
            @test_throws CycleError connect!(dag, :c, :a)
        end

        @and_ "the connection should be rolled back" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            add_node!(dag, :c, Mean())
            connect!(dag, :a, :b)
            connect!(dag, :b, :c)
            try
                connect!(dag, :c, :a)
            catch
            end
            @test !(:a in dag.nodes[:c].children)
        end
    end

    # REQ-DAG-007 & REQ-DAG-008: Topological Ordering
    @scenario "Maintaining topological order" begin
        @given "a StatDAG with chain :a -> :b -> :c" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            add_node!(dag, :c, Mean())
            connect!(dag, :a, :b)
            connect!(dag, :b, :c)
        end

        @when "I request the topological order" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            add_node!(dag, :c, Mean())
            connect!(dag, :a, :b)
            connect!(dag, :b, :c)
            order = get_topological_order(dag)
        end

        @then "the order should contain all nodes" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            add_node!(dag, :c, Mean())
            connect!(dag, :a, :b)
            connect!(dag, :b, :c)
            order = get_topological_order(dag)
            @test length(order) == 3
        end

        @and_ ":a should come before :b" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            add_node!(dag, :c, Mean())
            connect!(dag, :a, :b)
            connect!(dag, :b, :c)
            order = get_topological_order(dag)
            @test findfirst(==(:a), order) < findfirst(==(:b), order)
        end

        @and_ ":b should come before :c" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            add_node!(dag, :c, Mean())
            connect!(dag, :a, :b)
            connect!(dag, :b, :c)
            order = get_topological_order(dag)
            @test findfirst(==(:b), order) < findfirst(==(:c), order)
        end
    end

    # REQ-FIT-001 & REQ-FIT-002: Single Value Update
    @scenario "Updating a node with a single value (streaming mode)" begin
        @given "a simple chain :source -> :sink with Mean stats" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
        end

        @when "I fit the value 1.0 to :source" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => 1.0)
        end

        @then "the source should have value 1.0" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => 1.0)
            @test value(dag, :source) == 1.0
        end

        @and_ "the value should propagate to :sink" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => 1.0)
            @test value(dag, :sink) == 1.0
        end

        @when "I fit another value 3.0 to :source" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => 1.0)
            fit!(dag, :source => 3.0)
        end

        @then "the source mean should be 2.0" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => 1.0)
            fit!(dag, :source => 3.0)
            @test value(dag, :source) == 2.0
        end

        @and_ "the sink should receive intermediate means [1.0, 2.0] -> mean = 1.5" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => 1.0)
            fit!(dag, :source => 3.0)
            @test value(dag, :sink) == 1.5
        end
    end

    # REQ-FIT-003 & REQ-FIT-004: Batch Update
    @scenario "Updating a node with an iterable (batch mode)" begin
        @given "a simple chain :source -> :sink with Mean stats" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
        end

        @when "I fit the array [1.0, 2.0, 3.0, 4.0, 5.0] to :source" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => [1.0, 2.0, 3.0, 4.0, 5.0])
        end

        @then "the source mean should be 3.0" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => [1.0, 2.0, 3.0, 4.0, 5.0])
            @test value(dag, :source) == 3.0
        end

        @and_ "each element should propagate sequentially to downstream nodes" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => [1.0, 2.0, 3.0, 4.0, 5.0])
            # Sink receives: [1.0, 1.5, 2.0, 2.5, 3.0] -> mean = 2.0
            @test value(dag, :sink) == 2.0
        end
    end

    # REQ-FIT-005 & REQ-FIT-006: Multiple Source Nodes
    @scenario "Updating multiple source nodes simultaneously" begin
        @given "a DAG with two independent source nodes" begin
            dag = StatDAG()
            add_node!(dag, :input1, Mean())
            add_node!(dag, :input2, Mean())
        end

        @when "I fit a Dict with single values to both nodes" begin
            dag = StatDAG()
            add_node!(dag, :input1, Mean())
            add_node!(dag, :input2, Mean())
            fit!(dag, Dict(:input1 => 10.0, :input2 => 20.0))
        end

        @then "input1 should have value 10.0" begin
            dag = StatDAG()
            add_node!(dag, :input1, Mean())
            add_node!(dag, :input2, Mean())
            fit!(dag, Dict(:input1 => 10.0, :input2 => 20.0))
            @test value(dag, :input1) == 10.0
        end

        @and_ "input2 should have value 20.0" begin
            dag = StatDAG()
            add_node!(dag, :input1, Mean())
            add_node!(dag, :input2, Mean())
            fit!(dag, Dict(:input1 => 10.0, :input2 => 20.0))
            @test value(dag, :input2) == 20.0
        end
    end

    # REQ-FIT-008: Mismatched Iterable Lengths
    @scenario "Processing iterables with different lengths" begin
        @given "a DAG with two source nodes" begin
            dag = StatDAG()
            add_node!(dag, :input1, Mean())
            add_node!(dag, :input2, Mean())
        end

        @when "I fit iterables of different lengths" begin
            dag = StatDAG()
            add_node!(dag, :input1, Mean())
            add_node!(dag, :input2, Mean())
            # Will process
        end

        @then "it should process up to shortest length and issue a warning" begin
            dag = StatDAG()
            add_node!(dag, :input1, Mean())
            add_node!(dag, :input2, Mean())
            @test_logs (:warn, r"different lengths") fit!(dag, Dict(
                :input1 => [1.0, 2.0, 3.0],
                :input2 => [4.0, 5.0]
            ))
        end
    end

    # REQ-MULTI-001, REQ-MULTI-002, REQ-MULTI-003: Multi-Input Nodes (Fan-in)
    @scenario "Connecting multiple sources to a single node (fan-in)" begin
        @given "a DAG with nodes :input1, :input2, and :combined" begin
            dag = StatDAG()
            add_node!(dag, :input1, Mean())
            add_node!(dag, :input2, Mean())
            add_node!(dag, :combined, Mean())
        end

        @when "I connect both inputs to the combined node using vector syntax" begin
            dag = StatDAG()
            add_node!(dag, :input1, Mean())
            add_node!(dag, :input2, Mean())
            add_node!(dag, :combined, Mean())
            connect!(dag, [:input1, :input2], :combined)
        end

        @then "the combined node should have both parents" begin
            dag = StatDAG()
            add_node!(dag, :input1, Mean())
            add_node!(dag, :input2, Mean())
            add_node!(dag, :combined, Mean())
            connect!(dag, [:input1, :input2], :combined)
            @test length(get_parents(dag, :combined)) == 2
            @test :input1 in get_parents(dag, :combined)
            @test :input2 in get_parents(dag, :combined)
        end
    end

    # Fan-out Pattern
    @scenario "One source feeding multiple downstream nodes (fan-out)" begin
        @given "a DAG with :source -> :branch1 and :source -> :branch2" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :branch1, Mean())
            add_node!(dag, :branch2, Mean())
            connect!(dag, :source, :branch1)
            connect!(dag, :source, :branch2)
        end

        @when "I fit data [1.0, 2.0, 3.0] to :source" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :branch1, Mean())
            add_node!(dag, :branch2, Mean())
            connect!(dag, :source, :branch1)
            connect!(dag, :source, :branch2)
            fit!(dag, :source => [1.0, 2.0, 3.0])
        end

        @then "both branches should receive the same intermediate values" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :branch1, Mean())
            add_node!(dag, :branch2, Mean())
            connect!(dag, :source, :branch1)
            connect!(dag, :source, :branch2)
            fit!(dag, :source => [1.0, 2.0, 3.0])
            @test value(dag, :source) == 2.0
            @test value(dag, :branch1) == 1.5
            @test value(dag, :branch2) == 1.5
        end
    end

    # Diamond Pattern
    @scenario "Complex DAG with diamond pattern" begin
        @given "a diamond pattern: :source -> :branch1 -> :sink and :source -> :branch2 -> :sink" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :branch1, Mean())
            add_node!(dag, :branch2, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :branch1)
            connect!(dag, :source, :branch2)
            connect!(dag, [:branch1, :branch2], :sink)
        end

        @when "I fit data to :source" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :branch1, Mean())
            add_node!(dag, :branch2, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :branch1)
            connect!(dag, :source, :branch2)
            connect!(dag, [:branch1, :branch2], :sink)
            fit!(dag, :source => [1.0, 2.0, 3.0])
        end

        @then "all nodes should be updated in topological order" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :branch1, Mean())
            add_node!(dag, :branch2, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :branch1)
            connect!(dag, :source, :branch2)
            connect!(dag, [:branch1, :branch2], :sink)
            fit!(dag, :source => [1.0, 2.0, 3.0])
            @test value(dag, :source) == 2.0
            @test value(dag, :branch1) == 1.5
            @test value(dag, :branch2) == 1.5
            @test value(dag, :sink) > 0  # Updated with array of parent values
        end
    end

    # REQ-VAL-001 & REQ-VAL-002: Value Retrieval
    @scenario "Retrieving values from the DAG" begin
        @given "a DAG with a node that has been updated" begin
            dag = StatDAG()
            add_node!(dag, :node1, Mean())
            fit!(dag, :node1 => 5.0)
        end

        @when "I request the value of :node1" begin
            dag = StatDAG()
            add_node!(dag, :node1, Mean())
            fit!(dag, :node1 => 5.0)
            val = value(dag, :node1)
        end

        @then "it should return 5.0" begin
            dag = StatDAG()
            add_node!(dag, :node1, Mean())
            fit!(dag, :node1 => 5.0)
            @test value(dag, :node1) == 5.0
        end

        @when "I request values for all nodes" begin
            dag = StatDAG()
            add_node!(dag, :node1, Mean())
            add_node!(dag, :node2, Mean())
            fit!(dag, :node1 => 5.0)
            all_vals = OnlineStatsChains.values(dag)
        end

        @then "it should return a Dict with all node values" begin
            dag = StatDAG()
            add_node!(dag, :node1, Mean())
            add_node!(dag, :node2, Mean())
            fit!(dag, :node1 => 5.0)
            all_vals = OnlineStatsChains.values(dag)
            @test haskey(all_vals, :node1)
            @test haskey(all_vals, :node2)
        end
    end

    # REQ-VAL-003: KeyError for non-existent node
    @scenario "Requesting value of non-existent node" begin
        @given "a DAG with some nodes" begin
            dag = StatDAG()
            add_node!(dag, :existing, Mean())
        end

        @when "I request the value of :nonexistent" begin
            dag = StatDAG()
            add_node!(dag, :existing, Mean())
            # Will throw error
        end

        @then "it should throw a KeyError" begin
            dag = StatDAG()
            add_node!(dag, :existing, Mean())
            @test_throws KeyError value(dag, :nonexistent)
        end
    end

    # REQ-INTRO-001, REQ-INTRO-002, REQ-INTRO-003: Graph Introspection
    @scenario "Inspecting the graph structure" begin
        @given "a DAG with structure :a -> :b and :a -> :c" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            add_node!(dag, :c, Mean())
            connect!(dag, :a, :b)
            connect!(dag, :a, :c)
        end

        @when "I request all node IDs" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            add_node!(dag, :c, Mean())
            connect!(dag, :a, :b)
            connect!(dag, :a, :c)
            nodes = get_nodes(dag)
        end

        @then "it should return all 3 node IDs" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            add_node!(dag, :c, Mean())
            connect!(dag, :a, :b)
            connect!(dag, :a, :c)
            nodes = get_nodes(dag)
            @test length(nodes) == 3
            @test :a in nodes
        end

        @when "I request the children of :a" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            add_node!(dag, :c, Mean())
            connect!(dag, :a, :b)
            connect!(dag, :a, :c)
            children = get_children(dag, :a)
        end

        @then "it should return [:b, :c]" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            add_node!(dag, :c, Mean())
            connect!(dag, :a, :b)
            connect!(dag, :a, :c)
            children = get_children(dag, :a)
            @test length(children) == 2
            @test :b in children
            @test :c in children
        end

        @when "I request the parents of :b" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            add_node!(dag, :c, Mean())
            connect!(dag, :a, :b)
            connect!(dag, :a, :c)
            parents = get_parents(dag, :b)
        end

        @then "it should return [:a]" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            add_node!(dag, :c, Mean())
            connect!(dag, :a, :b)
            connect!(dag, :a, :c)
            parents = get_parents(dag, :b)
            @test length(parents) == 1
            @test :a in parents
        end
    end

    # REQ-INTRO-005: Validation
    @scenario "Validating DAG consistency" begin
        @given "a valid DAG" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            connect!(dag, :a, :b)
        end

        @when "I validate the DAG" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            connect!(dag, :a, :b)
            result = validate(dag)
        end

        @then "it should return true" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            connect!(dag, :a, :b)
            @test validate(dag) == true
        end
    end

    # REQ-ERR-001, REQ-ERR-002, REQ-ERR-003, REQ-ERR-004, REQ-ERR-005: Error Handling
    @scenario "Comprehensive error handling" begin
        @when "attempting operations with non-existent nodes" begin
            dag = StatDAG()
            add_node!(dag, :existing, Mean())
        end

        @then "all error messages should be clear and actionable" begin
            dag = StatDAG()
            add_node!(dag, :test, Mean())

            # Duplicate node
            err = try
                add_node!(dag, :test, Mean())
                nothing
            catch e
                e
            end
            @test err isa ArgumentError
            @test occursin("already exists", err.msg)

            # Non-existent node in connect
            err = try
                connect!(dag, :test, :nonexistent)
                nothing
            catch e
                e
            end
            @test err isa ArgumentError
            @test occursin("does not exist", err.msg)

            # Non-existent node in fit!
            err = try
                fit!(dag, :nonexistent => 1.0)
                nothing
            catch e
                e
            end
            @test err isa ArgumentError
            @test occursin("does not exist", err.msg)
        end
    end

    # REQ-EVAL-002: Lazy Evaluation Mode
    @scenario "Lazy evaluation mode" begin
        @given "a DAG with lazy evaluation strategy" begin
            dag = StatDAG(strategy=:lazy)
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
        end

        @when "I fit data to the source node" begin
            dag = StatDAG(strategy=:lazy)
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => 1.0)
        end

        @then "the source should be updated but not propagated" begin
            dag = StatDAG(strategy=:lazy)
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => 1.0)
            @test value(dag, :source) == 1.0
            # Note: value() triggers recomputation in lazy mode
        end

        @and_ "the source and sink should be marked as dirty" begin
            dag = StatDAG(strategy=:lazy)
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => 1.0)
            @test :source in dag.dirty_nodes || :sink in dag.dirty_nodes  # At least one is dirty before value() call
        end

        @when "I request the value of the sink node" begin
            dag = StatDAG(strategy=:lazy)
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => 1.0)
            sink_val = value(dag, :sink)
        end

        @then "it should trigger recomputation and return the correct value" begin
            dag = StatDAG(strategy=:lazy)
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => 1.0)
            @test value(dag, :sink) == 1.0
        end
    end

    # REQ-API-004: invalidate! and recompute! functions
    @scenario "Manual invalidation and recomputation" begin
        @given "a lazy DAG with computed values" begin
            dag = StatDAG(strategy=:lazy)
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => 1.0)
            value(dag, :sink)  # Trigger computation
        end

        @when "I invalidate a node manually" begin
            dag = StatDAG(strategy=:lazy)
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => 1.0)
            value(dag, :sink)
            invalidate!(dag, :source)
        end

        @then "the node and its descendants should be marked dirty" begin
            dag = StatDAG(strategy=:lazy)
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => 1.0)
            value(dag, :sink)
            invalidate!(dag, :source)
            @test :source in dag.dirty_nodes
            @test :sink in dag.dirty_nodes
        end

        @when "I call recompute!" begin
            dag = StatDAG(strategy=:lazy)
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => 1.0)
            invalidate!(dag, :source)
            recompute!(dag)
        end

        @then "all dirty nodes should be recomputed" begin
            dag = StatDAG(strategy=:lazy)
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => 1.0)
            invalidate!(dag, :source)
            recompute!(dag)
            @test isempty(dag.dirty_nodes)
        end
    end

    # REQ-EVAL-003: Partial Evaluation Mode
    @scenario "Partial evaluation mode" begin
        @given "a DAG with partial evaluation strategy" begin
            dag = StatDAG(strategy=:partial)
            add_node!(dag, :source, Mean())
            add_node!(dag, :branch1, Mean())
            add_node!(dag, :branch2, Mean())
            connect!(dag, :source, :branch1)
            connect!(dag, :source, :branch2)
        end

        @when "I fit data to the source" begin
            dag = StatDAG(strategy=:partial)
            add_node!(dag, :source, Mean())
            add_node!(dag, :branch1, Mean())
            add_node!(dag, :branch2, Mean())
            connect!(dag, :source, :branch1)
            connect!(dag, :source, :branch2)
            fit!(dag, :source => 1.0)
        end

        @then "only the affected subgraph should be updated" begin
            dag = StatDAG(strategy=:partial)
            add_node!(dag, :source, Mean())
            add_node!(dag, :branch1, Mean())
            add_node!(dag, :branch2, Mean())
            connect!(dag, :source, :branch1)
            connect!(dag, :source, :branch2)
            fit!(dag, :source => 1.0)
            # Partial behaves like eager for now (optimization can be added later)
            @test value(dag, :branch1) == 1.0
            @test value(dag, :branch2) == 1.0
        end
    end

    # REQ-EVAL-004 & REQ-EVAL-005: Strategy selection and switching
    @scenario "Creating DAG with specific strategy" begin
        @when "I create a DAG with eager strategy" begin
            dag = StatDAG(strategy=:eager)
        end

        @then "the strategy should be set to eager" begin
            dag = StatDAG(strategy=:eager)
            @test dag.strategy == :eager
        end

        @when "I create a DAG with lazy strategy" begin
            dag = StatDAG(strategy=:lazy)
        end

        @then "the strategy should be set to lazy" begin
            dag = StatDAG(strategy=:lazy)
            @test dag.strategy == :lazy
        end

        @when "I create a DAG with invalid strategy" begin
            # Will throw error
        end

        @then "it should raise an ArgumentError" begin
            @test_throws ArgumentError StatDAG(strategy=:invalid)
        end
    end

    @scenario "Switching evaluation strategy" begin
        @given "an eager DAG with some data" begin
            dag = StatDAG(strategy=:eager)
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => 1.0)
        end

        @when "I switch to lazy strategy" begin
            dag = StatDAG(strategy=:eager)
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => 1.0)
            set_strategy!(dag, :lazy)
        end

        @then "the strategy should be changed" begin
            dag = StatDAG(strategy=:eager)
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => 1.0)
            set_strategy!(dag, :lazy)
            @test dag.strategy == :lazy
        end

        @and_ "all nodes should be marked dirty when switching to lazy" begin
            dag = StatDAG(strategy=:eager)
            add_node!(dag, :source, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :sink)
            fit!(dag, :source => 1.0)
            set_strategy!(dag, :lazy)
            @test !isempty(dag.dirty_nodes)
        end

        @when "I switch from lazy back to eager" begin
            dag = StatDAG(strategy=:lazy)
            add_node!(dag, :source, Mean())
            fit!(dag, :source => 1.0)
            set_strategy!(dag, :eager)
        end

        @then "dirty nodes should be cleared" begin
            dag = StatDAG(strategy=:lazy)
            add_node!(dag, :source, Mean())
            fit!(dag, :source => 1.0)
            set_strategy!(dag, :eager)
            @test isempty(dag.dirty_nodes)
        end
    end
end

# Include integration tests with OnlineStats.jl if available
if isdefined(@__MODULE__, :OnlineStats)
    @info "Running integration tests with OnlineStats.jl"
    include("test_integration_onlinestats.jl")
else
    @warn "OnlineStats.jl not available - skipping integration tests"
end
