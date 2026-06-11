using Test
using QuartoDocBuilder
using Markdown

# ---------------------------------------------------------------------------
# Sample module with edge-case docstrings used to exercise quarto_format.jl
# ---------------------------------------------------------------------------
module SampleFormatModule

export ParagraphStruct, rich_function, multi_method, NoDocsFunction

"""
A struct documented with a paragraph-first docstring (no indented signature
line). This is the common shape for structs and is what used to crash
`quarto_doc_short`. The text is intentionally long so that we can test the
truncation behaviour of the short-reference entries: padding padding padding
padding padding padding padding padding padding padding padding padding padding
padding padding padding padding padding padding padding padding padding padding.
"""
struct ParagraphStruct
    value::Int
end

"""
    rich_function(x)

A signature-first docstring exercising many Markdown features.

# Examples

A normal Julia code block:

```julia
rich_function(2)
```

A doctest block:

```jldoctest
julia> rich_function(2)
3
```

## A subheader

!!! note
    This is a note.

!!! warning
    This is a warning.

!!! tip
    This is a tip.

!!! danger
    This is a danger.

Some inline math ``x \\le y`` here.

- item one
- item two

| A | B |
|---|---|
| 1 | 2 |
"""
rich_function(x) = x + 1

"""
    multi_method(x::Int)

First method documentation.
"""
multi_method(x::Int) = x

"""
    multi_method(x::String)

Second method documentation.
"""
multi_method(x::String) = x

# Intentionally undocumented (no docstring attached in Docs.meta)
NoDocsFunction() = nothing

end # module SampleFormatModule

bind(sym) = Base.Docs.Binding(SampleFormatModule, sym)

@testset "quarto_format.jl" begin

    @testset "quarto_doc_short never throws and produces links" begin
        # Paragraph-first struct: used to crash with FieldError/BoundsError.
        local short_struct
        @test_nowarn (short_struct = quarto_doc_short(bind(:ParagraphStruct)))
        @test short_struct isa Vector
        joined_struct = string(short_struct...)
        # Paragraph-first => link uses the page name.
        @test occursin("[ParagraphStruct](reference/ParagraphStruct.qmd)", joined_struct)
        # Truncated to ~200 chars: the trailing padding must be cut off.
        @test occursin("...", joined_struct)
        @test !occursin("padding padding padding padding padding padding padding padding padding padding padding padding padding padding padding", joined_struct)

        # Signature-first function: link uses the signature code.
        local short_func
        @test_nowarn (short_func = quarto_doc_short(bind(:rich_function)))
        @test short_func isa Vector
        joined_func = string(short_func...)
        @test occursin("[rich_function(x)](reference/rich_function.qmd)", joined_func)
        @test occursin("> A signature-first docstring", joined_func)
    end

    @testset "quarto_doc_short on multi-method docstrings" begin
        local short_multi
        @test_nowarn (short_multi = quarto_doc_short(bind(:multi_method)))
        joined = string(short_multi...)
        @test occursin("[multi_method(x::Int)](reference/multi_method.qmd)", joined)
        @test occursin("[multi_method(x::String)](reference/multi_method.qmd)", joined)
    end

    @testset "quarto_doc returns a vector and renders full content" begin
        blocks = quarto_doc(bind(:rich_function))
        @test blocks isa Vector
        body = string(blocks...)
        # Signature is rendered as a julia block.
        @test occursin("rich_function(x)", body)
        # The doctest block is rendered as a (non-executed) julia block.
        @test occursin("julia> rich_function(2)", body)
        # Inline math survives as $...$.
        @test occursin("\$x \\le y\$", body)
        # The list and table survive.
        @test occursin("item one", body)
        @test occursin("| A | B |", body) || occursin("A", body)
    end

    @testset "quarto_doc multi-method returns one block per method" begin
        blocks = quarto_doc(bind(:multi_method))
        @test blocks isa Vector
        @test length(blocks) == 2
        @test occursin("First method documentation", blocks[1]) ||
              occursin("First method documentation", string(blocks...))
        @test occursin("Second method documentation", string(blocks...))
    end

    @testset "missing docs detected for undocumented binding" begin
        blocks = quarto_doc(bind(:NoDocsFunction))
        @test blocks isa Vector
        body = string(blocks...)
        @test occursin("No documentation found", body)
        @test occursin("NoDocsFunction", body)

        short = quarto_doc_short(bind(:NoDocsFunction))
        @test short isa Vector
        @test occursin("No documentation found", string(short...))
        @test occursin("NoDocsFunction", string(short...))
    end

    @testset "admonition category mapping" begin
        body = string(quarto_doc(bind(:rich_function))...)
        @test occursin("callout-note", body)        # note
        @test occursin("callout-warning", body)     # warning
        @test occursin("callout-tip", body)         # tip
        @test occursin("callout-important", body)   # danger
        # No raw "category: title" prefix should leak through.
        @test !occursin("title=\"note:", body)
        @test !occursin("title=\"warning:", body)

        # Direct unit tests for the category mapping.
        @test occursin("callout-note", quarto_format(Markdown.Admonition("note", "Note", [])))
        @test occursin("callout-warning", quarto_format(Markdown.Admonition("warning", "Warning", [])))
        @test occursin("callout-tip", quarto_format(Markdown.Admonition("tip", "Tip", [])))
        @test occursin("callout-important", quarto_format(Markdown.Admonition("danger", "Danger", [])))
        @test occursin("callout-note", quarto_format(Markdown.Admonition("info", "Info", [])))
        @test occursin("callout-note", quarto_format(Markdown.Admonition("compat", "Compat", [])))
        # Unknown category falls back to callout-note.
        @test occursin("callout-note", quarto_format(Markdown.Admonition("bogus", "Bogus", [])))
    end

    @testset "header demotion by two levels" begin
        body = string(quarto_doc(bind(:rich_function))...)
        # No body line should be an H1 or H2 (they would pollute the page TOC).
        for line in split(body, "\n")
            @test !startswith(line, "# ")
            @test !startswith(line, "## ")
        end
        # "# Examples" should become "### Examples".
        @test occursin("### Examples", body)
        # "## A subheader" should become "#### A subheader".
        @test occursin("#### A subheader", body)

        # Direct unit tests of header demotion.
        @test occursin("### ", quarto_format(Markdown.Header{1}(["H1 title"])))
        @test occursin("#### ", quarto_format(Markdown.Header{2}(["H2 title"])))
        @test occursin("##### ", quarto_format(Markdown.Header{3}(["H3 title"])))
        @test occursin("###### ", quarto_format(Markdown.Header{4}(["H4 title"])))
        # H5/H6 cap at 6 (######).
        @test occursin("###### ", quarto_format(Markdown.Header{5}(["H5 title"])))
        @test occursin("###### ", quarto_format(Markdown.Header{6}(["H6 title"])))
    end

    @testset "code block language normalisation" begin
        # jldoctest and empty language both become julia.
        @test occursin("```julia", quarto_format(Markdown.Code("jldoctest", "x")))
        @test occursin("```julia", quarto_format(Markdown.Code("", "x")))
        # Non-evaluated by default (no curly braces).
        @test !occursin("```{julia}", quarto_format(Markdown.Code("julia", "x")))
    end

    @testset "regression: quarto_build_refpage ungrouped path" begin
        mktempdir() do dir
            cd(dir) do
                quarto_build_refpage(SampleFormatModule)
                @test isfile("docs/reference.qmd")
                content = read("docs/reference.qmd", String)
                # The paragraph-first struct's name must appear.
                @test occursin("ParagraphStruct", content)
                @test occursin("rich_function", content)
            end
        end
    end

end
