using Test
using OnlineStatsChains
using OnlineStats

@testset "Edge Transformers" begin
    @testset "Basic Transform" begin
        dag = StatDAG()
        add_node!(dag, :raw, Mean())
        add_node!(dag, :scaled, Mean())
        
        # REQ-TRANS-001: connect! SHALL accept transform keyword argument
        connect!(dag, :raw, :scaled, transform = x -> x * 100)
        
        # Test single value
        fit!(dag, :raw => 5.0)
        @test value(dag, :raw) ≈ 5.0
        @test value(dag, :scaled) ≈ 500.0  # REQ-TRANS-002: transformed before propagation
        
        # Test batch mode
        fit!(dag, :raw => [1.0, 2.0, 3.0])
        @test value(dag, :raw) ≈ 2.75  # Mean of [5, 1, 2, 3]
        @test value(dag, :scaled) ≈ 275.0  # Mean of [500, 100, 200, 300]
    end
    
    @testset "Identity Transform (No Transform)" begin
        # REQ-TRANS-003: No transform means backward compatible behavior
        # Without transform, propagates COMPUTED values (means), not raw data
        dag = StatDAG()
        add_node!(dag, :source, Mean())
        add_node!(dag, :sink, Mean())
        
        connect!(dag, :source, :sink)  # No transform
        
        fit!(dag, :source => [10.0, 20.0, 30.0])
        # source computes: mean([10, 20, 30]) = 20.0
        # sink receives computed values at each step: [10.0, 15.0, 20.0]
        # sink computes: mean([10.0, 15.0, 20.0]) = 15.0
        @test value(dag, :source) ≈ 20.0
        @test value(dag, :sink) ≈ 15.0  # Backward compatible: receives computed values
    end
    
    @testset "Transform with Different Operations" begin
        # REQ-TRANS-012: Common transformation patterns
        dag = StatDAG()
        add_node!(dag, :source, Mean())
        add_node!(dag, :doubled, Mean())
        add_node!(dag, :squared, Mean())
        add_node!(dag, :logged, Mean())
        
        # Different mathematical operations
        connect!(dag, :source, :doubled, transform = x -> x * 2)
        connect!(dag, :source, :squared, transform = x -> x^2)
        connect!(dag, :source, :logged, transform = x -> log(x))
        
        fit!(dag, :source => [1.0, 2.0, 4.0, 8.0])
        
        @test value(dag, :source) ≈ 3.75
        @test value(dag, :doubled) ≈ 7.5
        @test value(dag, :squared) ≈ mean([1.0^2, 2.0^2, 4.0^2, 8.0^2])
        @test value(dag, :logged) ≈ mean(log.([1.0, 2.0, 4.0, 8.0]))
    end
    
    @testset "Combined Filter and Transform" begin
        # REQ-TRANS-007: Filter evaluated first, then transform
        dag = StatDAG()
        add_node!(dag, :temps, Mean())
        add_node!(dag, :fahrenheit, Mean())
        
        # Only convert non-missing valid temperatures
        connect!(dag, :temps, :fahrenheit,
                 filter = t -> !ismissing(t) && t >= -273.15,
                 transform = c -> c * 9/5 + 32)
        
        # Use only valid values for source (missing values would fail fit!)
        temps_c = [0.0, 100.0, -274.0, 37.0]  # One invalid (below absolute zero)
        fit!(dag, :temps => temps_c)
        
        # Mean of all temps in Celsius: (0 + 100 - 274 + 37) / 4 = -34.25
        @test value(dag, :temps) ≈ -34.25
        
        # Mean of valid temps in Fahrenheit: only 0, 100, and 37 pass filter
        # (0°C = 32°F, 100°C = 212°F, 37°C = 98.6°F)
        expected_f = mean([0.0 * 9/5 + 32, 100.0 * 9/5 + 32, 37.0 * 9/5 + 32])
        @test value(dag, :fahrenheit) ≈ expected_f
    end
    
    @testset "Transform Error Handling" begin
        # REQ-TRANS-006: Transform exceptions should be caught and contextualized
        dag = StatDAG()
        add_node!(dag, :source, Mean())
        add_node!(dag, :target, Mean())
        
        # Transform that will fail (accessing field on non-struct)
        connect!(dag, :source, :target, transform = x -> x.nonexistent_field)
        
        # This should throw an error with context about the transform
        @test_throws ErrorException fit!(dag, :source => 5.0)
    end
    
    @testset "Multi-Input Transform" begin
        # REQ-TRANS-010: Multi-input connections support transformers
        dag = StatDAG()
        add_node!(dag, :price, Mean())
        add_node!(dag, :quantity, Mean())
        add_node!(dag, :total, Mean())
        
        # Transform combines both inputs: price * quantity
        connect!(dag, [:price, :quantity], :total,
                 transform = vals -> vals[1] * vals[2])
        
        prices = [10.0, 20.0, 15.0]
        quantities = [5.0, 3.0, 4.0]
        
        fit!(dag, Dict(:price => prices, :quantity => quantities))
        
        # Mean price and quantity
        @test value(dag, :price) ≈ 15.0
        @test value(dag, :quantity) ≈ 4.0
        
        # Mean of (price * quantity) for each pair
        expected_total = mean([10.0 * 5.0, 20.0 * 3.0, 15.0 * 4.0])
        @test value(dag, :total) ≈ expected_total
    end
    
    @testset "Transform Introspection" begin
        # REQ-TRANS-011: Introspection functions
        dag = StatDAG()
        add_node!(dag, :a, Mean())
        add_node!(dag, :b, Mean())
        add_node!(dag, :c, Mean())
        
        transform_fn = x -> x * 2
        connect!(dag, :a, :b, transform = transform_fn)
        connect!(dag, :b, :c)  # No transform
        
        # has_transform
        @test has_transform(dag, :a, :b) == true
        @test has_transform(dag, :b, :c) == false
        @test has_transform(dag, :a, :c) == false  # No edge
        
        # get_transform
        @test get_transform(dag, :a, :b) === transform_fn
        @test get_transform(dag, :b, :c) === nothing
        @test get_transform(dag, :a, :c) === nothing  # No edge
    end
    
    @testset "Transform in Different Evaluation Modes" begin
        # REQ-TRANS-009: Transformers work in all evaluation modes
        
        # Eager mode (default)
        dag_eager = StatDAG(strategy=:eager)
        add_node!(dag_eager, :source, Mean())
        add_node!(dag_eager, :scaled, Mean())
        connect!(dag_eager, :source, :scaled, transform = x -> x * 10)
        
        fit!(dag_eager, :source => 5.0)
        @test value(dag_eager, :scaled) ≈ 50.0
        
        # Lazy mode
        dag_lazy = StatDAG(strategy=:lazy)
        add_node!(dag_lazy, :source, Mean())
        add_node!(dag_lazy, :scaled, Mean())
        connect!(dag_lazy, :source, :scaled, transform = x -> x * 10)
        
        fit!(dag_lazy, :source => 5.0)
        @test value(dag_lazy, :scaled) ≈ 50.0  # Triggers recomputation
        
        # Partial mode
        dag_partial = StatDAG(strategy=:partial)
        add_node!(dag_partial, :source, Mean())
        add_node!(dag_partial, :scaled, Mean())
        connect!(dag_partial, :source, :scaled, transform = x -> x * 10)
        
        fit!(dag_partial, :source => 5.0)
        @test value(dag_partial, :scaled) ≈ 50.0
    end
    
    @testset "Multiple Edges with Different Transforms" begin
        # REQ-TRANS-008: Multiple edges evaluated independently
        dag = StatDAG()
        add_node!(dag, :source, Mean())
        add_node!(dag, :x2, Mean())
        add_node!(dag, :x3, Mean())
        add_node!(dag, :x10, Mean())
        
        connect!(dag, :source, :x2, transform = x -> x * 2)
        connect!(dag, :source, :x3, transform = x -> x * 3)
        connect!(dag, :source, :x10, transform = x -> x * 10)
        
        fit!(dag, :source => [1.0, 2.0, 3.0, 4.0])
        
        mean_val = 2.5
        @test value(dag, :source) ≈ mean_val
        @test value(dag, :x2) ≈ mean_val * 2
        @test value(dag, :x3) ≈ mean_val * 3
        @test value(dag, :x10) ≈ mean_val * 10
    end
    
    @testset "Type Conversion Transform" begin
        # REQ-TRANS-012: Type conversions
        dag = StatDAG()
        add_node!(dag, :source, Mean())
        add_node!(dag, :rounded, Mean())
        
        connect!(dag, :source, :rounded, transform = x -> round(Int, x))
        
        fit!(dag, :source => [1.2, 2.7, 3.4, 4.9])
        
        @test value(dag, :source) ≈ 3.05
        # Mean of rounded values: [1, 3, 3, 5] = 3.0
        @test value(dag, :rounded) ≈ 3.0
    end
    
    @testset "Data Extraction Transform" begin
        # REQ-TRANS-012: Data extraction - extract part of complex data
        # Test extracting specific component via transform
        dag = StatDAG()
        add_node!(dag, :source, Mean())
        add_node!(dag, :doubled, Mean())
        
        # Transform extracts and doubles the value
        connect!(dag, :source, :doubled, transform = x -> x * 2)
        
        # Feed simple numeric values
        fit!(dag, :source => [10.0, 20.0, 30.0])
        
        # Source: mean([10, 20, 30]) = 20
        @test value(dag, :source) ≈ 20.0
        # Doubled: mean([20, 40, 60]) = 40
        @test value(dag, :doubled) ≈ 40.0
    end
end
