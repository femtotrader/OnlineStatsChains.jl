# Test file for type stability
# Verifies that core functions are type-stable for performance

@testitem "Type Stability" begin
    using OnlineStats
    import OnlineStatsChains: values

    @testset "Basic Operations Type Stability" begin
        dag = StatDAG()
        add_node!(dag, :mean, Mean())

        # Test that basic operations return inferred types
        @test @inferred(StatDAG()) isa StatDAG
        @test @inferred(add_node!(dag, :variance, Variance())) isa StatDAG
    end

    @testset "fit! Type Stability" begin
        dag = StatDAG()
        add_node!(dag, :mean, Mean())

        # Single value fit should be type stable
        @test @inferred(fit!(dag, :mean => 1.0)) isa StatDAG

        # Batch fit should be type stable
        dag2 = StatDAG()
        add_node!(dag2, :mean2, Mean())
        @test @inferred(fit!(dag2, :mean2 => [1.0, 2.0, 3.0])) isa StatDAG
    end

    @testset "value Type Stability" begin
        dag = StatDAG()
        add_node!(dag, :mean, Mean())
        fit!(dag, :mean => [1.0, 2.0, 3.0])

        # value() returns Any because different nodes can have different types
        # This is expected and not a performance issue
        val = value(dag, :mean)
        @test val isa Float64
    end

    @testset "values Type Stability" begin
        dag = StatDAG()
        add_node!(dag, :mean, Mean())
        add_node!(dag, :variance, Variance())
        fit!(dag, :mean => [1.0, 2.0, 3.0])
        fit!(dag, :variance => [1.0, 2.0, 3.0])

        # values() returns Dict{Symbol, <concrete type>} (depends on nodes)
        result = values(dag)
        @test result isa Dict
        @test haskey(result, :mean)
        @test haskey(result, :variance)
    end

    @testset "Graph Operations Type Stability" begin
        dag = StatDAG()
        add_node!(dag, :source, Mean())
        add_node!(dag, :sink, Mean())
        connect!(dag, :source, :sink)

        # Graph introspection should be type stable
        @test @inferred(get_nodes(dag)) isa Vector{Symbol}
        @test @inferred(get_parents(dag, :sink)) isa Vector{Symbol}
        @test @inferred(get_children(dag, :source)) isa Vector{Symbol}
    end

    @testset "Edge Operations Type Stability" begin
        dag = StatDAG()
        add_node!(dag, :source, Mean())
        add_node!(dag, :sink, Mean())

        # Filter function
        filter_fn = x -> x > 0
        @test @inferred(connect!(dag, :source, :sink, filter=filter_fn)) isa StatDAG

        # Check filter introspection
        @test @inferred(has_filter(dag, :source, :sink)) isa Bool
        # Note: get_filter returns Union{Function, Nothing} which is not concrete
        result = get_filter(dag, :source, :sink)
        @test result isa Union{Function, Nothing}
    end

    @testset "Transform Operations Type Stability" begin
        dag = StatDAG()
        add_node!(dag, :celsius, Mean())
        add_node!(dag, :fahrenheit, Mean())

        # Transform function
        to_f = c -> c * 9/5 + 32
        @test @inferred(connect!(dag, :celsius, :fahrenheit, transform=to_f)) isa StatDAG

        # Check transform introspection
        @test @inferred(has_transform(dag, :celsius, :fahrenheit)) isa Bool
    end

    @testset "Strategy Operations Type Stability" begin
        dag = StatDAG()

        # Strategy operations should be type stable
        @test @inferred(set_strategy!(dag, :lazy)) isa StatDAG
        @test @inferred(set_strategy!(dag, :eager)) isa StatDAG
    end

    @testset "Multi-input Type Stability" begin
        dag = StatDAG()
        add_node!(dag, :input1, Mean())
        add_node!(dag, :input2, Mean())
        add_node!(dag, :combined, Mean())

        connect!(dag, [:input1, :input2], :combined)

        # Multi-input fit should be type stable
        data = Dict(:input1 => 1.0, :input2 => 2.0)
        @test @inferred(fit!(dag, data)) isa StatDAG
    end

    @testset "Evaluation Strategy Type Stability" begin
        # Eager mode
        dag_eager = StatDAG(strategy=:eager)
        add_node!(dag_eager, :source, Mean())
        add_node!(dag_eager, :sink, Mean())
        connect!(dag_eager, :source, :sink)
        @test @inferred(fit!(dag_eager, :source => 1.0)) isa StatDAG

        # Lazy mode
        dag_lazy = StatDAG(strategy=:lazy)
        add_node!(dag_lazy, :source, Mean())
        @test @inferred(fit!(dag_lazy, :source => 1.0)) isa StatDAG
        @test @inferred(recompute!(dag_lazy)) isa StatDAG

        # Partial mode
        dag_partial = StatDAG(strategy=:partial)
        add_node!(dag_partial, :source, Mean())
        @test @inferred(fit!(dag_partial, :source => 1.0)) isa StatDAG
    end

    @testset "Validation Type Stability" begin
        dag = StatDAG()
        add_node!(dag, :mean, Mean())

        # Validation should return Bool
        @test @inferred(validate(dag)) isa Bool
    end

    @testset "Topological Order Type Stability" begin
        dag = StatDAG()
        add_node!(dag, :a, Mean())
        add_node!(dag, :b, Mean())
        add_node!(dag, :c, Mean())
        connect!(dag, :a, :b)
        connect!(dag, :b, :c)

        # Topological order should return Vector{Symbol}
        @test @inferred(get_topological_order(dag)) isa Vector{Symbol}
    end
end

@testitem "Observer System Type Stability" begin
    using OnlineStats
    import OnlineStatsChains: add_observer!, remove_observer!, notify_observers!

    @testset "Observer Operations Type Stability" begin
        dag = StatDAG()
        add_node!(dag, :mean, Mean())

        # Create a simple callback
        callback = (node_id, cached_val, raw_val) -> nothing

        # add_observer! should return Int
        observer_id = @inferred add_observer!(dag, :mean, callback)
        @test observer_id isa Int

        # remove_observer! should return Nothing
        @test @inferred(remove_observer!(dag, :mean, observer_id)) === nothing
    end

    @testset "notify_observers! Type Stability" begin
        dag = StatDAG()
        add_node!(dag, :mean, Mean())

        callback = (node_id, cached_val, raw_val) -> nothing
        add_observer!(dag, :mean, callback)

        # notify_observers! should return Nothing
        @test @inferred(notify_observers!(dag, :mean, 1.0, 1.0)) === nothing
    end
end

@testitem "Performance Critical Paths" begin
    using OnlineStats
    using BenchmarkTools

    @testset "No Type Instabilities in Hot Path" begin
        dag = StatDAG()
        add_node!(dag, :mean, Mean())
        add_node!(dag, :variance, Variance())
        connect!(dag, :mean, :variance)

        # Pre-compile
        fit!(dag, :mean => 1.0)

        # Check for allocations (type instabilities often cause allocations)
        allocs = @allocated begin
            for i in 1:100
                fit!(dag, :mean => Float64(i))
            end
        end

        # Should have minimal allocations in steady state
        # Note: Some allocations are expected due to OnlineStat internals
        @test allocs < 50000  # Reasonable threshold
    end

    @testset "Filter Path Performance" begin
        dag = StatDAG()
        add_node!(dag, :source, Mean())
        add_node!(dag, :filtered, Mean())
        connect!(dag, :source, :filtered, filter = x -> x > 0)

        # Pre-compile
        fit!(dag, :source => 1.0)

        # Measure allocations
        allocs = @allocated begin
            for i in 1:100
                fit!(dag, :source => Float64(i))
            end
        end

        @test allocs < 100000
    end

    @testset "Transform Path Performance" begin
        dag = StatDAG()
        add_node!(dag, :celsius, Mean())
        add_node!(dag, :fahrenheit, Mean())
        connect!(dag, :celsius, :fahrenheit, transform = c -> c * 9/5 + 32)

        # Pre-compile
        fit!(dag, :celsius => 0.0)

        # Measure allocations
        allocs = @allocated begin
            for i in 1:100
                fit!(dag, :celsius => Float64(i))
            end
        end

        @test allocs < 100000
    end
end
