# Content selection helpers for QuartoDocBuilder.jl
# Provides pkgdown-style selectors for organizing reference pages

# ============================================================================
# Shared helpers for collecting documented bindings across (sub)modules
# ============================================================================

"""
    _documented_bindings(m::Module; recursive::Bool=false) -> Vector{Base.Docs.Binding}

Return the `Base.Docs.Binding` keys from `Base.Docs.meta(m)`.

When `recursive=true`, descend into direct submodules of `m` (depth-first),
collecting their documented bindings as well.  A submodule `s` is a symbol in
`names(m; all=true)` such that:
- `isdefined(m, s)` is true,
- `getfield(m, s) isa Module`,
- `getfield(m, s) !== m` (not self-referential),
- `parentmodule(getfield(m, s)) === m` (owned by `m`, not re-exported from elsewhere).

A `seen::Set{Module}` guard prevents cycles.

**Warnings emitted (only from the top-level call, not on recursive descent):**
- When `recursive=false` and at least one direct submodule has documented
  bindings, a single `@warn` is emitted listing those submodules and advising
  the caller to pass `recursive=true`.
- When `recursive=true` and two or more bindings share the same `.var` name
  (e.g. `A.foo` and `A.Sub.foo`), a single `@warn` lists the colliding names
  so the user is aware that page generation may overwrite files.
"""
function _documented_bindings(m::Module; recursive::Bool=false)
    seen = Set{Module}()
    _documented_bindings_impl(m, recursive, seen, true)
end

# Internal recursive implementation.
# `toplevel` is true only for the initial call so that warnings are emitted
# exactly once.
function _documented_bindings_impl(
    m::Module,
    recursive::Bool,
    seen::Set{Module},
    toplevel::Bool,
)
    push!(seen, m)

    # Own bindings
    own = Base.Docs.Binding[k for (k, _) in Base.Docs.meta(m)]

    # Identify direct submodules
    direct_submods = Module[]
    for s in names(m; all=true)
        isdefined(m, s) || continue
        child = getfield(m, s)
        child isa Module || continue
        child === m && continue
        parentmodule(child) === m || continue
        child in seen && continue
        push!(direct_submods, child)
    end

    if !recursive
        if toplevel
            # Warn if any direct (or nested) submodule has documented bindings
            submods_with_docs = Module[]
            for child in direct_submods
                if _has_any_docs(child, Set{Module}(seen))
                    push!(submods_with_docs, child)
                end
            end
            if !isempty(submods_with_docs)
                names_str = join(string.(nameof.(submods_with_docs)), ", ")
                @warn "Submodule(s) with documented bindings were skipped: $names_str. " *
                      "Pass `recursive=true` to include them."
            end
        end
        return own
    end

    # Recursive collection
    all_bindings = copy(own)
    for child in direct_submods
        child in seen && continue
        child_bindings = _documented_bindings_impl(child, true, seen, false)
        append!(all_bindings, child_bindings)
    end

    if toplevel
        # Warn about name collisions (same .var from different modules)
        var_to_bindings = Dict{Symbol, Vector{Base.Docs.Binding}}()
        for b in all_bindings
            push!(get!(var_to_bindings, b.var, Base.Docs.Binding[]), b)
        end
        collisions = [(v, bs) for (v, bs) in var_to_bindings if length(bs) > 1]
        if !isempty(collisions)
            parts = String[]
            for (v, bs) in sort(collisions; by=x->string(x[1]))
                mods = join([string(b.mod, ".", b.var) for b in bs], ", ")
                push!(parts, "$v ($mods)")
            end
            @warn "Name collision(s) in recursive documentation — page files may be overwritten: " *
                  join(parts, "; ")
        end
    end

    all_bindings
end

# Returns true if `m` or any of its submodules (not in `seen`) has at least one
# documented binding.
function _has_any_docs(m::Module, seen::Set{Module})
    m in seen && return false
    push!(seen, m)
    !isempty(Base.Docs.meta(m)) && return true
    for s in names(m; all=true)
        isdefined(m, s) || continue
        child = getfield(m, s)
        child isa Module || continue
        child === m && continue
        parentmodule(child) === m || continue
        _has_any_docs(child, seen) && return true
    end
    false
end

"""
    _documented_symbols(m::Module; recursive::Bool=false) -> Vector{Symbol}

Return the `.var` field of each binding from `_documented_bindings(m; recursive)`.
"""
function _documented_symbols(m::Module; recursive::Bool=false)
    Symbol[b.var for b in _documented_bindings(m; recursive=recursive)]
end

"""
    _module_path(m::Module, root::Module) -> Union{Vector{Symbol}, Nothing}

Return the chain of module names from `root` (exclusive) down to `m`
(inclusive) by walking `parentmodule` up from `m` to `root`.

For example, with `root = Root` and `m = Root.Inner.Deep`, returns
`[:Inner, :Deep]`. When `m === root`, returns an empty vector. If `root` is
not an ancestor of `m`, returns `nothing`.
"""
function _module_path(m::Module, root::Module)
    m === root && return Symbol[]
    path = Symbol[]
    cur = m
    # Guard against pathological cycles (Main's parent is Main).
    while cur !== root
        parent = parentmodule(cur)
        push!(path, nameof(cur))
        if parent === cur
            # Reached a fixed point (e.g. Main) without hitting root.
            return nothing
        end
        cur = parent
    end
    return reverse(path)
end

"""
    reference_page_names(bindings::Vector{Base.Docs.Binding}, root::Module) -> Dict{Base.Docs.Binding, String}

Compute a collision-safe per-page file name for each documented binding.

The page name for a binding is `string(b.var)` when that bare name is unique
among `bindings`. When two or more bindings share the same `.var`, every
colliding binding *except one owned directly by `root`* gets a qualified name
formed from its module path relative to `root` joined with `.` followed by the
bare name (e.g. a `foo` defined in `Root.Inner` becomes `"Inner.foo"`). A
colliding binding owned directly by `root` keeps the bare name. If two
colliders are both in submodules, both are qualified.

When `root` is not an ancestor of a binding's module (which should not happen
in normal use), the fully qualified `string(b.mod)` is used as the prefix as a
fallback.
"""
function reference_page_names(bindings::Vector{Base.Docs.Binding}, root::Module)
    # Count how many bindings share each bare name.
    counts = Dict{Symbol, Int}()
    for b in bindings
        counts[b.var] = get(counts, b.var, 0) + 1
    end

    names = Dict{Base.Docs.Binding, String}()
    for b in bindings
        bare = string(b.var)
        if get(counts, b.var, 0) <= 1
            names[b] = bare
            continue
        end

        # Collision: a root-owned binding keeps the bare name; others get
        # qualified relative names.
        if b.mod === root
            names[b] = bare
            continue
        end

        path = _module_path(b.mod, root)
        if path === nothing
            # Fallback: fully qualified module string.
            names[b] = string(b.mod) * "." * bare
        else
            prefix = join(string.(path), ".")
            names[b] = isempty(prefix) ? bare : prefix * "." * bare
        end
    end

    names
end

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
    has_docstring(module_name::Module; recursive::Bool=false) -> Function

Create a selector that matches symbols with documentation.

When `recursive=true`, the set of documented symbols includes those from
direct and nested submodules (see `_documented_bindings`).

# Example
```julia
selector = has_docstring(MyModule)
selector(:documented_func)    # true if has docstring
selector(:undocumented_func)  # false
```
"""
function has_docstring(module_name::Module; recursive::Bool=false)
    documented = Set(_documented_bindings(module_name; recursive=recursive))
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
    filter_objects(module_name::Module, selectors::Vector; recursive::Bool=false) -> Vector{Symbol}

Filter module objects using a list of selectors.
Applies selectors in order and returns unique matches.

# Arguments
- `module_name::Module`: Module to get symbols from
- `selectors::Vector`: List of selectors (Symbols, Functions, or Strings)
- `recursive::Bool`: When `true`, include documented symbols from submodules
  (default: `false`).

# Example
```julia
# Get all functions starting with "process_" or ending with "_util"
symbols = filter_objects(MyModule, [starts_with("process_"), ends_with("_util")])

# Also include submodule symbols
symbols = filter_objects(MyModule, [starts_with("process_")]; recursive=true)
```
"""
function filter_objects(module_name::Module, selectors::Vector; recursive::Bool=false)
    # Get all documented symbols via shared helper
    all_symbols = _documented_symbols(module_name; recursive=recursive)

    result = Symbol[]
    for sel in selectors
        matches = apply_selector(sel, all_symbols)
        append!(result, matches)
    end

    unique(result)
end

"""
    group_objects(module_name::Module, groups::Vector{ReferenceGroup}; recursive::Bool=false) -> Vector{Tuple{ReferenceGroup, Vector{Symbol}}}

Group module objects according to ReferenceGroup specifications.
Returns a vector of (group, symbols) pairs.

# Arguments
- `module_name::Module`: Module to get symbols from
- `groups::Vector{ReferenceGroup}`: Group specifications
- `recursive::Bool`: When `true`, include documented symbols from submodules
  (default: `false`).

# Returns
Vector of tuples, each containing a ReferenceGroup and its matched symbols.
"""
function group_objects(module_name::Module, groups::Vector{ReferenceGroup}; recursive::Bool=false)
    # Get all documented symbols via shared helper
    all_symbols = _documented_symbols(module_name; recursive=recursive)
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
    auto_group_objects(module_name::Module; recursive::Bool=false) -> Vector{Tuple{ReferenceGroup, Vector{Symbol}}}

Automatically group objects by type (functions, types, constants).
Used as fallback when no custom grouping is specified.

# Arguments
- `module_name::Module`: Module to analyze
- `recursive::Bool`: When `true`, include documented symbols from submodules
  (default: `false`).
"""
function auto_group_objects(module_name::Module; recursive::Bool=false)
    all_bindings = _documented_bindings(module_name; recursive=recursive)

    functions = Symbol[]
    types = Symbol[]
    constants = Symbol[]
    other = Symbol[]

    for b in all_bindings
        sym = b.var
        # Determine the module that owns this binding so getfield works
        owner = b.mod
        try
            obj = getfield(owner, sym)
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
    autodocs_group(module_name::Module; title::String="API Reference", desc::String="", filter=nothing, recursive::Bool=false) -> ReferenceGroup

Create a ReferenceGroup that automatically includes all documented symbols from a module.
Similar to Documenter.jl's @autodocs macro.

# Arguments
- `module_name::Module`: Module to document
- `title::String`: Group title (default: "API Reference")
- `desc::String`: Group description
- `filter`: Optional filter function (e.g., `is_exported(MyModule)`)
- `recursive::Bool`: When `true`, include documented symbols from submodules
  (default: `false`).

# Example
```julia
# Include all documented symbols
group = autodocs_group(MyModule)

# Include only exported, documented symbols
group = autodocs_group(MyModule;
    title="Public API",
    filter=is_exported(MyModule)
)

# Include submodule symbols as well
group = autodocs_group(MyModule; recursive=true)

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
    filter = nothing,
    recursive::Bool = false,
)
    # Get all documented symbols via shared helper
    all_symbols = _documented_symbols(module_name; recursive=recursive)

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
