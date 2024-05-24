"""
    quarto_yaml(module_name)

Generate the _quarto.yaml file.

# Arguments
- `module_name`: the name of the current module.
"""
function quarto_yaml(module_name)

    if isfile("docs/_quarto.yml")
        @warn "docs/_quarto.yml already exists! Delete it by hand and try again." 
        return nothing
    end

    module_name = "Pkgdown"

yaml = 
"""
project:
  type: website
  output-dir: site

website:
  title: "$(module_name).jl"
  search: true

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
        - auto: "from_module/*"

    - title: "Tutorials"
      style: "docked"
      background: light
      contents:
        - tutorials.qmd
        - auto: "tutorials/*" 

  page-footer: "Website generated with [Quarto](https://quarto.org/) and [Pkgdown.jl](https://github.com/vituri/Pkgdown.jl)"


format:
  html:
    theme: cosmo    
    toc: true
    preview-links: true
    
engine: julia
"""

write("docs/_quarto.yml", yaml)

end

"""
    quarto_index()

Generate the index.qmd file. It is just a copy of the README.md file.
"""
function quarto_index()
    cp("README.md", "docs/index.qmd", force=true)
end

"""
    quarto_build_site(module_name)

Create all the files necessary to build the Quarto website.
"""
function quarto_build_site(module_name)

    quarto_index()

    quarto_yaml(module_name)

end

function quarto_git_ignore()
texto = """site/
.quarto/
.jupyter_cache/
_freeze/
"""

write("docs/.gitignore", texto)
end