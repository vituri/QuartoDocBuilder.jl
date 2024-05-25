"""
    quarto_yaml(module_name)

Generate the _quarto.yaml file.

# Arguments
- `module_name`: the name of the current module.
"""
function quarto_yaml(
  module_name
  ;output_dir = "site"
  ,freeze = "auto"
  ,cache = "true"
  ,warning = "false"

  ,comments = "true"
  ,repo = "USERNAME/REPOSITORY"

  ,theme = "flatly"
  )

    if isfile("docs/_quarto.yml")
        @warn "docs/_quarto.yml already exists! Delete it and try again." 
        return nothing
    end

  # project

  yaml = String[]
s = """

project:
  type: website
  output-dir: $output_dir"""
push!(yaml, s)

    # execute
    s = """

execute:
  freeze: $freeze
  cache: $cache
  warning: $warning"""
push!(yaml, s)

# website
s = 
  """

website:
  # title: "$(module_name).jl"
  page-navigation: true
  bread-crumbs: true

  search:
    show-item-context: true
    type: overlay

  navbar:
    background: primary

    left:
      - text: "$(module_name).jl"
        href: index.qmd
      - text: "Reference"
        href: reference.qmd
      - text: "Tutorials"
        href: tutorials.qmd

  sidebar:
    - title: "Reference"
      style: "docked"
      background: light
      contents: 
        - reference.qmd
        - auto: "reference/*"

    - title: "Tutorials"
      style: "docked"
      background: light
      contents:
        - tutorials.qmd
        - auto: "tutorials/*"
        
"""

push!(yaml, s)  

# comments
if comments == "true"
s = """

  comments:
    giscus:
      repo: $repo
      reactions-enabled: true
      loading: lazy
      mapping: pathname

"""

push!(yaml, s)  

end

# footer
s = """

page-footer: "Website generated with [Quarto](https://quarto.org/) and [Pkgdown.jl](https://github.com/vituri/Pkgdown.jl)"

"""
  push!(yaml, s)  

# engine

s = """

engine: julia
"""
push!(yaml, s)

# format

s = """

format:
  html:
    theme: $theme
    css: styles.css
    code-copy: true
    code-overflow: wrap
    preview-links: true
    toc: true
    toc-depth: 3
    toc-expand: true """

push!(yaml, s)

final_yaml = string(yaml...)

write("docs/_quarto.yml", final_yaml)

end

"""
    quarto_index()

Generate the index.qmd file. It is just a copy of the README.md file.
"""
function quarto_index()
  try
    cp("README.md", "docs/index.qmd", force=false)
  catch
    @warn "docs/index.qmd already exists!"
  end
    
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
    quarto_build_site(module_name)

Create all the files necessary to build the Quarto website.
"""
function quarto_build_site(module_name; kwargs...)

  if isdir("docs") == false
    mkdir("docs")
  end

  quarto_yaml(module_name; kwargs...)
  
  quarto_git_ignore()

  # reference
  if isdir("docs/reference") == false
    mkdir("docs/reference")
  end

  if isfile("docs/reference.qmd") == false
    s = """
    
# Reference
    
Write your references here."""

    write("docs/reference.qmd", s)
  end

  # tutorials
  if isdir("docs/tutorials") == false
    mkdir("docs/tutorials")

    s = """
    
# First tutorial
    
This is my first tutorial!"""

    write("docs/tutorials/tutorial-01.qmd", s)
  end

  if isfile("docs/tutorials.qmd") == false
    write("docs/tutorials.qmd", """

# Tutorials
    
    
    Describe your tutorials here.""")
  end

  quarto_index()

  fs = names(@eval $(Symbol(module_name)))[2:end]

  fs .|> quarto_doc_page

  quarto_styles()

  @info "All done!"
end