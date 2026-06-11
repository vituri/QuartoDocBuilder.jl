# Sphinx objects.inv (version 2) support for QuartoDocBuilder.jl
#
# Implements reading and writing the Sphinx inventory format used by
# Documenter.jl (>= 1.0), DocInventories.jl and DocumenterInterLinks.jl.
# This lets QuartoDocBuilder resolve cross-package references to real URLs
# (instead of fabricating Documenter-specific paths) and emit an
# `objects.inv` so other packages can link back to sites built here.
#
# Format (version 2): a plain-text header of exactly four lines
#
#     # Sphinx inventory version 2
#     # Project: <name>
#     # Version: <version>
#     # The remainder of this file is compressed using zlib.
#
# followed by a zlib-compressed body. Each body line has the shape
#
#     <name> <domain>:<role> <priority> <uri> <dispname>
#
# where fields are space-separated. A trailing `$` in `uri` means
# "substitute the object name here". A `dispname` of `-` means it is
# identical to `name`.

using CodecZlib
using Downloads

"""
    InventoryItem

A single entry in a Sphinx `objects.inv` inventory.

# Fields
- `name::String`: Fully qualified object name (e.g. `"MyPkg.myfunction"`).
- `domain::String`: Domain of the object (Julia inventories use `"jl"`).
- `role::String`: Role within the domain (e.g. `"function"`, `"type"`).
- `priority::Int`: Search priority (Documenter uses `1`).
- `uri::String`: URI relative to the inventory root. A trailing `\$`
  is shorthand for the object `name` (expanded by [`item_uri`](@ref)).
- `dispname::String`: Display name. The sentinel `"-"` means it equals `name`.
"""
struct InventoryItem
    name::String
    domain::String
    role::String
    priority::Int
    uri::String
    dispname::String
end

"""
    InventoryItem(name, domain, role, priority, uri; dispname="-")

Convenience constructor with a default `dispname` of `"-"` (meaning the
display name is identical to `name`).
"""
function InventoryItem(name, domain, role, priority, uri; dispname::AbstractString="-")
    InventoryItem(String(name), String(domain), String(role), Int(priority),
                  String(uri), String(dispname))
end

"""
    item_uri(item::InventoryItem) -> String

Return the URI of `item` with any trailing `\$` expanded to the item's
`name`, as mandated by the Sphinx inventory v2 format.
"""
function item_uri(item::InventoryItem)
    if endswith(item.uri, "\$")
        return item.uri[1:end-1] * item.name
    end
    return item.uri
end

"""
    item_dispname(item::InventoryItem) -> String

Return the display name of `item`, expanding the `"-"` sentinel to the
item's `name`.
"""
item_dispname(item::InventoryItem) = item.dispname == "-" ? item.name : item.dispname

"""
    Inventory

An in-memory representation of a Sphinx `objects.inv` inventory.

# Fields
- `project::String`: Project name from the inventory header.
- `version::String`: Project version from the inventory header.
- `items::Vector{InventoryItem}`: All inventory entries.
- `root_url::String`: Base URL the URIs are relative to (empty for
  inventories that were not loaded from a URL). Used by
  [`resolve_inventory`](@ref) to build absolute links.
- `lookup::Dict{String,Int}`: Name => index map for O(1) resolution.
"""
struct Inventory
    project::String
    version::String
    items::Vector{InventoryItem}
    root_url::String
    lookup::Dict{String,Int}
end

"""
    Inventory(project, version, items; root_url="") -> Inventory

Construct an [`Inventory`](@ref) from `project`, `version` and a vector of
[`InventoryItem`](@ref)s, building the name lookup table automatically.
`root_url` is the base URL the item URIs are relative to.
"""
function Inventory(project::AbstractString, version::AbstractString,
                   items::Vector{InventoryItem}; root_url::AbstractString="")
    lookup = Dict{String,Int}()
    for (i, item) in enumerate(items)
        # First occurrence wins on duplicate names.
        get!(lookup, item.name, i)
    end
    Inventory(String(project), String(version), items, String(root_url), lookup)
end

"""
    write_inventory(inv::Inventory, path::AbstractString) -> String

Write `inv` to `path` in the Sphinx `objects.inv` version-2 format: a
four-line plain-text header followed by a zlib-compressed body. Returns
`path`.

The body lines are sorted by name for stable, reproducible output.
"""
function write_inventory(inv::Inventory, path::AbstractString)
    header = string(
        "# Sphinx inventory version 2\n",
        "# Project: ", inv.project, "\n",
        "# Version: ", inv.version, "\n",
        "# The remainder of this file is compressed using zlib.\n",
    )

    sorted = sort(inv.items; by = it -> it.name)
    body = IOBuffer()
    for item in sorted
        # <name> <domain>:<role> <priority> <uri> <dispname>
        println(body, item.name, " ", item.domain, ":", item.role, " ",
                item.priority, " ", item.uri, " ", item.dispname)
    end
    compressed = transcode(ZlibCompressor, take!(body))

    open(path, "w") do io
        write(io, header)
        write(io, compressed)
    end
    return path
end

# Parse the four header lines from an IO, returning (project, version).
function _parse_inventory_header(io::IO)
    line1 = readline(io)
    startswith(line1, "# Sphinx inventory version 2") ||
        error("Unsupported inventory format (expected version 2 header), got: $(repr(line1))")

    line2 = readline(io)
    line3 = readline(io)
    line4 = readline(io)

    project = startswith(line2, "# Project:") ? strip(line2[length("# Project:")+1:end]) : ""
    version = startswith(line3, "# Version:") ? strip(line3[length("# Version:")+1:end]) : ""
    occursin("compressed using zlib", line4) ||
        error("Unexpected inventory header line 4: $(repr(line4))")

    return String(project), String(version)
end

# Parse a single decompressed body line into an InventoryItem, or `nothing`
# for blank lines. Body line: `<name> <domain>:<role> <priority> <uri> <dispname>`.
function _parse_inventory_line(line::AbstractString)
    isempty(strip(line)) && return nothing
    # Documenter/Sphinx fields are separated by single spaces. Names in Julia
    # inventories do not contain spaces, so a max-split of 5 fields is correct.
    parts = split(line, ' '; limit = 5)
    length(parts) == 5 || return nothing

    name = parts[1]
    domainrole = parts[2]
    priority = something(tryparse(Int, parts[3]), 1)
    uri = parts[4]
    dispname = parts[5]

    colon = findfirst(':', domainrole)
    if colon === nothing
        domain = domainrole
        role = ""
    else
        domain = domainrole[1:colon-1]
        role = domainrole[colon+1:end]
    end

    return InventoryItem(String(name), String(domain), String(role),
                         priority, String(uri), String(dispname))
end

"""
    load_inventory(source::AbstractString; root_url=nothing) -> Inventory

Load a Sphinx `objects.inv` inventory from `source`.

If `source` starts with `http://` or `https://` it is downloaded to a
temporary file (using the `Downloads` stdlib) and `root_url` defaults to the
directory containing the inventory (the part of the URL before the trailing
`/objects.inv`). Otherwise `source` is treated as a local file path and
`root_url` defaults to `""` (override it to make [`resolve_inventory`](@ref)
produce absolute URLs).

The four-line header is parsed for project/version, then the zlib-compressed
body is inflated and parsed into [`InventoryItem`](@ref)s.
"""
function load_inventory(source::AbstractString; root_url=nothing)
    is_url = startswith(source, "http://") || startswith(source, "https://")

    if is_url
        derived_root = _root_from_url(source)
        tmp = Downloads.download(source)
        try
            inv = _load_inventory_file(tmp)
            return Inventory(inv.project, inv.version, inv.items;
                             root_url = root_url === nothing ? derived_root : String(root_url))
        finally
            rm(tmp; force = true)
        end
    else
        inv = _load_inventory_file(source)
        rr = root_url === nothing ? "" : String(root_url)
        return Inventory(inv.project, inv.version, inv.items; root_url = rr)
    end
end

# Derive the root URL from an objects.inv URL by stripping the file name.
function _root_from_url(url::AbstractString)
    slash = findlast('/', url)
    slash === nothing && return rstrip(url, '/')
    return String(rstrip(url[1:slash-1], '/'))
end

# Read and parse a local inventory file into an Inventory (root_url left empty).
function _load_inventory_file(path::AbstractString)
    project = ""
    version = ""
    items = InventoryItem[]
    open(path, "r") do io
        project, version = _parse_inventory_header(io)
        compressed = read(io)
        decompressed = transcode(ZlibDecompressor, compressed)
        text = String(decompressed)
        for line in eachline(IOBuffer(text))
            item = _parse_inventory_line(line)
            item === nothing || push!(items, item)
        end
    end
    return Inventory(project, version, items)
end

"""
    resolve_inventory(inv::Inventory, name::AbstractString) -> Union{String, Nothing}

Resolve an object `name` against `inv`, returning a full URL (the inventory's
`root_url` joined with the item URI) or `nothing` if not found.

Lookup tries, in order:
1. the exact `name`,
2. `name` with a trailing `()` stripped,
3. any item whose name ends in `.<name>` (bare-name fallback, since
   Documenter inventories use fully qualified names like `MyPkg.myfunction`).

The item URI's trailing `\$` shorthand is expanded before joining.
"""
function resolve_inventory(inv::Inventory, name::AbstractString)
    clean = String(replace(name, r"\(\)$" => ""))

    idx = get(inv.lookup, clean, nothing)
    if idx === nothing
        # Bare-name fallback: match the last dotted component.
        suffix = "." * clean
        for (i, item) in enumerate(inv.items)
            if endswith(item.name, suffix)
                idx = i
                break
            end
        end
    end

    idx === nothing && return nothing
    return _join_url(inv.root_url, item_uri(inv.items[idx]))
end

# Join a root URL and a relative URI with exactly one slash between them.
function _join_url(root::AbstractString, uri::AbstractString)
    isempty(root) && return String(uri)
    return rstrip(root, '/') * "/" * lstrip(uri, '/')
end

# Determine the Sphinx role for a binding's value.
function _inventory_role(value)
    value isa Type && return "type"
    return "function"
end

"""
    generate_inventory(mod::Module; project=string(mod), version="", base_url="", recursive=false) -> Inventory

Build an [`Inventory`](@ref) describing every documented binding in `mod`,
matching the page layout produced by QuartoDocBuilder: each documented name
`<name>` maps to the URI `reference/<page_name>.html#sec-doc` (the page anchor
`quarto_doc_page` emits is `{#sec-doc}`).

Items use the `"jl"` domain, priority `1`, and a role of `"type"` for
bindings whose value is a `Type`, otherwise `"function"`. Names are fully
qualified as `"<project>.<name>"` so other inventories can resolve them.
`base_url` becomes the inventory's `root_url`.

When `recursive=true`, documented bindings from submodules are also included.
Their object names use the qualified relative name (e.g.
`"MyPkg.Inner.foo"`) and the URI uses the same collision-safe page name as the
generated pages (see [`reference_page_names`](@ref)).
"""
function generate_inventory(mod::Module; project::AbstractString=string(nameof(mod)),
                            version::AbstractString="", base_url::AbstractString="",
                            recursive::Bool=false)
    items = InventoryItem[]

    if recursive
        bindings = _documented_bindings(mod; recursive=true)
        page_names = reference_page_names(bindings, mod)
        for b in bindings
            page = page_names[b]
            value = isdefined(b.mod, b.var) ? getfield(b.mod, b.var) : nothing
            role = _inventory_role(value)
            # Fully qualified object name: project prefix + qualified relative
            # name (the page name already carries the submodule path on
            # collision; for unique names it is the bare name). Use the module
            # path to qualify the object name regardless of collision.
            relname = _qualified_relative_name(b, mod)
            fqname = string(project, ".", relname)
            uri = "reference/$(page).html#sec-doc"
            push!(items, InventoryItem(fqname, "jl", role, 1, uri))
        end
    else
        for (binding, _) in Base.Docs.meta(mod)
            short = _binding_name(binding)
            value = (binding isa Base.Docs.Binding && isdefined(binding.mod, binding.var)) ?
                    getfield(binding.mod, binding.var) : nothing
            role = _inventory_role(value)
            fqname = string(project, ".", short)
            uri = "reference/$(short).html#sec-doc"
            push!(items, InventoryItem(fqname, "jl", role, 1, uri))
        end
    end

    return Inventory(project, version, items; root_url = base_url)
end

# Build the object name relative to `root`, qualified by submodule path.
# A binding for `foo` owned by `Root` -> "foo"; owned by `Root.Inner` ->
# "Inner.foo". Falls back to the fully qualified module string when `root` is
# not an ancestor.
function _qualified_relative_name(b::Base.Docs.Binding, root::Module)
    bare = string(b.var)
    b.mod === root && return bare
    path = _module_path(b.mod, root)
    if path === nothing
        return string(b.mod) * "." * bare
    end
    prefix = join(string.(path), ".")
    return isempty(prefix) ? bare : prefix * "." * bare
end

# Local helper mirroring autolink.jl's _reference_name (kept private here so
# inventory.jl is self-contained regardless of include order).
function _binding_name(item)
    if item isa Base.Docs.Binding
        return string(item.var)
    elseif item isa Symbol
        return string(item)
    end
    return string(item)
end
