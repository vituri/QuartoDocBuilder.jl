using Markdown

"""
    quarto_format(m::Markdown.Code, eval = false)

Format a block of markdown code to Quarto.

# Arguments

- m::Markdown: a block of Markdown.Code.
- eval: if false, then the resulting block is not going to 
be evaluated.
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

Return a plain text from `m`.
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

"""
    quarto_format(m::Markdown.Header{1})

Take a level 1 header and write it as a level 3 header.
"""
function quarto_format(m::Markdown.Header{1})
"""

### $(m.text[1])
    
"""

end

concat_all(s) = string(s...)

"""
    quarto_format(md::Markdown.MD)

Given a markdown block, apply `quarto_format` to each
of its elements and concatenate the resulting string.
"""
function quarto_format(md::Markdown.MD)
    quarto_format.(md.content[1].content) |> concat_all
end

"""
    quarto_format(md::Markdown.Admonition)

Format a Markdown.Admonition into a callout block in Quarto.
"""
function quarto_format(md::Markdown.Admonition)

"""
::: {.callout-warning title="$(md.category): $(md.title)"}

$(md.content |> Markdown.plain)

:::

"""
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

"""
    quarto_doc(s::Symbol)

Create the documentation of a symbol (function, object, etc) `s`.
"""
function _doc_target(b)
    if b isa Base.Docs.Binding
        return isdefined(b.mod, b.var) ? getfield(b.mod, b.var) : nothing
    end
    return b
end

function _doc_lookup(b)
    if b isa Base.Docs.Binding
        return Base.Docs.doc(b)
    end
    return Base.Docs.doc(b)
end

function quarto_doc(b)
    target = _doc_target(b)
    if target === nothing
        return ["""

```julia
$(b)
```

No documentation found!
"""]
    end

    z = _doc_lookup(b)
    if z === nothing
        return ["""

```julia
$(b)
```

No documentation found!
"""]
    end
    ct = z.content
    
    if ct[1] isa Markdown.Paragraph
      return  [
"""

```julia
$(ct[2].content[1].code)
```

No documentation found!
"""
        ]
    else 
        return quarto_format.(ct)
    end 
end



"""
    quarto_doc_page(s; dir = "docs/reference")

Given a symbol or binding `s`, write its .qmd doc into the folder `dir`.
"""
function quarto_doc_page(s; dir = "docs/reference")
    mkpath(dir)

    blocks = quarto_doc(s) .|> quarto_callout_block
    st = _doc_page_name(s)

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

"""
    quarto_doc_short(s::Symbol)

Create a short description of the object. Used to build
the Reference page.
"""
function quarto_doc_short(b)
    target = _doc_target(b)
    if target === nothing
        return [
            """

```julia
$(b)
```

No documentation found! :(
            """
        ]
    end

    z = _doc_lookup(b)
    if z === nothing
        return [
            """

```julia
$(b)
```

No documentation found! :(
            """
        ]
    end
    ct = z.content
  
    if ct[1] isa Markdown.Paragraph
        return [
            """

```julia
$(ct[2].content[1].code)
```

No documentation found! :(
            """
        ]
    else
        page_name = _doc_page_name(b)
        dc_short = map(ct) do x
            code, description = x.content[1].content[1:2]
  
            s = """
  
  [$(code.code)](reference/$(page_name).qmd)
  
  > $(quarto_format(description))
  
  ---
  
            """
        end
  
        return quarto_format.(dc_short)
  
    end
  
  end
