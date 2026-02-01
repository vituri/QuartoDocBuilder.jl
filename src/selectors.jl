# Content selection helpers for QuartoDocBuilder.jl
# Provides pkgdown-style selectors for organizing reference pages

"""
    starts_with(prefix::String) -> Function

Create a selector that matches symbols starting with `prefix`.

# Example
```julia
# Match functions like `process_data`, `process_file`
selector = starts_with("process_")
selector(:process_data)  # true
selector(:other_func)    # false
```
"""
starts_with(prefix::String) = sym -> startswith(string(sym), prefix)

"""
    ends_with(suffix::String) -> Function

Create a selector that matches symbols ending with `suffix`.

# Example
```julia
# Match functions like `my_util`, `string_util`
selector = ends_with("_util")
selector(:my_util)      # true
selector(:util_helper)  # false
```
"""
ends_with(suffix::String) = sym -> endswith(string(sym), suffix)

"""
    matches(pattern::Union{String, Regex}) -> Function

Create a selector that matches symbols against a regex pattern.

# Example
```julia
# Match functions starting with "get" or "set"
selector = matches(r"^(get|set)")
selector(:get_value)  # true
selector(:set_value)  # true
selector(:update)     # false
```
"""
function matches(pattern::Union{String, Regex})
    rx = pattern isa String ? Regex(pattern) : pattern
    sym -> occursin(rx, string(sym))
end

"""
    contains(substring::String) -> Function

Create a selector that matches symbols containing `substring`.

# Example
```julia
# Match functions containing "helper"
selector = contains("helper")
selector(:my_helper_func)  # true
selector(:other_func)      # false
```
"""
contains(substring::String) = sym -> occursin(substring, string(sym))

"""
    has_docstring(module_name::Module) -> Function

Create a selector that matches symbols with documentation.

# Example
```julia
selector = has_docstring(MyModule)
selector(:documented_func)    # true if has docstring
selector(:undocumented_func)  # false
```
"""
function has_docstring(module_name::Module)
    documented = Set(k for (k, v) in Base.Docs.meta(module_name))
    sym -> sym in documented
end

"""
    is_exported(module_name::Module) -> Function

Create a selector that matches exported symbols.

# Example
```julia
selector = is_exported(MyModule)
selector(:exported_func)    # true if exported
selector(:internal_func)    # false
```
"""
function is_exported(module_name::Module)
    exported = Set(names(module_name))
    sym -> sym in exported
end

"""
    is_function_symbol(module_name::Module) -> Function

Create a selector that matches function symbols.
"""
function is_function_symbol(module_name::Module)
    sym -> begin
        try
            obj = getfield(module_name, sym)
            return obj isa Function
        catch
            return false
        end
    end
end

"""
    is_type_symbol(module_name::Module) -> Function

Create a selector that matches type/struct symbols.
"""
function is_type_symbol(module_name::Module)
    sym -> begin
        try
            obj = getfield(module_name, sym)
            return obj isa Type
        catch
            return false
        end
    end
end

"""
    is_const_symbol(module_name::Module) -> Function

Create a selector that matches constant symbols.
"""
function is_const_symbol(module_name::Module)
    sym -> begin
        try
            obj = getfield(module_name, sym)
            return !(obj isa Function) && !(obj isa Type) && !(obj isa Module)
        catch
            return false
        end
    end
end

"""
    parse_content_selector(s::String) -> Union{Symbol, Function}

Parse a content selector string into a selector function or symbol.

Supported formats:
- `"function_name"` -> Symbol(:function_name)
- `"starts_with:prefix"` -> starts_with("prefix")
- `"ends_with:suffix"` -> ends_with("suffix")
- `"matches:pattern"` -> matches("pattern")
- `"contains:substring"` -> contains("substring")

# Example
```julia
sel = parse_content_selector("starts_with:process_")
sel(:process_data)  # true

sym = parse_content_selector("my_function")
sym  # :my_function
```
"""
function parse_content_selector(s::String)
    if occursin(":", s)
        parts = split(s, ":", limit=2)
        selector_type, arg = parts[1], parts[2]

        if selector_type == "starts_with"
            return starts_with(arg)
        elseif selector_type == "ends_with"
            return ends_with(arg)
        elseif selector_type == "matches"
            return matches(arg)
        elseif selector_type == "contains"
            return contains(arg)
        else
            @warn "Unknown selector type: $selector_type. Treating as symbol."
            return Symbol(s)
        end
    end
    # Plain symbol name
    return Symbol(s)
end

"""
    apply_selector(selector, symbols::Vector{Symbol}) -> Vector{Symbol}

Apply a selector to filter a vector of symbols.

# Arguments
- `selector`: A Symbol, Function, or String
- `symbols::Vector{Symbol}`: Symbols to filter

# Returns
Vector of symbols that match the selector.
"""
function apply_selector(selector, symbols::Vector{Symbol})
    if selector isa Symbol
        return selector in symbols ? [selector] : Symbol[]
    elseif selector isa Function
        return filter(selector, symbols)
    elseif selector isa String
        parsed = parse_content_selector(selector)
        return apply_selector(parsed, symbols)
    else
        return Symbol[]
    end
end

"""
    filter_objects(module_name::Module, selectors::Vector) -> Vector{Symbol}

Filter module objects using a list of selectors.
Applies selectors in order and returns unique matches.

# Arguments
- `module_name::Module`: Module to get symbols from
- `selectors::Vector`: List of selectors (Symbols, Functions, or Strings)

# Example
```julia
# Get all functions starting with "process_" or ending with "_util"
symbols = filter_objects(MyModule, [starts_with("process_"), ends_with("_util")])
```
"""
function filter_objects(module_name::Module, selectors::Vector)
    # Get all documented symbols (extract .var from Binding objects)
    all_symbols = Symbol[k.var for (k, _) in Base.Docs.meta(module_name)]

    result = Symbol[]
    for sel in selectors
        matches = apply_selector(sel, all_symbols)
        append!(result, matches)
    end

    unique(result)
end

"""
    group_objects(module_name::Module, groups::Vector{ReferenceGroup}) -> Vector{Tuple{ReferenceGroup, Vector{Symbol}}}

Group module objects according to ReferenceGroup specifications.
Returns a vector of (group, symbols) pairs.

# Arguments
- `module_name::Module`: Module to get symbols from
- `groups::Vector{ReferenceGroup}`: Group specifications

# Returns
Vector of tuples, each containing a ReferenceGroup and its matched symbols.
"""
function group_objects(module_name::Module, groups::Vector{ReferenceGroup})
    # Get all documented symbols (extract .var from Binding objects)
    all_symbols = Symbol[k.var for (k, _) in Base.Docs.meta(module_name)]
    used_symbols = Set{Symbol}()

    result = Tuple{ReferenceGroup, Vector{Symbol}}[]

    for group in groups
        group_symbols = Symbol[]

        for sel in group.contents
            matches = apply_selector(sel, all_symbols)
            for sym in matches
                if !(sym in used_symbols)
                    push!(group_symbols, sym)
                    push!(used_symbols, sym)
                end
            end
        end

        # Sort alphabetically within each group
        sort!(group_symbols)
        push!(result, (group, group_symbols))
    end

    result
end

"""
    auto_group_objects(module_name::Module) -> Vector{Tuple{ReferenceGroup, Vector{Symbol}}}

Automatically group objects by type (functions, types, constants).
Used as fallback when no custom grouping is specified.

# Arguments
- `module_name::Module`: Module to analyze
"""
function auto_group_objects(module_name::Module)
    all_symbols = Symbol[k.var for (k, _) in Base.Docs.meta(module_name)]

    functions = Symbol[]
    types = Symbol[]
    constants = Symbol[]
    other = Symbol[]

    for sym in all_symbols
        try
            obj = getfield(module_name, sym)
            if obj isa Function
                push!(functions, sym)
            elseif obj isa Type
                push!(types, sym)
            elseif obj isa Module
                continue  # Skip submodules
            else
                push!(constants, sym)
            end
        catch
            push!(other, sym)
        end
    end

    result = Tuple{ReferenceGroup, Vector{Symbol}}[]

    if !isempty(functions)
        sort!(functions)
        push!(result, (ReferenceGroup(title="Functions"), functions))
    end

    if !isempty(types)
        sort!(types)
        push!(result, (ReferenceGroup(title="Types"), types))
    end

    if !isempty(constants)
        sort!(constants)
        push!(result, (ReferenceGroup(title="Constants"), constants))
    end

    if !isempty(other)
        sort!(other)
        push!(result, (ReferenceGroup(title="Other"), other))
    end

    result
end

"""
    autodocs_group(module_name::Module; title::String="API Reference", desc::String="", filter=nothing) -> ReferenceGroup

Create a ReferenceGroup that automatically includes all documented symbols from a module.
Similar to Documenter.jl's @autodocs macro.

# Arguments
- `module_name::Module`: Module to document
- `title::String`: Group title (default: "API Reference")
- `desc::String`: Group description
- `filter`: Optional filter function (e.g., `is_exported(MyModule)`)

# Example
```julia
# Include all documented symbols
group = autodocs_group(MyModule)

# Include only exported, documented symbols
group = autodocs_group(MyModule;
    title="Public API",
    filter=is_exported(MyModule)
)

# Use in config
config = QuartoConfig(
    module_name = MyModule,
    reference = [autodocs_group(MyModule)]
)
```
"""
function autodocs_group(module_name::Module;
    title::String = "API Reference",
    desc::String = "",
    filter = nothing
)
    # Get all documented symbols
    all_symbols = Symbol[k.var for (k, _) in Base.Docs.meta(module_name)]

    # Apply filter if provided
    if filter !== nothing
        all_symbols = Base.filter(filter, all_symbols)
    end

    # Sort alphabetically
    sort!(all_symbols)

    ReferenceGroup(
        title = title,
        desc = desc,
        contents = all_symbols
    )
end

"""
    check_missing_docstrings(module_name::Module; exported_only::Bool=true, warn::Bool=true) -> Vector{Symbol}

Check for exported symbols that are missing documentation.
Returns a list of undocumented symbols.

# Arguments
- `module_name::Module`: Module to check
- `exported_only::Bool`: Only check exported symbols (default: true)
- `warn::Bool`: Print warnings for missing docstrings (default: true)

# Returns
Vector of symbols that are missing documentation.

# Example
```julia
# Check and warn about missing docstrings
missing = check_missing_docstrings(MyModule)

# Check without warnings
missing = check_missing_docstrings(MyModule; warn=false)

# Check all symbols, not just exported
missing = check_missing_docstrings(MyModule; exported_only=false)
```
"""
function check_missing_docstrings(module_name::Module;
    exported_only::Bool = true,
    warn::Bool = true
)
    # Get documented symbols
    documented = Set(k.var for (k, _) in Base.Docs.meta(module_name))

    # Get symbols to check
    if exported_only
        symbols_to_check = names(module_name)
    else
        symbols_to_check = names(module_name; all=true)
    end

    # Filter out internal symbols (starting with #)
    symbols_to_check = filter(s -> !startswith(string(s), "#"), symbols_to_check)

    # Filter out the module name itself
    symbols_to_check = filter(s -> s != nameof(module_name), symbols_to_check)

    # Find missing docstrings
    missing = Symbol[]
    for sym in symbols_to_check
        if !(sym in documented)
            push!(missing, sym)
            if warn
                @warn "Missing docstring for $(exported_only ? "exported " : "")symbol: $sym"
            end
        end
    end

    sort!(missing)
    return missing
end

"""
    documentation_coverage(module_name::Module; exported_only::Bool=true) -> NamedTuple

Calculate documentation coverage statistics for a module.

# Arguments
- `module_name::Module`: Module to analyze
- `exported_only::Bool`: Only consider exported symbols (default: true)

# Returns
NamedTuple with fields:
- `total::Int`: Total number of symbols
- `documented::Int`: Number of documented symbols
- `missing::Int`: Number of undocumented symbols
- `coverage::Float64`: Coverage percentage (0-100)
- `missing_symbols::Vector{Symbol}`: List of undocumented symbols

# Example
```julia
stats = documentation_coverage(MyModule)
println("Documentation coverage: \$(stats.coverage)%")
println("Missing: \$(stats.missing_symbols)")
```
"""
function documentation_coverage(module_name::Module; exported_only::Bool=true)
    # Get documented symbols
    documented_set = Set(k.var for (k, _) in Base.Docs.meta(module_name))

    # Get symbols to check
    if exported_only
        symbols_to_check = collect(names(module_name))
    else
        symbols_to_check = collect(names(module_name; all=true))
    end

    # Filter out internal symbols and module name
    symbols_to_check = filter(s -> !startswith(string(s), "#"), symbols_to_check)
    symbols_to_check = filter(s -> s != nameof(module_name), symbols_to_check)

    total = length(symbols_to_check)
    documented = count(s -> s in documented_set, symbols_to_check)
    missing_syms = filter(s -> !(s in documented_set), symbols_to_check)

    coverage = total > 0 ? (documented / total) * 100 : 100.0

    return (
        total = total,
        documented = documented,
        missing = length(missing_syms),
        coverage = round(coverage; digits=1),
        missing_symbols = sort(missing_syms)
    )
end
