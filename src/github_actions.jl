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

"""
    quarto_github_action_versioned(; kwargs...)

Generate a GitHub Actions workflow for building and deploying versioned documentation.

This workflow supports:
- `/dev/` documentation on push to main/master branch
- `/vX.Y.Z/` documentation on release tags
- `/stable/` symlink pointing to latest release
- Automatic `versions.json` manifest updates
- Old version cleanup (configurable retention)

# Arguments
- `quarto_version::String`: Quarto version to use (default: "pre-release")
- `julia_version::String`: Julia version to use (default: "1")
- `output_dir::String`: Output directory from Quarto (default: "site")
- `dev_branch::String`: Branch for dev docs (default: "main")
- `keep_versions::Int`: Number of old versions to keep (default: 5)

# Example
```julia
quarto_github_action_versioned()
# Creates .github/workflows/docs.yml with versioned deployment

quarto_github_action_versioned(keep_versions=10, dev_branch="develop")
```

# URL Structure
The workflow deploys to:
- `/stable/` - Symlink to latest release tag
- `/dev/` - Development branch documentation
- `/vX.Y.Z/` - Specific version documentation (from tags)
- `versions.json` - Manifest of all available versions
"""
function quarto_github_action_versioned(;
    quarto_version::String = "pre-release",
    julia_version::String = "1",
    output_dir::String = "site",
    dev_branch::String = "main",
    keep_versions::Int = 5
)
    workflow = """name: Build and Deploy Versioned Documentation

on:
  push:
    branches: [$dev_branch]
    tags:
      - 'v*.*.*'
  pull_request:
    branches: [$dev_branch]
  workflow_dispatch:

permissions:
  contents: write
  pages: write
  id-token: write

concurrency:
  group: "pages-\${{ github.ref }}"
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      version_path: \${{ steps.version.outputs.path }}
      is_release: \${{ steps.version.outputs.is_release }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Determine version path
        id: version
        run: |
          if [[ "\${{ github.ref }}" == refs/tags/v* ]]; then
            VERSION=\${GITHUB_REF#refs/tags/}
            echo "path=\$VERSION" >> \$GITHUB_OUTPUT
            echo "is_release=true" >> \$GITHUB_OUTPUT
          else
            echo "path=dev" >> \$GITHUB_OUTPUT
            echo "is_release=false" >> \$GITHUB_OUTPUT
          fi

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
        env:
          DOC_VERSION: \${{ steps.version.outputs.path }}
        run: |
          julia --project=docs docs/make.jl

      - name: Set up Quarto
        uses: quarto-dev/quarto-actions/setup@v2
        with:
          version: $quarto_version

      - name: Render Quarto site
        run: |
          cd docs && quarto render

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: docs-\${{ steps.version.outputs.path }}
          path: docs/$output_dir/
          retention-days: 1

  deploy:
    needs: build
    if: github.event_name != 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - name: Checkout gh-pages
        uses: actions/checkout@v4
        with:
          ref: gh-pages
          path: gh-pages
        continue-on-error: true

      - name: Create gh-pages branch if missing
        run: |
          if [ ! -d "gh-pages" ]; then
            mkdir gh-pages
            cd gh-pages
            git init
            git checkout -b gh-pages
          fi

      - name: Download build artifact
        uses: actions/download-artifact@v4
        with:
          name: docs-\${{ needs.build.outputs.version_path }}
          path: new-docs

      - name: Deploy versioned docs
        run: |
          VERSION_PATH="\${{ needs.build.outputs.version_path }}"
          IS_RELEASE="\${{ needs.build.outputs.is_release }}"

          # Remove old version if exists
          rm -rf "gh-pages/\$VERSION_PATH"

          # Copy new docs
          cp -r new-docs "gh-pages/\$VERSION_PATH"

          # Update stable symlink for releases
          if [ "\$IS_RELEASE" = "true" ]; then
            rm -rf gh-pages/stable
            ln -s "\$VERSION_PATH" gh-pages/stable
          fi

          # Update versions.json
          cd gh-pages
          python3 << 'EOF'
import json
import os
from pathlib import Path

versions = []
for p in Path('.').iterdir():
    if p.is_dir() and not p.name.startswith('.'):
        if p.name.startswith('v') or p.name == 'dev':
            if not p.is_symlink():
                versions.append(p.name)

# Sort versions (dev first, then semver descending)
def sort_key(v):
    if v == 'dev':
        return (0, [0, 0, 0])
    elif v.startswith('v'):
        try:
            parts = v[1:].split('.')
            return (1, [-int(p) for p in parts[:3]])
        except:
            return (2, [0, 0, 0])
    return (2, [0, 0, 0])

versions.sort(key=sort_key)

# Keep only N versions plus dev
keep = $keep_versions
kept = ['dev'] if 'dev' in versions else []
semvers = [v for v in versions if v.startswith('v')][:keep]
versions = kept + semvers

# Remove old versions
for p in Path('.').iterdir():
    if p.is_dir() and not p.name.startswith('.') and not p.is_symlink():
        if p.name not in versions and p.name not in ['stable']:
            print(f"Removing old version: {p.name}")
            import shutil
            shutil.rmtree(p)

# Find stable
stable = None
if os.path.islink('stable'):
    stable = os.readlink('stable')

# Build manifest
manifest = {
    'stable': stable,
    'dev': 'dev',
    'versions': []
}

if stable:
    manifest['versions'].append({
        'version': 'stable',
        'url': '/stable/',
        'aliases': [stable]
    })

for v in versions:
    manifest['versions'].append({
        'version': v,
        'url': f'/{v}/'
    })

with open('versions.json', 'w') as f:
    json.dump(manifest, f, indent=2)

print("Updated versions.json")
EOF

      - name: Create root redirect
        run: |
          cat > gh-pages/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="0; url=stable/">
  <link rel="canonical" href="stable/">
  <title>Redirecting...</title>
</head>
<body>
  <p>Redirecting to <a href="stable/">stable documentation</a>...</p>
</body>
</html>
EOF

      - name: Commit and push
        run: |
          cd gh-pages
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add -A
          if git diff --staged --quiet; then
            echo "No changes to commit"
          else
            git commit -m "Deploy docs: \${{ needs.build.outputs.version_path }}"
            git push origin gh-pages --force
          fi
"""

    mkpath(".github/workflows")
    write(".github/workflows/docs.yml", workflow)
    @info "GitHub Actions versioned workflow created at .github/workflows/docs.yml"
    @info """
    Versioned documentation workflow configured!

    This workflow will:
    - Deploy to /dev/ on push to $dev_branch branch
    - Deploy to /vX.Y.Z/ on release tags (e.g., v1.0.0)
    - Update /stable/ symlink to latest release
    - Keep the last $keep_versions versions
    - Auto-update versions.json manifest

    To create a new release:
    1. Tag your commit: git tag v1.0.0
    2. Push the tag: git push origin v1.0.0

    GitHub Pages Setup:
    - Go to Settings > Pages
    - Select 'Deploy from a branch'
    - Choose 'gh-pages' branch, '/ (root)' folder
    """
end
