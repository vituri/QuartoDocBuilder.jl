"""
    quarto_index(; title::String="")

Generate the index.qmd file from README.md with proper YAML front matter.

# Arguments
- `title::String`: Title for the page (shown in browser tab). Defaults to "Home".
"""
function quarto_index(; title::String="")
    if isfile("docs/index.qmd")
        @warn "docs/index.qmd already exists!"
        return
    end

    if !isfile("README.md")
        @warn "README.md not found!"
        return
    end

    # Read README content
    readme_content = read("README.md", String)

    # Use provided title or default
    page_title = isempty(title) ? "Home" : title

    # Create index.qmd with YAML front matter
    index_content = """---
title: "$page_title"
---

$readme_content
"""

    write("docs/index.qmd", index_content)
    @info "Created docs/index.qmd"
end

function quarto_git_ignore()
texto = """site/
.quarto/
.jupyter_cache/
_freeze/
"""

write("docs/.gitignore", texto)
end


"""
    quarto_build_refpage(module_name; output = "docs/reference.qmd")

Build the docs/reference.qmd file with a short description of
each object.

# Arguments

- `module_name`: the module name.

- `output`: the output file. By default, it is "docs/reference.qmd".
"""
function quarto_build_refpage(module_name; output = "docs/reference.qmd")
  fs = get_objects_from_module(module_name)

  short_docs = map(quarto_doc_short.(fs)) do x
      if x isa Vector
          return string(x...)
      else
          return x
      end
  end

  s = """---
engine: julia
---

# Reference

$(string(short_docs...))
"""

  write(output, s)
end

# ============================================================================
# New config-based functions (added for pkgdown-like features)
# ============================================================================

"""
    quarto_yaml_from_config(config::QuartoConfig; force::Bool=false)

Generate the _quarto.yml file from a QuartoConfig struct.

Supports:
- Light/dark mode toggle
- Dropdown menus for articles
- Custom navbar items
- Custom footer
- Theme pairing (light/dark themes)

# Arguments
- `config::QuartoConfig`: Configuration struct
- `force::Bool`: Overwrite existing file if true (default: false)
"""
function quarto_yaml_from_config(config::QuartoConfig; force::Bool=false)
    if isfile("docs/_quarto.yml") && !force
        @warn "docs/_quarto.yml already exists! Use force=true to overwrite."
        return nothing
    end

    module_str = config.module_name !== nothing ? string(config.module_name) : "Documentation"
    repo = config.repo

    yaml = String[]

    # Project section
    push!(yaml, """
project:
  type: website
  output-dir: $(config.output_dir)
""")

    # Execute section
    push!(yaml, """
execute:
  freeze: $(config.freeze)
  cache: $(config.cache)
  warning: $(config.warning)
""")

    # Website section
    push!(yaml, """
website:
  page-navigation: true
  bread-crumbs: true

  search:
    show-item-context: true
    type: overlay
""")

    # Build navbar
    navbar_yaml = _build_navbar_yaml(config, module_str)
    push!(yaml, navbar_yaml)

    # Build sidebars
    sidebar_yaml = _build_sidebar_yaml(config)
    push!(yaml, sidebar_yaml)

    # Comments (Giscus)
    giscus_repo = !isempty(config.giscus_repo) ? config.giscus_repo : repo
    if config.comments && !isempty(giscus_repo)
        push!(yaml, """
  comments:
    giscus:
      repo: $giscus_repo
      reactions-enabled: true
      loading: lazy
      mapping: pathname
""")
    end

    # Footer
    footer_yaml = _build_footer_yaml(config)
    push!(yaml, footer_yaml)

    # Engine
    push!(yaml, """
engine: julia
""")

    # Format with theme support
    format_yaml = _build_format_yaml(config)
    push!(yaml, format_yaml)

    final_yaml = join(yaml, "\n")
    write("docs/_quarto.yml", final_yaml)
    @info "Created docs/_quarto.yml"
end

"""
Internal: Build navbar YAML section.

Supports multiple dropdown sections.
"""
function _build_navbar_yaml(config::QuartoConfig, module_str::String)
    repo = config.repo

    yaml = """  navbar:
    background: primary

    left:
      - text: "$module_str.jl"
        href: index.qmd
"""

    # Add "Get Started" prominently if available
    if !isempty(config.get_started)
        yaml *= """      - text: "Get Started"
        href: $(config.get_started)
"""
    end

    # Add Reference
    yaml *= """      - text: "Reference"
        href: reference.qmd
"""

    # Build sections with dropdowns
    sorted_sections = sort(config.sections, by = s -> s.order)

    for section in sorted_sections
        section_dir = "docs/" * section.dir
        index_file = !isempty(section.index_file) ? section.index_file : "$(section.dir).qmd"

        if isdir(section_dir)
            section_files = discover_articles(section_dir)

            if !isempty(section_files) && section.dropdown && length(section_files) <= section.dropdown_limit
                # Create dropdown menu
                yaml *= """      - text: "$(section.title)"
        menu:
"""
                for f in section_files
                    title = get_article_title("docs/" * f)
                    yaml *= """          - text: "$title"
            href: $f
"""
                end
            elseif !isempty(section_files) || isfile("docs/$index_file")
                # Link to index page
                yaml *= """      - text: "$(section.title)"
        href: $index_file
"""
            end
        elseif isfile("docs/$index_file")
            # Directory doesn't exist but index file does
            yaml *= """      - text: "$(section.title)"
        href: $index_file
"""
        end
    end

    # Add News if enabled and exists
    if config.news && isfile(config.news_file)
        yaml *= """      - text: "News"
        href: news.qmd
"""
    end

    # Right side: tools
    yaml *= """
    tools:
"""

    # GitHub link
    if !isempty(repo)
        yaml *= """      - icon: github
        href: https://github.com/$repo
        text: "Source"
"""
    end

    yaml
end

"""
Internal: Build sidebar YAML section.

Supports multiple sections with their own sidebars.
"""
function _build_sidebar_yaml(config::QuartoConfig)
    yaml = """
  sidebar:
    - title: "Reference"
      style: "docked"
      background: light
      contents:
        - reference.qmd
        - auto: "reference/*"
"""

    # Build sidebars for each section
    for section in config.sections
        if !section.sidebar
            continue
        end

        section_dir = section.dir
        index_file = !isempty(section.index_file) ? section.index_file : "$(section.dir).qmd"

        if isdir("docs/" * section_dir)
            yaml *= """
    - title: "$(section.title)"
      style: "docked"
      background: light
      contents:
        - $index_file
        - auto: "$section_dir/*"
"""
        end
    end

    yaml
end

"""
Internal: Build footer YAML section.
"""
function _build_footer_yaml(config::QuartoConfig)
    footer = config.footer

    if isempty(footer.left) && isempty(footer.center) && isempty(footer.right)
        # Default footer
        return """
  page-footer: "Website generated with [Quarto](https://quarto.org/) and [QuartoDocBuilder.jl](https://github.com/vituri/QuartoDocBuilder.jl)"
"""
    end

    yaml = "  page-footer:\n"
    !isempty(footer.left) && (yaml *= "    left: \"$(footer.left)\"\n")
    !isempty(footer.center) && (yaml *= "    center: \"$(footer.center)\"\n")
    !isempty(footer.right) && (yaml *= "    right: \"$(footer.right)\"\n")

    yaml
end

"""
Internal: Build format YAML section with theme support.
"""
function _build_format_yaml(config::QuartoConfig)
    theme = config.theme

    yaml = """
format:
  html:
    css: styles.css
    code-copy: true
    code-overflow: wrap
    preview-links: true
    toc: true
    toc-depth: 3
    toc-expand: true
"""

    # Use default theme if none specified
    bootswatch = isempty(theme.bootswatch) ? "flatly" : theme.bootswatch

    # Theme with light/dark support
    if theme.dark_mode
        dark_theme = get_dark_theme(bootswatch)
        yaml *= """    theme:
      light: $bootswatch
      dark: $dark_theme
"""
    else
        yaml *= """    theme: $bootswatch
"""
    end

    # Syntax highlighting
    if !isempty(theme.code_highlight)
        yaml *= """    highlight-style: $(theme.code_highlight)
"""
    end

    yaml
end

"""
    quarto_build_site(config::QuartoConfig)

Build the documentation site from a QuartoConfig struct.

This is the config-based alternative to `quarto_build_site(module_name; kwargs...)`.
Supports all pkgdown-like features including grouped references, multiple sections, news, etc.

# Arguments
- `config::QuartoConfig`: Full configuration struct

# Example (with multiple sections)
```julia
config = QuartoConfig(
    module_name = MyPackage,
    repo = "user/MyPackage.jl",
    reference = [
        ReferenceGroup(title="Core", contents=[:main_func]),
        ReferenceGroup(title="Utils", contents=[starts_with("util_")])
    ],
    sections = [
        SectionConfig(title="Tutorials", dir="tutorials", order=1),
        SectionConfig(title="Explanation", dir="explanation", order=2),
        SectionConfig(title="How-to Guides", dir="how-to", order=3)
    ],
    theme = ThemeConfig(bootswatch="cosmo", dark_mode=true)
)
quarto_build_site(config)
```
"""
function quarto_build_site(config::QuartoConfig)
    if config.module_name === nothing
        error("QuartoConfig.module_name must be set")
    end

    module_name = config.module_name

    # Create docs directory
    if !isdir("docs")
        mkdir("docs")
    end

    # Generate _quarto.yml
    quarto_yaml_from_config(config; force=true)

    # Create .gitignore
    quarto_git_ignore()

    # Create reference directory and pages
    if !isdir("docs/reference")
        mkdir("docs/reference")
    end

    # Generate reference page (grouped if config has groups)
    if !isempty(config.reference)
        quarto_build_refpage_grouped(module_name, config)
    else
        quarto_build_refpage(module_name)
    end

    # Create section directories and index files
    for section in config.sections
        section_dir = "docs/" * section.dir
        index_file = !isempty(section.index_file) ? section.index_file : "$(section.dir).qmd"
        index_path = "docs/$index_file"

        # Create directory if it doesn't exist
        if !isdir(section_dir)
            mkpath(section_dir)
        end

        # Create index file if it doesn't exist
        if !isfile(index_path)
            desc = !isempty(section.desc) ? section.desc : "Explore the $(section.title) section."
            write(index_path, """---
title: "$(section.title)"
listing:
  - id: $(section.dir)-listing
    contents: "$(section.dir)/*.qmd"
    type: default
---

$desc

::: {#$(section.dir)-listing}
:::
""")
            @info "Created section index: $index_path"
        end
    end

    # Generate news page
    if config.news && isfile(config.news_file)
        quarto_news_page(config)
    end

    # Copy README as index with module name as title
    module_str = string(module_name)
    quarto_index(title = module_str * ".jl")

    # Generate individual function documentation pages
    fs = get_objects_from_module(module_name)
    for f in fs
        quarto_doc_page(f)
    end

    # Generate styles
    quarto_styles_from_config(config)

    @info "Documentation site built successfully!"
    @info "Run 'cd docs && quarto preview' to preview locally."
end

"""
    quarto_build_refpage_grouped(module_name::Module, config::QuartoConfig; output::String="docs/reference.qmd")

Build a grouped reference page with sections, titles, and descriptions.
Similar to pkgdown's reference page organization.

# Arguments
- `module_name::Module`: Module to document
- `config::QuartoConfig`: Configuration with reference groups
- `output::String`: Output file path

# Example
```julia
config = QuartoConfig(
    module_name = MyModule,
    reference = [
        ReferenceGroup(title="Core Functions", desc="Main functionality", contents=[:func1, :func2]),
        ReferenceGroup(title="Utilities", contents=[starts_with("util_")])
    ]
)
quarto_build_refpage_grouped(MyModule, config)
```
"""
function quarto_build_refpage_grouped(module_name::Module, config::QuartoConfig; output::String="docs/reference.qmd")
    groups = config.reference

    # If no groups specified, use auto-grouping
    if isempty(groups)
        grouped = auto_group_objects(module_name)
    else
        grouped = group_objects(module_name, groups)
    end

    s = """---
title: "Reference"
toc: true
toc-depth: 2
---

"""

    for (group, symbols) in grouped
        if isempty(symbols)
            continue
        end

        # Section anchor
        anchor = lowercase(replace(group.title, " " => "-", "_" => "-"))
        s *= "## $(group.title) {#sec-$anchor}\n\n"

        # Description if provided
        if !isempty(group.desc)
            s *= "$(group.desc)\n\n"
        end

        # Table of functions
        s *= "| Function | Description |\n"
        s *= "|----------|-------------|\n"

        for sym in symbols
            short_desc = _get_short_description(module_name, sym)
            # Escape pipe characters in description
            short_desc = replace(short_desc, "|" => "\\|")
            s *= "| [`$sym`](reference/$sym.qmd) | $short_desc |\n"
        end

        s *= "\n"
    end

    write(output, s)
    @info "Grouped reference page created at $output"
end

"""
Internal: Get short description for a symbol.
"""
function _get_short_description(module_name::Module, sym::Symbol)
    try
        doc = Base.doc(getfield(module_name, sym))
        doc_str = string(doc)

        # Get first paragraph/sentence
        lines = split(doc_str, "\n")
        for line in lines
            line = strip(line)
            if !isempty(line) && !startswith(line, "#") && !startswith(line, "```")
                # Truncate if too long
                if length(line) > 100
                    return line[1:97] * "..."
                end
                return line
            end
        end
        return ""
    catch
        return ""
    end
end

"""
    quarto_rebuild_reference(module_name::Module)
    quarto_rebuild_reference(config::QuartoConfig)

Rebuild only the reference pages (individual function docs and index).
Useful for updating docs without regenerating the entire site.
"""
function quarto_rebuild_reference(module_name::Module)
    # Regenerate individual pages
    fs = get_objects_from_module(module_name)
    for f in fs
        quarto_doc_page(f)
    end

    # Regenerate index
    quarto_build_refpage(module_name)

    @info "Reference pages rebuilt"
end

function quarto_rebuild_reference(config::QuartoConfig)
    if config.module_name === nothing
        error("QuartoConfig.module_name must be set")
    end

    module_name = config.module_name

    # Regenerate individual pages
    fs = get_objects_from_module(module_name)
    for f in fs
        quarto_doc_page(f)
    end

    # Regenerate index (grouped or simple)
    if !isempty(config.reference)
        quarto_build_refpage_grouped(module_name, config)
    else
        quarto_build_refpage(module_name)
    end

    @info "Reference pages rebuilt"
end

"""
    quarto_rebuild_all(config::QuartoConfig)

Rebuild the entire documentation site, overwriting existing files.
"""
function quarto_rebuild_all(config::QuartoConfig)
    # Remove existing _quarto.yml to allow regeneration
    isfile("docs/_quarto.yml") && rm("docs/_quarto.yml")

    quarto_build_site(config)
end