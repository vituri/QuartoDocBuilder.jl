# Auto-linking system for QuartoDocBuilder.jl
# Converts function references to clickable links

"""
    ReferenceIndex

Index of function names to their documentation URLs.
"""
struct ReferenceIndex
    entries::Dict{String, String}  # function_name => url
    module_name::Union{Module, Nothing}
end

function _reference_name(item)
    if item isa Base.Docs.Binding
        return string(item.var)
    elseif item isa Symbol
        return string(item)
    end
    return string(item)
end

"""
    build_reference_index(module_name::Module; base_path::String="reference", recursive::Bool=false) -> ReferenceIndex

Build a lookup table mapping function names to their reference page URLs.

# Arguments
- `module_name::Module`: Module to index
- `base_path::String`: Base path for reference pages (default: "reference")
- `recursive::Bool`: When `true`, include documented bindings from submodules
  and use the collision-safe page names from [`reference_page_names`](@ref) so
  that autolink targets match the actual generated files. Entries are keyed by
  the collision-safe page name and, when that bare name is unambiguous, also by
  the bare name — so both `` `Inner.foo` `` and an unambiguous `` `bar` ``
  mention autolink (default: `false`).

# Returns
A ReferenceIndex with all documented symbols.

# Example
```julia
index = build_reference_index(MyModule)
index.entries["my_function"]  # "reference/my_function.qmd"
```
"""
function build_reference_index(module_name::Module; base_path::String="reference", recursive::Bool=false)
    entries = Dict{String, String}()

    if recursive
        bindings = _documented_bindings(module_name; recursive=true)
        page_names = reference_page_names(bindings, module_name)
        for b in bindings
            page = page_names[b]
            url = "$base_path/$page.qmd"
            # Key by the (possibly qualified) page name, e.g. "Inner.foo".
            entries[page] = url
            # Also key by the bare name when it is unambiguous (the page name
            # equals the bare name only for non-colliding bindings).
            bare = string(b.var)
            if page == bare
                entries[bare] = url
            end
        end
    else
        for (sym, _) in Base.Docs.meta(module_name)
            name = _reference_name(sym)
            url = "$base_path/$name.qmd"
            entries[name] = url
        end
    end

    ReferenceIndex(entries, module_name)
end

"""
    autolink_references(text::String, index::ReferenceIndex) -> String

Convert function references in backticks to hyperlinks.

Patterns matched:
- `` `function_name()` `` -> `[function_name()](reference/function_name.qmd)`
- `` `function_name` `` -> `[function_name](reference/function_name.qmd)` (if in index)

# Arguments
- `text::String`: Text containing references
- `index::ReferenceIndex`: Reference index for lookups

# Returns
Text with references converted to markdown links.

# Example
```julia
index = build_reference_index(MyModule)
text = "Use `my_function()` to process data."
autolink_references(text, index)
# "Use [`my_function()`](reference/my_function.qmd) to process data."
```
"""
function autolink_references(text::String, index::ReferenceIndex)
    pattern = r"`([A-Za-z_][\w\.]*)(\(\))?`"
    replace(text, pattern => function(token)
        m = match(pattern, token)
        m === nothing && return token

        name = m.captures[1]
        suffix = m.captures[2] === nothing ? "" : m.captures[2]
        url = resolve_reference(name * suffix, index)

        url === nothing ? token : "[`$(name)$(suffix)`]($url)"
    end)
end

"""
    autolink_references(text::String, module_name::Module) -> String

Convenience method that builds the index automatically.

# Arguments
- `text::String`: Text containing references
- `module_name::Module`: Module to use for reference lookups
"""
function autolink_references(text::String, module_name::Module)
    index = build_reference_index(module_name)
    autolink_references(text, index)
end

"""
    autolink_cross_package(text::String, packages::Dict{String, ReferenceIndex}) -> String

Link references to multiple packages.

# Arguments
- `text::String`: Text containing references
- `packages::Dict{String, ReferenceIndex}`: Map of package names to their indices

# Example
```julia
packages = Dict(
    "Base" => build_reference_index(Base),
    "MyPkg" => build_reference_index(MyPkg)
)
autolink_cross_package(text, packages)
```
"""
function autolink_cross_package(text::String, packages::Dict{String, ReferenceIndex})
    result = text

    for (_, index) in packages
        result = autolink_references(result, index)
    end

    result
end

"""
    resolve_reference(name::String, index::ReferenceIndex) -> Union{String, Nothing}

Resolve a function name to its documentation URL.

# Arguments
- `name::String`: Function name to look up
- `index::ReferenceIndex`: Reference index

# Returns
URL string if found, `nothing` otherwise.
"""
function resolve_reference(name::String, index::ReferenceIndex)
    clean_name = replace(name, r"\(\)$" => "")

    for candidate in (clean_name, split(clean_name, ".")[end])
        if haskey(index.entries, candidate)
            return index.entries[candidate]
        end
    end

    nothing
end

"""
    find_undefined_references(text::String, index::ReferenceIndex) -> Vector{String}

Find all backtick-quoted identifiers that don't have documentation.
Useful for identifying missing documentation.

# Arguments
- `text::String`: Text to scan
- `index::ReferenceIndex`: Reference index

# Returns
Vector of undefined reference names.
"""
function find_undefined_references(text::String, index::ReferenceIndex)
    undefined = String[]
    pattern = r"`([A-Za-z_][\w\.]*)(?:\(\))?`"

    # Find all backtick-quoted identifiers
    for m in eachmatch(pattern, text)
        name = m.captures[1]
        if resolve_reference(name, index) === nothing && !(name in undefined)
            push!(undefined, name)
        end
    end

    undefined
end

"""
    create_reference_report(module_name::Module) -> String

Generate a report of all documented functions and their reference URLs.

# Arguments
- `module_name::Module`: Module to analyze

# Returns
Markdown-formatted report.
"""
function create_reference_report(module_name::Module)
    index = build_reference_index(module_name)

    report = "# Reference Index Report\n\n"
    report *= "Module: `$(module_name)`\n\n"
    report *= "| Function | URL |\n"
    report *= "|----------|-----|\n"

    for (name, url) in sort(collect(index.entries))
        report *= "| `$name` | $url |\n"
    end

    report *= "\nTotal: $(length(index.entries)) documented items.\n"

    report
end

"""
    link_julia_docs(text::String) -> String

Add links to Julia Base documentation for common types and functions.

Links to https://docs.julialang.org for:
- Common types: String, Int, Float64, Vector, Dict, etc.
- Common functions: map, filter, reduce, etc.

# Arguments
- `text::String`: Text to process

# Returns
Text with Julia standard library links added.
"""
function link_julia_docs(text::String)
    # Map of common Julia types/functions to their doc pages
    julia_refs = Dict(
        "String" => "https://docs.julialang.org/en/v1/base/strings/#Core.String",
        "Int" => "https://docs.julialang.org/en/v1/base/numbers/#Core.Int",
        "Float64" => "https://docs.julialang.org/en/v1/base/numbers/#Core.Float64",
        "Bool" => "https://docs.julialang.org/en/v1/base/numbers/#Core.Bool",
        "Vector" => "https://docs.julialang.org/en/v1/base/arrays/#Base.Vector",
        "Dict" => "https://docs.julialang.org/en/v1/base/collections/#Base.Dict",
        "Array" => "https://docs.julialang.org/en/v1/base/arrays/#Core.Array",
        "Tuple" => "https://docs.julialang.org/en/v1/base/base/#Core.Tuple",
        "Nothing" => "https://docs.julialang.org/en/v1/base/constants/#Core.nothing",
        "Symbol" => "https://docs.julialang.org/en/v1/base/base/#Core.Symbol",
        "Function" => "https://docs.julialang.org/en/v1/base/base/#Core.Function",
        "Module" => "https://docs.julialang.org/en/v1/base/base/#Core.Module",
    )

    result = text

    for (name, url) in julia_refs
        # Only link if it appears in backticks and isn't already a link
        pattern = Regex("`($name)`(?!\\])")
        result = replace(result, pattern => SubstitutionString("[`\\1`]($url)"))
    end

    result
end
# ============================================================================
# External Cross-References (like Documenter.jl's @extref)
# ============================================================================

"""
    ExternalDocsRegistry

Registry of external package documentation.

Stores, per package, a base URL plus an optional Sphinx [`Inventory`](@ref)
loaded from that site's `objects.inv`. The inventory is what enables
*correct* cross-package linking: references resolve to real URLs published
by the upstream docs rather than fabricated, Documenter-specific paths.

# Fields
- `packages::Dict{String, String}`: package name => base URL.
- `inventories::Dict{String, Inventory}`: package name => loaded inventory
  (only present for packages whose `objects.inv` was successfully loaded).
"""
struct ExternalDocsRegistry
    packages::Dict{String, String}        # package_name => base_url
    inventories::Dict{String, Inventory}  # package_name => inventory
end

"""
    ExternalDocsRegistry() -> ExternalDocsRegistry

Create an empty external docs registry.
"""
ExternalDocsRegistry() = ExternalDocsRegistry(Dict{String, String}(), Dict{String, Inventory}())

# Global registry for convenience
const EXTERNAL_DOCS = Ref{ExternalDocsRegistry}(ExternalDocsRegistry())

"""
    register_external_docs(package::String, base_url::String;
                           inventory=nothing, registry=EXTERNAL_DOCS[])

Register an external package's documentation for cross-referencing.

The `base_url` is stored, and an [`Inventory`](@ref) is associated with the
package so that references can be resolved to real URLs:

- If `inventory` is an [`Inventory`](@ref), it is used directly.
- If `inventory` is a `String`, it is treated as a path/URL to an
  `objects.inv` and loaded.
- If `inventory` is `nothing` (the default), this attempts to load
  `"\$base_url/objects.inv"`. Network/parse failures are caught and degrade
  gracefully to "no inventory" (the package is still registered, but its
  references will not resolve until an inventory is available).

# Arguments
- `package::String`: Package name (e.g., "DataFrames").
- `base_url::String`: Base URL for the package docs
  (e.g., "https://dataframes.juliadata.org/stable").
- `inventory`: An `Inventory`, a path/URL string, or `nothing` (default).
- `registry`: Registry to add to (default: global registry).

# Example
```julia
register_external_docs("DataFrames", "https://dataframes.juliadata.org/stable")
register_external_docs("Plots", "https://docs.juliaplots.org/stable")
```
"""
function register_external_docs(package::String, base_url::String;
                                inventory=nothing,
                                registry::ExternalDocsRegistry=EXTERNAL_DOCS[])
    # Ensure URL doesn't end with /
    url = rstrip(base_url, '/')
    registry.packages[package] = String(url)

    if inventory isa Inventory
        registry.inventories[package] = inventory
    elseif inventory isa AbstractString
        try
            registry.inventories[package] = load_inventory(String(inventory); root_url = url)
        catch err
            @warn "Could not load inventory for $package from $inventory" exception=err
        end
    elseif inventory === nothing
        # Best-effort: try the conventional objects.inv at the docs root.
        try
            registry.inventories[package] = load_inventory("$(url)/objects.inv")
        catch
            # Network may be unavailable / no inventory published. Degrade
            # gracefully: keep the base URL but no inventory.
        end
    end

    @info "Registered external docs: $package => $url" *
          (haskey(registry.inventories, package) ? " (inventory loaded)" : " (no inventory)")
end

"""
    get_external_docs_url(package::String; registry=EXTERNAL_DOCS[]) -> Union{String, Nothing}

Get the base documentation URL for an external package.

# Arguments
- `package::String`: Package name
- `registry`: Registry to search (default: global registry)

# Returns
Base URL string if registered, `nothing` otherwise.
"""
function get_external_docs_url(package::String; registry::ExternalDocsRegistry=EXTERNAL_DOCS[])
    get(registry.packages, package, nothing)
end

"""
    clear_external_docs(; registry=EXTERNAL_DOCS[])

Clear all registered external documentation URLs and inventories.
"""
function clear_external_docs(; registry::ExternalDocsRegistry=EXTERNAL_DOCS[])
    empty!(registry.packages)
    empty!(registry.inventories)
end

"""
    list_external_docs(; registry=EXTERNAL_DOCS[]) -> Dict{String, String}

List all registered external documentation URLs.
"""
function list_external_docs(; registry::ExternalDocsRegistry=EXTERNAL_DOCS[])
    copy(registry.packages)
end

# Pre-registered common Julia packages
const COMMON_JULIA_PACKAGES = Dict{String, String}(
    "DataFrames" => "https://dataframes.juliadata.org/stable",
    "Plots" => "https://docs.juliaplots.org/stable",
    "Makie" => "https://docs.makie.org/stable",
    "Flux" => "https://fluxml.ai/Flux.jl/stable",
    "DifferentialEquations" => "https://docs.sciml.ai/DiffEqDocs/stable",
    "JuMP" => "https://jump.dev/JuMP.jl/stable",
    "CSV" => "https://csv.juliadata.org/stable",
    "HTTP" => "https://juliaweb.github.io/HTTP.jl/stable",
    "JSON" => "https://juliahub.com/docs/JSON/",
    "Distributions" => "https://juliastats.org/Distributions.jl/stable",
    "StatsBase" => "https://juliastats.org/StatsBase.jl/stable",
    "LinearAlgebra" => "https://docs.julialang.org/en/v1/stdlib/LinearAlgebra/",
    "Random" => "https://docs.julialang.org/en/v1/stdlib/Random/",
    "Dates" => "https://docs.julialang.org/en/v1/stdlib/Dates/",
    "Test" => "https://docs.julialang.org/en/v1/stdlib/Test/",
)

"""
    register_common_packages(; load_inventories::Bool=false, registry=EXTERNAL_DOCS[])

Register common Julia packages with their documentation URLs.
Includes DataFrames, Plots, Makie, Flux, JuMP, and more.

By default this only records base URLs and performs **no** network access;
references will resolve only once an inventory is available. Pass
`load_inventories=true` to additionally attempt to fetch each package's
`objects.inv` (each fetch is wrapped in its own try/catch and failures are
skipped, so this degrades gracefully when offline).

# Example
```julia
register_common_packages()                      # offline, URLs only
register_common_packages(load_inventories=true) # also fetch inventories
```
"""
function register_common_packages(; load_inventories::Bool=false,
                                   registry::ExternalDocsRegistry=EXTERNAL_DOCS[])
    for (pkg, url) in COMMON_JULIA_PACKAGES
        registry.packages[pkg] = url
        if load_inventories
            try
                registry.inventories[pkg] = load_inventory("$(url)/objects.inv")
            catch
                # No inventory available / offline: skip this package.
            end
        end
    end
    @info "Registered $(length(COMMON_JULIA_PACKAGES)) common Julia packages" *
          (load_inventories ? " ($(length(registry.inventories)) inventories loaded)" : "")
end

"""
    autolink_external(text::String; registry=EXTERNAL_DOCS[]) -> String

Add links to external package documentation, resolving every reference
through the package's Sphinx [`Inventory`](@ref).

Only references that resolve through a loaded inventory are linked; if a
package has no inventory, its references are left untouched. URLs are never
fabricated.

# Arguments
- `text::String`: Text to process
- `registry`: External docs registry to use

# Returns
Text with inventory-resolved external package links added.

# Note
External references are detected by patterns like:
- `PackageName.function_name`
- `PackageName.TypeName`
"""
function autolink_external(text::String; registry::ExternalDocsRegistry=EXTERNAL_DOCS[])
    result = text

    for (pkg, _) in registry.packages
        # Only packages with a loaded inventory can produce links.
        haskey(registry.inventories, pkg) || continue

        # Pattern: `PackageName.something`
        pattern = Regex("`($pkg\\.(\\w+))`")
        result = replace(result, pattern => function(m)
            full_match = match(pattern, m)
            if full_match !== nothing
                full_ref = full_match.captures[1]
                url = resolve_external_ref(ExternalRef(pkg, full_match.captures[2]);
                                           registry = registry)
                url === nothing && return m
                return "[`$full_ref`]($url)"
            end
            return m
        end)
    end

    result
end

"""
    ExternalRef(package::String, symbol::String)

Represents a reference to an external package's documentation.
"""
struct ExternalRef
    package::String
    symbol::String
end

"""
    parse_external_ref(ref::String) -> Union{ExternalRef, Nothing}

Parse an external reference string like "DataFrames.DataFrame".

# Returns
ExternalRef if valid, `nothing` otherwise.
"""
function parse_external_ref(ref::String)
    m = match(r"^(\w+)\.(\w+)$", ref)
    if m !== nothing
        return ExternalRef(m.captures[1], m.captures[2])
    end
    nothing
end

"""
    resolve_external_ref(ref::ExternalRef; registry=EXTERNAL_DOCS[]) -> Union{String, Nothing}

Resolve an external reference to its documentation URL using the package's
Sphinx [`Inventory`](@ref).

# Arguments
- `ref::ExternalRef`: External reference to resolve
- `registry`: External docs registry to use

# Returns
The full URL if the package has a loaded inventory containing the symbol,
`nothing` otherwise. URLs are never fabricated: a registered package without
an inventory (or one whose inventory lacks the symbol) yields `nothing`.
"""
function resolve_external_ref(ref::ExternalRef; registry::ExternalDocsRegistry=EXTERNAL_DOCS[])
    inv = get(registry.inventories, ref.package, nothing)
    inv === nothing && return nothing

    # Try fully-qualified "Package.symbol" first, then the bare symbol
    # (resolve_inventory itself also performs a bare-name fallback).
    url = resolve_inventory(inv, "$(ref.package).$(ref.symbol)")
    url === nothing && (url = resolve_inventory(inv, ref.symbol))
    return url
end
