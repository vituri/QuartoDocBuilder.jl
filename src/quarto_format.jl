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
        
"""

```{$l}
#| eval: $eval
$(m.code)

```

"""
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
function quarto_doc(s::Symbol)
    z = Base.doc(@eval $s)
    ct = z.content
    
    if ct[1] isa Markdown.Paragraph        
      return  [
"""

```{julia}
#| eval: false

$(ct[2].content[1].code)

```

No documentation found! :(
"""
        ]
    else 
        return quarto_format.(ct)
    end 
end



"""
    quarto_doc_page(s; dir = "docs/from_module")

Given a symbol `s`, write its .qmd doc into the folder `dir`.
"""
function quarto_doc_page(s; dir = "docs/from_module")

    blocks = quarto_doc(s) .|> quarto_callout_block

    qmd = """
      ---
      engine: julia
      ---

      # $(string(s))
          
      $(str_concat(blocks, sep = "\n --- \n "))
      """
    path = "$(dir)/$(string(s)).qmd"
    @info "Writing docs to file $path"
    write(path, qmd)
end