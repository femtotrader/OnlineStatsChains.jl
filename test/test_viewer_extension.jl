# Test file for Viewer Extension
# This file uses classic @testset (not @testitem) because JSServe, JSON3, Colors, NanoDates are weak dependencies
# These tests are conditionally included in runtests.jl only when dependencies are available

using Test
using OnlineStatsChains
using OnlineStats
using JSServe, JSON3, Colors, NanoDates

# Get extension module
const ViewerExt = Base.get_extension(OnlineStatsChains, :OnlineStatsChainsViewerExt)
if ViewerExt === nothing
    error("Viewer extension failed to load")
end

# Import extension symbols via the extension module
using .ViewerExt: to_cytoscape_json, export_dag, display
using .ViewerExt: capture_timestamp, format_timestamp, format_time_delta
using .ViewerExt: set_node_style!, set_edge_style!, set_style!

@testset "Viewer Extension" begin

    @testset "Extension Loading" begin
        ext = Base.get_extension(OnlineStatsChains, :OnlineStatsChainsViewerExt)
        @test ext !== nothing
        @test ext isa Module
    end

    @testset "Timestamp Utilities" begin
        @testset "Capture timestamp" begin
            t1 = capture_timestamp()
            sleep(0.001)  # 1 millisecond
            t2 = capture_timestamp()

            @test t2 > t1
            @test (t2 - t1) > 1_000_000  # At least 1 ms difference in nanoseconds
            @test isa(t1, UInt64)  # time_ns() returns UInt64
        end

        @testset "Format timestamp" begin
            # Test with a known timestamp
            t = 1728134567123456789  # Example nanosecond timestamp
            timestamp_str = format_timestamp(t)

            @test occursin("T", timestamp_str)  # ISO 8601 format
            @test occursin("Z", timestamp_str)  # UTC indicator
            @test occursin(".", timestamp_str)  # Has fractional seconds
        end

        @testset "Format time delta" begin
            @test format_time_delta(500) == "500 ns"
            @test format_time_delta(1_500) == "1.5 μs"
            @test format_time_delta(1_234_567) == "1.235 ms"
            @test format_time_delta(2_500_000_000) == "2.5 s"
        end
    end

    @testset "JSON Serialization" begin
        @testset "Basic DAG" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :variance, Variance())
            connect!(dag, :source, :variance)

            json_str = to_cytoscape_json(dag)
            @test occursin("\"nodes\"", json_str)
            @test occursin("\"edges\"", json_str)
            @test occursin("source", json_str)
            @test occursin("variance", json_str)

            # Validate JSON structure
            data = JSON3.read(json_str)
            @test haskey(data, :nodes)
            @test haskey(data, :edges)
            @test length(data[:nodes]) == 2
            @test length(data[:edges]) == 1
        end

        @testset "Node metadata" begin
            dag = StatDAG()
            add_node!(dag, :mean, Mean())
            add_node!(dag, :sum, Sum())

            json_str = to_cytoscape_json(dag)
            data = JSON3.read(json_str)

            # Check node structure
            node = data[:nodes][1]
            @test haskey(node, :data)
            @test haskey(node[:data], :id)
            @test haskey(node[:data], :label)
            @test haskey(node[:data], :type)
            @test haskey(node[:data], :is_source)
            @test haskey(node[:data], :is_sink)
        end

        @testset "Edge metadata" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :filtered, Mean())
            add_node!(dag, :transformed, Mean())

            connect!(dag, :source, :filtered, filter = x -> x > 0)
            connect!(dag, :source, :transformed, transform = x -> x * 2)

            json_str = to_cytoscape_json(dag)
            data = JSON3.read(json_str)

            # Find edges
            edges = data[:edges]
            @test length(edges) == 2

            # Check for filter and transform metadata
            has_filter_edge = any(e -> get(e[:data], :has_filter, false), edges)
            has_transform_edge = any(e -> get(e[:data], :has_transform, false), edges)

            @test has_filter_edge
            @test has_transform_edge
        end

        @testset "With values" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            fit!(dag, :source => [1, 2, 3])

            json_str = to_cytoscape_json(dag, show_values=true)
            @test occursin("value", json_str)

            data = JSON3.read(json_str)
            node_data = data[:nodes][1][:data]
            @test haskey(node_data, :value)
            @test node_data[:value] isa Number
        end

        @testset "Source and sink detection" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :middle, Mean())
            add_node!(dag, :sink, Mean())
            connect!(dag, :source, :middle)
            connect!(dag, :middle, :sink)

            json_str = to_cytoscape_json(dag)
            data = JSON3.read(json_str)

            # Find nodes by id
            nodes_dict = Dict(n[:data][:id] => n[:data] for n in data[:nodes])

            @test nodes_dict["source"][:is_source] == true
            @test nodes_dict["source"][:is_sink] == false
            @test nodes_dict["middle"][:is_source] == false
            @test nodes_dict["middle"][:is_sink] == false
            @test nodes_dict["sink"][:is_source] == false
            @test nodes_dict["sink"][:is_sink] == true
        end
    end

    @testset "Export Functions" begin
        @testset "JSON export" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            fit!(dag, :source => [1, 2, 3])

            tmpfile = tempname() * ".json"
            try
                export_dag(dag, tmpfile, format=:json)
                @test isfile(tmpfile)

                content = read(tmpfile, String)
                @test occursin("nodes", content)
                @test occursin("edges", content)

                # Validate it's valid JSON
                data = JSON3.read(content)
                @test haskey(data, :nodes)
            finally
                rm(tmpfile, force=true)
            end
        end

        @testset "Invalid format" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())

            @test_throws ArgumentError export_dag(dag, "test.txt", format=:invalid)
        end

        @testset "Unimplemented formats" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())

            @test_throws ErrorException export_dag(dag, "test.png", format=:png)
            @test_throws ErrorException export_dag(dag, "test.svg", format=:svg)
            @test_throws ErrorException export_dag(dag, "test.graphml", format=:graphml)
        end
    end

    @testset "Display Function" begin
        @testset "Basic display" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :variance, Variance())
            connect!(dag, :source, :variance)

            # Should not throw - returns a viewer object
            viewer = display(dag)
            @test viewer isa Dict
            @test haskey(viewer, :host)
            @test haskey(viewer, :port)
            @test haskey(viewer, :html)
            @test viewer[:host] == "127.0.0.1"
            @test viewer[:port] == 8080
        end

        @testset "Custom parameters" begin
            dag = StatDAG()
            add_node!(dag, :mean, Mean())

            viewer = display(dag, layout=:force, theme=:dark, port=8081)
            @test viewer[:port] == 8081
            @test occursin("cose", viewer[:html])  # Force layout maps to cose
            @test occursin("#1e1e1e", viewer[:html])  # Dark theme background
        end

        @testset "Invalid layout" begin
            dag = StatDAG()
            add_node!(dag, :mean, Mean())

            @test_throws ArgumentError display(dag, layout=:invalid)
        end

        @testset "Invalid theme" begin
            dag = StatDAG()
            add_node!(dag, :mean, Mean())

            @test_throws ArgumentError display(dag, theme=:invalid)
        end
    end

    @testset "Styling Functions" begin
        @testset "set_node_style! - KeyError" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())

            @test_throws KeyError set_node_style!(dag, :nonexistent, color="red")
        end

        @testset "set_edge_style! - KeyError" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            connect!(dag, :a, :b)

            @test_throws KeyError set_edge_style!(dag, :a, :nonexistent, color="red")
        end
    end

    @testset "Complex DAG" begin
        @testset "Diamond pattern" begin
            dag = StatDAG()
            add_node!(dag, :a, Mean())
            add_node!(dag, :b, Mean())
            add_node!(dag, :c, Mean())
            add_node!(dag, :d, Mean())
            connect!(dag, :a, :b)
            connect!(dag, :a, :c)
            connect!(dag, :b, :d)
            connect!(dag, :c, :d)

            json_str = to_cytoscape_json(dag)
            data = JSON3.read(json_str)

            @test length(data[:nodes]) == 4
            @test length(data[:edges]) == 4
        end

        @testset "Fan-out pattern" begin
            dag = StatDAG()
            add_node!(dag, :source, Mean())
            add_node!(dag, :out1, Mean())
            add_node!(dag, :out2, Mean())
            add_node!(dag, :out3, Mean())
            connect!(dag, :source, :out1)
            connect!(dag, :source, :out2)
            connect!(dag, :source, :out3)

            json_str = to_cytoscape_json(dag)
            data = JSON3.read(json_str)

            @test length(data[:nodes]) == 4
            @test length(data[:edges]) == 3

            # Source should be marked as source
            source_node = first(filter(n -> n[:data][:id] == "source", data[:nodes]))
            @test source_node[:data][:is_source] == true
        end
    end

    @testset "Edge Cases" begin
        @testset "Empty DAG" begin
            dag = StatDAG()
            json_str = to_cytoscape_json(dag)
            data = JSON3.read(json_str)

            @test length(data[:nodes]) == 0
            @test length(data[:edges]) == 0
        end

        @testset "Single node" begin
            dag = StatDAG()
            add_node!(dag, :lonely, Mean())

            json_str = to_cytoscape_json(dag)
            data = JSON3.read(json_str)

            @test length(data[:nodes]) == 1
            @test length(data[:edges]) == 0
            @test data[:nodes][1][:data][:is_source] == true
            @test data[:nodes][1][:data][:is_sink] == true
        end

        @testset "Special values" begin
            dag = StatDAG()
            add_node!(dag, :mean, Mean())

            # Test with NaN
            fit!(dag, :mean => [NaN, 1.0, 2.0])
            json_str = to_cytoscape_json(dag)
            @test occursin("NaN", json_str) || occursin("null", json_str)  # Either is acceptable
        end
    end

    @testset "Example Scripts Validation" begin
        # Most viewer examples are interactive (wait for user input with infinite loops)
        # These are meant to be run manually by users, not in automated tests
        # We only test non-interactive examples here

        examples_dir = joinpath(dirname(@__DIR__), "examples", "viz")

        # Skip all interactive examples that have "while true" loops:
        # - viewer_basic.jl (waits for Ctrl+C)
        # - viewer_export.jl (waits for Ctrl+C)
        # - viewer_layouts.jl (waits for Ctrl+C)
        # - viewer_custom_style.jl (waits for Ctrl+C)
        # - simple_viewer_demo.jl (waits for Ctrl+C)
        # - viewer_realtime.jl (realtime updates, waits for Ctrl+C)
        # - run_viewer.jl (interactive runner script)

        # Note: All viewer examples are interactive demos meant for manual exploration
        # The actual viewer functionality is tested in the main test suite above
        @test true  # Placeholder to avoid empty testset
    end
end
