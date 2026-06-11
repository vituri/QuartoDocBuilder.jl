# Tests for the Sphinx objects.inv inventory support and the
# inventory-aware external cross-referencing in autolink.jl.
#
# Self-contained: no network access. Public symbols are accessed via the
# `QuartoDocBuilder.` prefix so these tests do not depend on exports.

using Test
using QuartoDocBuilder

const QDB = QuartoDocBuilder

# A small sample module with one documented function, one documented type,
# and one undocumented function, used by generate_inventory tests.
module InventorySampleModule
export sample_function, SampleType

"""
    sample_function(x)

Return `x * 2`.
"""
sample_function(x) = x * 2

"""
    SampleType

A documented sample type.
"""
struct SampleType
    value::Int
end

undocumented_helper() = nothing
end

@testset "Inventory" begin

    @testset "round-trip write/load preserves data and resolves URLs" begin
        items = [
            QDB.InventoryItem("SamplePkg.foo", "jl", "function", 1,
                              "reference/foo.html#sec-doc"),
            # uri "$" compression: expands to the item name at lookup time
            QDB.InventoryItem("SamplePkg.Bar", "jl", "type", 1, "\$"),
            # explicit dispname (not the "-" sentinel)
            QDB.InventoryItem("SamplePkg.baz", "jl", "function", 1,
                              "reference/baz.html#sec-doc"; dispname = "baz!"),
        ]
        inv = QDB.Inventory("SamplePkg", "1.2.3", items;
                            root_url = "https://example.com/SamplePkg/stable")

        mktempdir() do dir
            path = joinpath(dir, "objects.inv")
            QDB.write_inventory(inv, path)
            @test isfile(path)

            loaded = QDB.load_inventory(path;
                root_url = "https://example.com/SamplePkg/stable")

            @test loaded.project == "SamplePkg"
            @test loaded.version == "1.2.3"
            @test length(loaded.items) == length(items)

            # Resolution produces correct full URLs.
            @test QDB.resolve_inventory(loaded, "SamplePkg.foo") ==
                  "https://example.com/SamplePkg/stable/reference/foo.html#sec-doc"

            # "$" uri compression expands to the item name.
            @test QDB.resolve_inventory(loaded, "SamplePkg.Bar") ==
                  "https://example.com/SamplePkg/stable/SamplePkg.Bar"

            # dispname survived the round-trip.
            baz_idx = findfirst(it -> it.name == "SamplePkg.baz", loaded.items)
            @test baz_idx !== nothing
            @test loaded.items[baz_idx].dispname == "baz!"

            # bare-name fallback resolves "foo" -> "SamplePkg.foo".
            @test QDB.resolve_inventory(loaded, "foo") ==
                  "https://example.com/SamplePkg/stable/reference/foo.html#sec-doc"

            # unknown name resolves to nothing.
            @test QDB.resolve_inventory(loaded, "does_not_exist") === nothing
        end
    end

    @testset "file header is exactly the four expected lines" begin
        inv = QDB.Inventory("HdrPkg", "0.1.0",
            [QDB.InventoryItem("HdrPkg.x", "jl", "function", 1, "reference/x.html#sec-doc")])

        mktempdir() do dir
            path = joinpath(dir, "objects.inv")
            QDB.write_inventory(inv, path)

            raw = read(path)

            expected_header = string(
                "# Sphinx inventory version 2\n",
                "# Project: HdrPkg\n",
                "# Version: 0.1.0\n",
                "# The remainder of this file is compressed using zlib.\n",
            )
            header_nbytes = ncodeunits(expected_header)

            # Header bytes are exactly the four expected lines.
            @test raw[1:header_nbytes] == codeunits(expected_header)

            # Body after the header is genuinely zlib-compressed: it is not
            # plain text, and zlib streams begin with the 0x78 magic byte.
            body = raw[header_nbytes+1:end]
            @test !isempty(body)
            @test body[1] == 0x78  # zlib magic
            # The body should NOT contain the readable name as plain ASCII.
            @test !occursin("HdrPkg.x", String(copy(body)))
        end
    end

    @testset "generate_inventory builds items for documented bindings" begin
        inv = QDB.generate_inventory(InventorySampleModule;
            base_url = "https://example.com/InventorySampleModule/stable")

        @test inv.project == "InventorySampleModule"

        names = [it.name for it in inv.items]
        @test "InventorySampleModule.sample_function" in names
        @test "InventorySampleModule.SampleType" in names
        # Undocumented helper must not appear.
        @test !any(occursin("undocumented_helper", n) for n in names)

        func_item = inv.items[findfirst(it -> it.name == "InventorySampleModule.sample_function", inv.items)]
        @test func_item.role == "function"
        @test func_item.domain == "jl"
        @test func_item.priority == 1
        @test func_item.uri == "reference/sample_function.html#sec-doc"

        type_item = inv.items[findfirst(it -> it.name == "InventorySampleModule.SampleType", inv.items)]
        @test type_item.role == "type"
        @test type_item.uri == "reference/SampleType.html#sec-doc"

        # Resolution against the generated inventory yields the full URL.
        @test QDB.resolve_inventory(inv, "InventorySampleModule.sample_function") ==
              "https://example.com/InventorySampleModule/stable/reference/sample_function.html#sec-doc"
    end

    @testset "resolve_external_ref returns nothing without an inventory" begin
        reg = QDB.ExternalDocsRegistry()

        # Unregistered package: nothing (and definitely no "/lib/types/").
        ref = QDB.ExternalRef("Unregistered", "Thing")
        result = QDB.resolve_external_ref(ref; registry = reg)
        @test result === nothing

        # Registered WITHOUT an inventory: still nothing, no fabricated URL.
        QDB.register_external_docs("NoInvPkg", "https://example.com/NoInvPkg";
            inventory = QDB.Inventory("noop", "", QDB.InventoryItem[]),
            registry = reg)
        # Wipe the inventory to simulate "registered, no inventory loaded".
        delete!(reg.inventories, "NoInvPkg")

        ref2 = QDB.ExternalRef("NoInvPkg", "SomeType")
        result2 = QDB.resolve_external_ref(ref2; registry = reg)
        @test result2 === nothing
        @test !(result2 isa AbstractString && occursin("/lib/types/", result2))
    end

    @testset "autolink_external links via an in-memory inventory" begin
        reg = QDB.ExternalDocsRegistry()

        inv = QDB.Inventory("SamplePkg", "1.0.0",
            [QDB.InventoryItem("SamplePkg.foo", "jl", "function", 1,
                               "reference/foo.html#sec-doc")];
            root_url = "https://example.com/SamplePkg/stable")

        QDB.register_external_docs("SamplePkg", "https://example.com/SamplePkg/stable";
            inventory = inv, registry = reg)

        linked = QDB.autolink_external("Use `SamplePkg.foo` here."; registry = reg)
        @test occursin(
            "[`SamplePkg.foo`](https://example.com/SamplePkg/stable/reference/foo.html#sec-doc)",
            linked)

        # A symbol not in the inventory is left untouched (no fabricated link).
        untouched = QDB.autolink_external("Use `SamplePkg.bar` here."; registry = reg)
        @test occursin("`SamplePkg.bar`", untouched)
        @test !occursin("](https://example.com/SamplePkg/stable/lib/types/", untouched)
    end

end
