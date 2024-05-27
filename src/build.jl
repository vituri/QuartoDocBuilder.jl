"""
    quarto_yaml(
      module_name
      ;output_dir = "site"
      ,freeze = "auto"
      ,cache = "true"
      ,warning = "false"
      ,comments = "true"
      ,repo = "USERNAME/REPOSITORY"
      ,theme = "flatly"
      )

Generate the _quarto.yaml file.

# Arguments
- `module_name`: the name of the current module.
- `output_dir`: the directory of the output, inside /docs/ .
- `freeze`, `cache`, `warning`: execution options in Quarto.
- `comments`: if the comment section with Discus is enabled.
- `repo`: string in the format USERNAME/REPOSITORY so your
comment section work with Discus. Also used to make the github icon.
- `theme`: one of the bootswatch themes available in Quarto.

# Details

This function creates the docs/_quarto.yaml file. See
  https://quarto.org/docs/reference/projects/websites.html for
more details.
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
  # title: "$(string(module_name)).jl"
  page-navigation: true
  bread-crumbs: true

  search:
    show-item-context: true
    type: overlay

  navbar:
    background: primary

    left:
      - text: "$(string(module_name)).jl"
        href: index.qmd
      - text: "Reference"
        href: reference.qmd
      - text: "Tutorials"
        href: tutorials.qmd
    
    tools:
    - icon: github
      href: https://github.com/$(repo)
      text: "$(string(module_name)).jl"

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

  page-footer: "Website generated with [Quarto](https://quarto.org/) and [QuartoDocBuilder.jl](https://github.com/vituri/QuartoDocBuilder.jl)"

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

    quarto_build_site(module_name; kwargs...)

Create all the files necessary to build the Quarto 
website for the first time.

# Arguments

- `module_name`: your module's name.

- `kwargs...`: kwargs passed to `quarto_yaml`.

# Details

This function does a lot of things!

- Create the `docs` directory, if it doesn't exist.

- Create docs/_quarto.yaml, which is the file that
contains all information about how to render the 
website as a Quarto project.

- Create the directory `docs/reference` and the file 
docs/reference.qmd if they don't exist.

- Create the directory `docs/tutorials` and the file 
docs/tutorials.qmd if they don't exist, together with
docs/tutorials/tutorial-01.qmd.

- Copy your README.md file as docs/index.qmd.

- Create docs/styles.css with some predefined styles.

- Create a .qmd file in docs/reference for each object
in `module_name`.

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

  fs = get_objects_from_module(module_name) #names(module_name)[2:end]

  fs .|> quarto_doc_page

  quarto_styles()

  @info "All done!"
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