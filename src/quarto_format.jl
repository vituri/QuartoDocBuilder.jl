using Markdown

# ============================================================================
# Generic Markdown -> Quarto node formatting
#
# The functions in this file walk Markdown.MD trees produced by
# `Base.Docs.doc` and render them to Quarto-flavoured Markdown. The renderer
# is deliberately *structure-agnostic*: it dispatches on the type of each node
# and never reaches into a field (`.code`, `.content[1]`, ...) without first
# checking the node type. This makes it robust to the many shapes a docstring
# AST can take (signature-first, paragraph-first, multi-method, etc.).
# ============================================================================

"""
    quarto_format(m::Markdown.Code, eval = false)

Format a block of markdown code to Quarto.

Code blocks with language `"jldoctest"` or `""` are rendered as `julia`
blocks. When `eval` is `false` (the default) the block is a plain fenced
block (not executed by Quarto); when `true` it is a Quarto executable
`{julia}` block.

# Arguments

- `m::Markdown.Code`: a block of Markdown.Code.
- `eval`: if `false`, the resulting block is not going to be evaluated.
"""
function quarto_format(m::Markdown.Code, eval = false)

    l = m.language
    l ∈ ["jldoctest", ""] && (l = "julia")

    if eval == false
"""

```$l
$(m.code)
```
"""
    else
"""
```{$l}
$(m.code)
```
"""
    end


end

"""
    quarto_format(m)

Return a plain text representation of `m` via `Markdown.plain`.

This is the generic fallback used for any node type without a more specific
method (lists, tables, block quotes, horizontal rules, ...). `Markdown.plain`
preserves inline math (`` `x` `` becomes `\$x\$`) and display math.
"""
quarto_format(m) = Markdown.plain(m)


"""
    quarto_format(m::Markdown.Paragraph)

Return a plain text of `m` and a line break.
"""
quarto_format(m::Markdown.Paragraph) = Markdown.plain(m) * " \n"

"""
    quarto_format(m::AbstractString)

Returns `m`.
"""
quarto_format(m::AbstractString) = m

# Demote every header by two levels so docstring headers never collide with
# the page-level H1 title or pollute the page TOC. H1->H3, H2->H4, H3->H5,
# H4+ are capped at H6.
function _demote_header_level(level::Int)
    min(level + 2, 6)
end

"""
    quarto_format(m::Markdown.Header)

Render a Markdown header, demoting its level by two (H1 -> H3, H2 -> H4,
H3 -> H5, H4 and deeper are capped at H6). Demotion keeps docstring headers
below the page H1 title and out of the page-level table of contents.
"""
function quarto_format(m::Markdown.Header{L}) where {L}
    hashes = "#"^_demote_header_level(L)
    text = Markdown.plaininline(m.text)
"""

$(hashes) $(text)

"""
end

concat_all(s) = string(s...)

# Flatten the (possibly deeply nested) content of a docstring block into a
# flat vector of leaf nodes. `Base.Docs.doc` wraps content in nested
# Markdown.MD objects, so we recurse through MD wrappers and splice their
# content in place while leaving every other node type untouched.
function _flatten_md(node)
    if node isa Markdown.MD
        out = Any[]
        for child in node.content
            append!(out, _flatten_md(child))
        end
        return out
    else
        return Any[node]
    end
end

"""
    quarto_format(md::Markdown.MD)

Given a markdown block, flatten its (possibly nested) content, apply
`quarto_format` to each leaf node, and concatenate the resulting strings.
"""
function quarto_format(md::Markdown.MD)
    quarto_format.(_flatten_md(md)) |> concat_all
end

# Map a Julia admonition category to the matching Quarto callout class.
const _ADMONITION_CALLOUTS = Dict(
    "note"    => "callout-note",
    "info"    => "callout-note",
    "tip"     => "callout-tip",
    "warning" => "callout-warning",
    "danger"  => "callout-important",
    "compat"  => "callout-note",
)

_admonition_callout(category::AbstractString) =
    get(_ADMONITION_CALLOUTS, lowercase(category), "callout-note")

"""
    quarto_format(md::Markdown.Admonition)

Format a Markdown.Admonition into a Quarto callout block, mapping the Julia
admonition category to the appropriate callout class:

- `note`/`info`/`compat` -> `callout-note`
- `warning` -> `callout-warning`
- `tip` -> `callout-tip`
- `danger` -> `callout-important`
- any other (unknown) category -> `callout-note`

The callout title is the admonition's own title. The `title` attribute is
omitted when the title is empty or simply the capitalized category default
(e.g. category `note` with title `"Note"`).
"""
function quarto_format(md::Markdown.Admonition)
    callout = _admonition_callout(md.category)
    title = md.title
    default_title = uppercasefirst(md.category)
    title_attr = (isempty(title) || title == default_title) ? "" :
        " title=\"$(title)\""

    body = quarto_format.(_flatten_md_content(md.content)) |> concat_all

"""
::: {.$(callout)$(title_attr)}

$(body)

:::

"""
end

# An admonition's `.content` is a plain vector of block nodes (not an MD).
# Flatten any nested MD wrappers it may contain so each block is rendered
# through `quarto_format`.
function _flatten_md_content(content)
    out = Any[]
    for node in content
        append!(out, _flatten_md(node))
    end
    return out
end

function str_concat(a, b; sep="\n")
    a * sep * b
end

function str_concat(v; sep="\n")
    reduce((a, b) -> str_concat(a, b, sep=sep), v)
end

"""
    quarto_callout_block(s)

Create a callout block with the string `s`.
"""
function quarto_callout_block(s)

    """

    ::: {.callout-note appearance="simple" title="docblock" collapse=false}

    $s

    :::

    """
end

# ============================================================================
# Docstring extraction helpers
# ============================================================================

# Resolve the documented object behind a binding (or return the value itself).
function _doc_target(b)
    if b isa Base.Docs.Binding
        return isdefined(b.mod, b.var) ? getfield(b.mod, b.var) : nothing
    end
    return b
end

# Look up the documentation MD for a binding or value.
function _doc_lookup(b)
    return Base.Docs.doc(b)
end

# Determine whether a binding genuinely has no documentation.
#
# Primary, shape-independent check: a Docs.Binding has no entry in the
# `Docs.meta` table of its module. When that information is unavailable
# (e.g. `b` is not a Binding), we fall back to a conservative shape check:
# `Base.Docs.doc` returns an MD whose first flattened node is a Paragraph
# beginning with "No documentation found".
function _is_missing_docs(b, md)
    if b isa Base.Docs.Binding
        meta = Base.Docs.meta(b.mod)
        return !haskey(meta, b)
    end

    nodes = _flatten_md(md)
    isempty(nodes) && return true
    first_node = nodes[1]
    if first_node isa Markdown.Paragraph
        txt = Markdown.plain(first_node)
        return occursin("No documentation found", txt)
    end
    return false
end

# Build the standard "missing documentation" block for a binding/value.
function _missing_docs_block(b)
    name = _doc_page_name(b)
    """

```julia
$(name)
```

No documentation found!
"""
end

# The list of docstring blocks for a documentation MD. `Base.Docs.doc`
# returns an MD whose `.content` holds one entry per method docstring.
function _doc_blocks(md)
    return md.content
end

"""
    quarto_doc(b)

Build the documentation for a binding or value `b`.

Returns a `Vector{String}`, one entry per docstring block (one per method
docstring). Each entry is the fully rendered Quarto Markdown for that block.
For genuinely undocumented bindings, returns a single "No documentation
found" block that includes the binding name.
"""
function quarto_doc(b)
    target = _doc_target(b)
    if target === nothing
        return [_missing_docs_block(b)]
    end

    md = _doc_lookup(b)
    if md === nothing
        return [_missing_docs_block(b)]
    end

    if _is_missing_docs(b, md)
        return [_missing_docs_block(b)]
    end

    blocks = _doc_blocks(md)
    return [quarto_format(block) for block in blocks]
end



"""
    quarto_doc_page(s; dir = "docs/reference", name = nothing)

Given a symbol or binding `s`, write its .qmd doc into the folder `dir`.

When `name` is given, it is used for both the output file name
(`<dir>/<name>.qmd`) and the page H1 title; otherwise the name is derived from
`s` via `_doc_page_name`, preserving the default behaviour.
"""
function quarto_doc_page(s; dir = "docs/reference", name::Union{Nothing,String}=nothing)
    mkpath(dir)

    blocks = quarto_doc(s) .|> quarto_callout_block
    st = name === nothing ? _doc_page_name(s) : name

    qmd = """
      ---
      engine: markdown
      ---

      # $(st) {#sec-doc}

      $(str_concat(blocks, sep = "\n --- \n "))
      """
    path = "$(dir)/$(st).qmd"
    @info "Writing docs to file $path"
    write(path, qmd)
end

function _doc_page_name(s)
    if s isa Base.Docs.Binding
        return string(s.var)
    elseif s isa Symbol
        return string(s)
    elseif s isa AbstractString
        paren = findfirst("(", s)
        paren !== nothing && return s[1:paren[1] - 1]
        return split(strip(s))[1]
    end
    return string(s)
end

# ============================================================================
# Short reference-index entries
# ============================================================================

# Find the leading signature code block of a docstring block, if any, plus the
# first paragraph of prose. Returns a tuple `(signature, paragraph_text)` where
# `signature` is the code string of a leading `Markdown.Code` node (or
# `nothing` if the block does not start with one) and `paragraph_text` is the
# plain text of the first paragraph found (or `nothing`).
function _short_parts(block)
    nodes = _flatten_md(block)

    signature = nothing
    if !isempty(nodes) && nodes[1] isa Markdown.Code
        signature = strip(nodes[1].code)
    end

    paragraph_text = nothing
    for node in nodes
        if node isa Markdown.Paragraph
            paragraph_text = strip(Markdown.plain(node))
            break
        end
    end

    return (signature, paragraph_text)
end

# Truncate a description to roughly `limit` characters, appending an ellipsis
# when content was removed. Operates on a single collapsed line.
function _truncate_desc(text, limit = 200)
    text === nothing && return ""
    collapsed = strip(replace(text, r"\s+" => " "))
    if length(collapsed) > limit
        return collapsed[1:nextind(collapsed, 0, limit)] * "..."
    end
    return collapsed
end

"""
    quarto_doc_short(b; page_name = nothing)

Create a short reference-index entry for a binding or value `b`. Used by
`quarto_build_refpage` to build the reference index.

Returns a `Vector{String}`, one entry per docstring block. For each block:

- If the block starts with a signature code block, the entry links the
  rendered signature to its per-function page and follows it with a blockquote
  of the first paragraph.
- If the block starts with a paragraph (no signature), the entry links the
  page name to its per-function page and follows it with a (truncated)
  blockquote of the first paragraph.

When `page_name` is given it is used as the reference page file stem (the link
target `reference/<page_name>.qmd`); otherwise it is derived from `b` via
`_doc_page_name`, preserving the default behaviour. Pass an explicit
`page_name` to keep collision-safe submodule page names consistent.

This function never throws on a well-formed `Markdown.MD`.
"""
function quarto_doc_short(b; page_name::Union{Nothing,String}=nothing)
    target = _doc_target(b)
    if target === nothing
        return [_missing_docs_block(b)]
    end

    md = _doc_lookup(b)
    if md === nothing
        return [_missing_docs_block(b)]
    end

    if _is_missing_docs(b, md)
        return [_missing_docs_block(b)]
    end

    page_name = page_name === nothing ? _doc_page_name(b) : page_name
    blocks = _doc_blocks(md)

    return map(blocks) do block
        signature, paragraph_text = _short_parts(block)

        link_label = signature !== nothing ? signature : page_name
        description = _truncate_desc(paragraph_text)

"""

[$(link_label)](reference/$(page_name).qmd)

> $(description)

---

"""
    end
end
