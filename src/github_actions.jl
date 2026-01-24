# GitHub Actions integration for QuartoDocBuilder.jl
# Generates CI/CD workflows for documentation deployment

"""
    quarto_github_action(; kwargs...)

Generate a GitHub Actions workflow for building and deploying documentation.

# Arguments
- `quarto_version::String`: Quarto version to use (default: "pre-release" for Julia support)
- `julia_version::String`: Julia version to use (default: "1")
- `output_dir::String`: Output directory from Quarto (default: "site")
- `trigger_branches::Vector{String}`: Branches that trigger deployment (default: ["main", "master"])

# Example
```julia
quarto_github_action()
# Creates .github/workflows/docs.yml

quarto_github_action(julia_version="1.10")
```
"""
function quarto_github_action(;
    quarto_version::String = "pre-release",
    julia_version::String = "1",
    output_dir::String = "site",
    trigger_branches::Vector{String} = ["main", "master"]
)
    branches_yaml = join(["\"$b\"" for b in trigger_branches], ", ")

    workflow = """name: Build and Deploy Documentation

on:
  push:
    branches: [$branches_yaml]
  pull_request:
    branches: [$branches_yaml]
  workflow_dispatch:

permissions:
  contents: write
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Julia
        uses: julia-actions/setup-julia@v2
        with:
          version: '$julia_version'

      - name: Cache Julia packages
        uses: actions/cache@v4
        with:
          path: |
            ~/.julia/artifacts
            ~/.julia/compiled
            ~/.julia/packages
          key: \${{ runner.os }}-julia-\${{ hashFiles('**/Project.toml', '**/Manifest.toml') }}
          restore-keys: |
            \${{ runner.os }}-julia-

      - name: Install Julia dependencies
        run: |
          julia --project=docs -e '
            using Pkg
            Pkg.develop(PackageSpec(path=pwd()))
            Pkg.instantiate()
          '

      - name: Build documentation (Julia)
        run: |
          julia --project=docs docs/make.jl

      - name: Set up Quarto
        uses: quarto-dev/quarto-actions/setup@v2
        with:
          version: $quarto_version

      - name: Render Quarto site
        run: |
          cd docs && quarto render

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: docs/$output_dir

  deploy:
    needs: build
    if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/master'
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: \${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
"""

    mkpath(".github/workflows")
    write(".github/workflows/docs.yml", workflow)
    @info "GitHub Actions workflow created at .github/workflows/docs.yml"
end

"""
    quarto_github_action_simple(; kwargs...)

Generate a simpler GitHub Actions workflow using gh-pages branch deployment.
This is the traditional approach that doesn't require GitHub Pages configuration.

# Arguments
- `branch::String`: Branch to deploy to (default: "gh-pages")
- `quarto_version::String`: Quarto version to use (default: "pre-release")
- `julia_version::String`: Julia version to use (default: "1")
- `output_dir::String`: Output directory from Quarto (default: "site")
"""
function quarto_github_action_simple(;
    branch::String = "gh-pages",
    quarto_version::String = "pre-release",
    julia_version::String = "1",
    output_dir::String = "site"
)
    workflow = """name: Build and Deploy Documentation

on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]
  workflow_dispatch:

permissions:
  contents: write

jobs:
  build-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up Julia
        uses: julia-actions/setup-julia@v2
        with:
          version: '$julia_version'

      - name: Cache Julia packages
        uses: actions/cache@v4
        with:
          path: |
            ~/.julia/artifacts
            ~/.julia/compiled
            ~/.julia/packages
          key: \${{ runner.os }}-julia-\${{ hashFiles('**/Project.toml', '**/Manifest.toml') }}
          restore-keys: |
            \${{ runner.os }}-julia-

      - name: Install Julia dependencies
        run: |
          julia --project=docs -e '
            using Pkg
            Pkg.develop(PackageSpec(path=pwd()))
            Pkg.instantiate()
          '

      - name: Build documentation (Julia)
        run: |
          julia --project=docs docs/make.jl

      - name: Set up Quarto
        uses: quarto-dev/quarto-actions/setup@v2
        with:
          version: $quarto_version

      - name: Render Quarto site
        run: |
          cd docs && quarto render

      - name: Deploy to GitHub Pages
        if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/master'
        uses: peaceiris/actions-gh-pages@v4
        with:
          github_token: \${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./docs/$output_dir
          publish_branch: $branch
"""

    mkpath(".github/workflows")
    write(".github/workflows/docs.yml", workflow)
    @info "GitHub Actions workflow created at .github/workflows/docs.yml"
end

"""
    quarto_makejl_template(module_name::Module; config_file::String="")

Generate a docs/make.jl template file.

# Arguments
- `module_name::Module`: The module being documented
- `config_file::String`: Optional path to configuration file

# Example
```julia
quarto_makejl_template(MyPackage)
# Creates docs/make.jl
```
"""
function quarto_makejl_template(module_name::Module; config_file::String="")
    module_str = string(module_name)

    if isempty(config_file)
        content = """# Documentation build script for $module_str

using $module_str
using QuartoDocBuilder

# Build the documentation site
quarto_build_site($module_str;
    repo = "USERNAME/$module_str.jl",  # Update with your GitHub repo
    theme = "flatly"
)

# Build the reference page with function descriptions
quarto_build_refpage($module_str)

println("Documentation build complete!")
println("Run 'quarto render' in the docs/ directory to generate HTML.")
"""
    else
        content = """# Documentation build script for $module_str

using $module_str
using QuartoDocBuilder

# Load configuration from file
config = load_config("$config_file")

# Set the module (can't be loaded from TOML)
config = QuartoConfig(
    module_name = $module_str,
    # Copy other fields from loaded config...
)

# Build the documentation site
quarto_build_site(config)

println("Documentation build complete!")
println("Run 'quarto render' in the docs/ directory to generate HTML.")
"""
    end

    mkpath("docs")
    write("docs/make.jl", content)
    @info "Created docs/make.jl"
end

"""
    quarto_docs_project_toml(module_name::Module)

Generate a docs/Project.toml for the documentation environment.

# Arguments
- `module_name::Module`: The module being documented
"""
function quarto_docs_project_toml(module_name::Module)
    module_str = string(module_name)

    content = """[deps]
$module_str = "$(Base.PkgId(module_name).uuid)"
QuartoDocBuilder = "164f4f01-dadb-4e86-a767-9a3bba57cbbb"
"""

    mkpath("docs")
    write("docs/Project.toml", content)
    @info "Created docs/Project.toml"
end

"""
    quarto_setup_instructions() -> String

Return setup instructions for GitHub Pages deployment.
"""
function quarto_setup_instructions()
    """
## GitHub Pages Setup Instructions

### Option 1: GitHub Pages (Recommended)

1. Generate the GitHub Actions workflow:
   ```julia
   using QuartoDocBuilder
   quarto_github_action()
   ```

2. Configure GitHub Pages in your repository:
   - Go to **Settings** > **Pages**
   - Under "Build and deployment", select **GitHub Actions**

3. Push your changes to main/master branch

4. Your documentation will be available at:
   `https://username.github.io/repository`

### Option 2: Traditional gh-pages branch

1. Generate the simpler workflow:
   ```julia
   quarto_github_action_simple()
   ```

2. Configure GitHub Pages:
   - Go to **Settings** > **Pages**
   - Select **Deploy from a branch**
   - Choose `gh-pages` branch and `/ (root)` folder

3. Push your changes

### Local Preview

Before pushing, you can preview your site locally:

```bash
cd docs
quarto preview
```

### Troubleshooting

- **Julia not found**: The workflow uses Julia 1.x by default. Specify a version with `julia_version="1.10"`.
- **Quarto version**: Uses pre-release for Julia engine support. Change with `quarto_version="1.4"`.
- **Permissions error**: Ensure the workflow has `contents: write` permission.
"""
end

"""
    setup_documentation(module_name::Module; repo::String="", kwargs...)

One-stop setup for documentation infrastructure.

Creates:
- docs/make.jl
- docs/Project.toml
- .github/workflows/docs.yml
- Initial documentation structure

# Arguments
- `module_name::Module`: The module to document
- `repo::String`: GitHub repository in "user/repo" format
- Additional kwargs passed to `quarto_build_site`

# Example
```julia
setup_documentation(MyPackage; repo="myuser/MyPackage.jl")
```
"""
function setup_documentation(module_name::Module; repo::String="", kwargs...)
    module_str = string(module_name)

    # Auto-detect repo if not provided
    if isempty(repo)
        repo = detect_repo()
        if isempty(repo)
            @warn "Could not auto-detect repository. Please set manually."
            repo = "USERNAME/$module_str.jl"
        end
    end

    @info "Setting up documentation for $module_str"
    @info "Repository: $repo"

    # Create docs/Project.toml
    quarto_docs_project_toml(module_name)

    # Create docs/make.jl
    quarto_makejl_template(module_name)

    # Create GitHub Actions workflow
    quarto_github_action()

    # Build initial site structure
    quarto_build_site(module_name; repo=repo, kwargs...)

    @info """
    Documentation setup complete!

    Next steps:
    1. Update docs/make.jl with your GitHub repository
    2. Add articles to docs/articles/
    3. Create NEWS.md for changelog
    4. Run 'julia --project=docs docs/make.jl' to rebuild
    5. Run 'cd docs && quarto preview' to preview locally
    6. Push to GitHub to trigger automatic deployment

    For more info: quarto_setup_instructions()
    """
end
