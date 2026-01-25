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

"""
    build_reference_index(module_name::Module; base_path::String="reference") -> ReferenceIndex

Build a lookup table mapping function names to their reference page URLs.

# Arguments
- `module_name::Module`: Module to index
- `base_path::String`: Base path for reference pages (default: "reference")

# Returns
A ReferenceIndex with all documented symbols.

# Example
```julia
index = build_reference_index(MyModule)
index.entries["my_function"]  # "reference/my_function.qmd"
```
"""
function build_reference_index(module_name::Module; base_path::String="reference")
    entries = Dict{String, String}()

    for (sym, _) in Base.Docs.meta(module_name)
        name = string(sym)
        url = "$base_path/$name.qmd"
        entries[name] = url
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
    result = text

    # Pattern for function calls with parentheses: `func_name()`
    # This is the most common pattern in docstrings
    result = replace(result, r"`(\w+)\(\)`" => function(m)
        func_match = match(r"`(\w+)\(\)`", m)
        if func_match === nothing
            return m
        end
        func_name = func_match.captures[1]
        if haskey(index.entries, func_name)
            return "[`$func_name()`]($(index.entries[func_name]))"
        else
            return m
        end
    end)

    # Pattern for identifiers without parentheses: `func_name`
    # Only link if it's in our index (to avoid linking random words)
    result = replace(result, r"`(\w+)`" => function(m)
        # Skip if already a link
        if occursin("]($m", result)
            return m
        end
        func_match = match(r"`(\w+)`", m)
        if func_match === nothing
            return m
        end
        func_name = func_match.captures[1]
        if haskey(index.entries, func_name)
            return "[`$func_name`]($(index.entries[func_name]))"
        else
            return m
        end
    end)

    result
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
    # Try exact match first
    if haskey(index.entries, name)
        return index.entries[name]
    end

    # Try without trailing parentheses
    clean_name = replace(name, r"\(\)$" => "")
    if haskey(index.entries, clean_name)
        return index.entries[clean_name]
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

    # Find all backtick-quoted identifiers
    for m in eachmatch(r"`(\w+)(?:\(\))?`", text)
        name = m.captures[1]
        if !haskey(index.entries, name) && !(name in undefined)
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
