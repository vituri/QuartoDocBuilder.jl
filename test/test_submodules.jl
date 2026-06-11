using Test
using Logging
using QuartoDocBuilder

# ---------------------------------------------------------------------------
# Test fixture: a module hierarchy with documented and undocumented bindings
# ---------------------------------------------------------------------------

module OuterMod

export outer_func

"""
    outer_func(x)

A documented function in OuterMod.
"""
outer_func(x) = x

"""
    OuterType

A documented type in OuterMod.
"""
struct OuterType end

# An undocumented binding — should never appear in documented lists
undocumented_outer() = nothing

module Inner

export inner_func

"""
    inner_func(x)

A documented function in Inner.
"""
inner_func(x) = x * 2

"""
    shared_name(x)

A documented function in Inner — name collides with OuterMod.Inner.Deep.shared_name.
"""
shared_name(x) = x

module Deep

export deep_func

"""
    deep_func(x)

A documented function in Deep (nested inside Inner).
"""
deep_func(x) = x ^ 2

"""
    shared_name(x)

A documented function in Deep — name collides with OuterMod.Inner.shared_name.
"""
shared_name(x) = x + 1

end # module Deep
end # module Inner

# An undocumented submodule — should NOT trigger the "submodule has docs" warning
module EmptySub
nothing_here() = 1
end # module EmptySub

end # module OuterMod

# ---------------------------------------------------------------------------
# Helper: collect just the .var symbols from a binding vector
# ---------------------------------------------------------------------------
binding_vars(bindings) = Set(b.var for b in bindings)

# ---------------------------------------------------------------------------
# Helper: capture log messages at Warn level and above as a string
# ---------------------------------------------------------------------------
function capture_warnings(f)
    buf = IOBuffer()
    logger = SimpleLogger(buf, Logging.Warn)
    with_logger(logger) do
        f()
    end
    String(take!(buf))
end

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

@testset "Submodule support" begin

    @testset "get_objects_from_module — non-recursive returns only own bindings and warns" begin
        # Should warn because Inner (which has documented bindings) is a submodule
        @test_logs (:warn, r"Inner") match_mode=:any begin
            bindings = get_objects_from_module(OuterMod)
            vars = binding_vars(bindings)

            # Outer module's own documented symbols
            @test :outer_func in vars
            @test :OuterType in vars

            # Inner symbols must NOT be present
            @test :inner_func ∉ vars
            @test :deep_func ∉ vars
        end
    end

    @testset "get_objects_from_module — EmptySub does not trigger warning" begin
        # OuterMod.EmptySub has no documented bindings and no submodules,
        # so no warning should be emitted.
        log_str = capture_warnings() do
            bindings = get_objects_from_module(OuterMod.EmptySub)
            @test isempty(bindings)
        end
        @test !occursin("recursive", log_str)
    end

    @testset "get_objects_from_module — recursive=true includes nested bindings" begin
        result_bindings = get_objects_from_module(OuterMod; recursive=true)
        vars = binding_vars(result_bindings)

        # All documented symbols across the hierarchy
        @test :outer_func in vars
        @test :OuterType in vars
        @test :inner_func in vars
        @test :deep_func in vars
        @test :shared_name in vars  # present (from both Inner and Deep)
    end

    @testset "get_objects_from_module — recursive=true fires collision warning" begin
        # Collision warning for shared_name (in both Inner and Deep)
        @test_logs (:warn, r"shared_name") match_mode=:any begin
            get_objects_from_module(OuterMod; recursive=true)
        end
    end

    @testset "get_objects_from_module — recursive=true does NOT fire skip warning" begin
        # When recursive=true we should NOT see the "Pass `recursive=true`" warning
        log_str = capture_warnings() do
            get_objects_from_module(OuterMod; recursive=true)
        end
        @test !occursin("Pass `recursive=true`", log_str)
    end

    @testset "autodocs_group — recursive=true includes inner symbols" begin
        group = autodocs_group(OuterMod; recursive=true)
        @test :inner_func in group.contents
        @test :deep_func in group.contents
        @test :outer_func in group.contents
    end

    @testset "auto_group_objects — recursive=true places inner symbols in groups" begin
        groups = auto_group_objects(OuterMod; recursive=true)
        # Flatten all symbols across all groups
        all_syms = reduce(vcat, [syms for (_, syms) in groups]; init=Symbol[])
        all_set = Set(all_syms)

        @test :inner_func in all_set
        @test :deep_func in all_set
        @test :outer_func in all_set
    end

    @testset "No infinite loop — test completes" begin
        # Just calling get_objects_from_module with recursive=true must terminate
        result = get_objects_from_module(OuterMod; recursive=true)
        @test result isa Vector
    end

end

# ---------------------------------------------------------------------------
# reference_page_names unit tests (FEATURE 2)
# ---------------------------------------------------------------------------

const QDB_SUB = QuartoDocBuilder

@testset "reference_page_names" begin

    @testset "unique names keep bare string(var)" begin
        bindings = QDB_SUB._documented_bindings(OuterMod.Inner.Deep; recursive=false)
        names = QDB_SUB.reference_page_names(bindings, OuterMod.Inner.Deep)
        # Deep has deep_func and shared_name, both unique within this set
        for b in bindings
            @test names[b] == string(b.var)
        end
    end

    @testset "collision qualifies non-root colliders, root keeps bare name" begin
        # Collect all documented bindings across the hierarchy
        bindings = QDB_SUB._documented_bindings(OuterMod; recursive=true)
        names = QDB_SUB.reference_page_names(bindings, OuterMod)

        # shared_name collides between Inner and Deep — both are non-root, so
        # both get qualified relative names.
        shared = [b for b in bindings if b.var == :shared_name]
        @test length(shared) == 2
        shared_names = Set(names[b] for b in shared)
        @test "Inner.shared_name" in shared_names
        @test "Inner.Deep.shared_name" in shared_names

        # Unique names stay bare.
        outer = first(b for b in bindings if b.var == :outer_func)
        @test names[outer] == "outer_func"
        inner = first(b for b in bindings if b.var == :inner_func)
        @test names[inner] == "inner_func"
        deep = first(b for b in bindings if b.var == :deep_func)
        @test names[deep] == "deep_func"
    end

end

# ---------------------------------------------------------------------------
# Build fixture for collision-safe page names (FEATURE 1 + 2 + 3)
# ---------------------------------------------------------------------------

module CollisionPkg

export foo

"""
    foo(x)

Outer foo. Mentions `unique_inner_fn` which lives in the submodule.
"""
foo(x) = x

module Inner

export unique_inner_fn

"""
    foo(x)

Inner foo — collides with CollisionPkg.foo.
"""
foo(x) = x + 1

"""
    unique_inner_fn(x)

A uniquely named function only in Inner.
"""
unique_inner_fn(x) = x * 3

end # module Inner

end # module CollisionPkg

@testset "Submodule site build (include_submodules)" begin

    @testset "include_submodules=true produces collision-safe pages" begin
        with_temp_project() do _
            write("README.md", "# CollisionPkg\n\nWelcome.\n")

            config = QuartoConfig(
                module_name = CollisionPkg,
                repo = "user/CollisionPkg.jl",
                comments = false,
                news = false,
                include_submodules = true
            )
            quarto_build_site(config)

            # Both colliding pages exist with distinct names.
            @test isfile("docs/reference/foo.qmd")
            @test isfile("docs/reference/Inner.foo.qmd")

            # The root-owned foo keeps the bare name; its page mentions unique_inner_fn.
            outer_page = read("docs/reference/foo.qmd", String)
            @test occursin("Outer foo", outer_page)

            inner_page = read("docs/reference/Inner.foo.qmd", String)
            @test occursin("Inner foo", inner_page)

            # Uniquely named submodule function gets a bare-named page.
            @test isfile("docs/reference/unique_inner_fn.qmd")
            unique_page = read("docs/reference/unique_inner_fn.qmd", String)
            @test occursin("uniquely named", unique_page)

            # The reference index page links to all three correctly.
            ref_page = read("docs/reference.qmd", String)
            @test occursin("reference/foo.qmd", ref_page)
            @test occursin("reference/Inner.foo.qmd", ref_page)
            @test occursin("reference/unique_inner_fn.qmd", ref_page)

            # Autolinking: outer foo's docstring mention of `unique_inner_fn`
            # resolves to its sibling page.
            @test occursin("[`unique_inner_fn`](./unique_inner_fn.qmd)", outer_page) ||
                  occursin("[`unique_inner_fn`](unique_inner_fn.qmd)", outer_page)

            # Inventory contains qualified names.
            @test isfile("docs/objects.inv")
            inv = QuartoDocBuilder.load_inventory("docs/objects.inv")
            names = [it.name for it in inv.items]
            @test "CollisionPkg.foo" in names
            @test "CollisionPkg.Inner.foo" in names
            @test "CollisionPkg.Inner.unique_inner_fn" in names

            # The inventory uri for the colliding inner foo points to the
            # collision-safe page name.
            inner_foo_item = inv.items[findfirst(it -> it.name == "CollisionPkg.Inner.foo", inv.items)]
            @test inner_foo_item.uri == "reference/Inner.foo.html#sec-doc"
        end
    end

    @testset "include_submodules=false (default) only outer pages" begin
        with_temp_project() do _
            write("README.md", "# CollisionPkg\n\nWelcome.\n")

            config = QuartoConfig(
                module_name = CollisionPkg,
                repo = "user/CollisionPkg.jl",
                comments = false,
                news = false
            )
            quarto_build_site(config)

            # Only the outer foo page exists.
            @test isfile("docs/reference/foo.qmd")
            @test !isfile("docs/reference/Inner.foo.qmd")
            @test !isfile("docs/reference/unique_inner_fn.qmd")

            # Inventory only contains the outer binding.
            @test isfile("docs/objects.inv")
            inv = QuartoDocBuilder.load_inventory("docs/objects.inv")
            names = [it.name for it in inv.items]
            @test "CollisionPkg.foo" in names
            @test !("CollisionPkg.Inner.foo" in names)
            @test !("CollisionPkg.Inner.unique_inner_fn" in names)
        end
    end

end
