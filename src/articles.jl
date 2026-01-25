# Articles/Vignettes system for QuartoDocBuilder.jl
# Provides article discovery, organization, and index generation

"""
    discover_articles(dir::String="docs/articles") -> Vector{String}

Auto-discover .qmd article files in the specified directory.
Returns paths relative to the docs directory.

# Arguments
- `dir::String`: Directory to search for articles

# Returns
Vector of article file paths, sorted alphabetically.

# Example
```julia
articles = discover_articles("docs/articles")
# ["articles/getting-started.qmd", "articles/advanced.qmd"]
```
"""
function discover_articles(dir::String="docs/articles")
    if !isdir(dir)
        return String[]
    end

    files = String[]
    for f in readdir(dir)
        filepath = joinpath(dir, f)
        if isfile(filepath) && endswith(f, ".qmd")
            # Return relative path from docs/
            rel_path = replace(filepath, r"^docs/" => "")
            push!(files, rel_path)
        end
    end

    sort(files)
end

"""
    discover_articles_recursive(dir::String="docs/articles") -> Vector{String}

Recursively discover .qmd article files in the specified directory and subdirectories.

# Arguments
- `dir::String`: Root directory to search

# Returns
Vector of article file paths, sorted alphabetically.
"""
function discover_articles_recursive(dir::String="docs/articles")
    if !isdir(dir)
        return String[]
    end

    files = String[]

    for (root, _, filenames) in walkdir(dir)
        for f in filenames
            if endswith(f, ".qmd")
                filepath = joinpath(root, f)
                rel_path = replace(filepath, r"^docs/" => "")
                push!(files, rel_path)
            end
        end
    end

    sort(files)
end

"""
    detect_get_started(module_name::Module; dir::String="docs/articles") -> Union{String, Nothing}

Find a "Get Started" article by looking for files matching common naming patterns.

Searches for (in order):
1. `{module_name}.qmd` (package name)
2. `get-started.qmd`
3. `getting-started.qmd`
4. `quickstart.qmd`
5. `introduction.qmd`
6. `intro.qmd`

# Arguments
- `module_name::Module`: The module being documented
- `dir::String`: Directory containing articles

# Returns
Path to the "Get Started" article, or `nothing` if not found.

# Example
```julia
get_started = detect_get_started(MyPackage)
# "articles/mypackage.qmd" or nothing
```
"""
function detect_get_started(module_name::Module; dir::String="docs/articles")
    module_str = lowercase(string(module_name))

    candidates = [
        joinpath(dir, "$(module_str).qmd"),
        joinpath(dir, "get-started.qmd"),
        joinpath(dir, "getting-started.qmd"),
        joinpath(dir, "quickstart.qmd"),
        joinpath(dir, "introduction.qmd"),
        joinpath(dir, "intro.qmd"),
    ]

    for c in candidates
        if isfile(c)
            # Return relative path from docs/
            return replace(c, r"^docs/" => "")
        end
    end

    nothing
end

"""
    get_article_title(filepath::String) -> String

Extract the title from an article's YAML frontmatter or first header.

# Arguments
- `filepath::String`: Path to the .qmd file

# Returns
The article title, or the filename (without extension) as fallback.
"""
function get_article_title(filepath::String)
    if !isfile(filepath)
        # Return filename without extension as fallback
        return titlecase(replace(basename(filepath), ".qmd" => "", "-" => " ", "_" => " "))
    end

    content = read(filepath, String)
    lines = split(content, "\n")

    in_frontmatter = false
    for line in lines
        # Check for YAML frontmatter
        if line == "---"
            in_frontmatter = !in_frontmatter
            continue
        end

        # Look for title in frontmatter
        if in_frontmatter
            m = match(r"^title:\s*[\"']?(.+?)[\"']?\s*$", line)
            if m !== nothing
                return strip(m.captures[1])
            end
        end

        # Look for first header (outside frontmatter)
        if !in_frontmatter
            m = match(r"^#\s+(.+)$", line)
            if m !== nothing
                return strip(m.captures[1])
            end
        end
    end

    # Fallback to filename
    titlecase(replace(basename(filepath), ".qmd" => "", "-" => " ", "_" => " "))
end

"""
    ArticleInfo

Information about a discovered article.
"""
struct ArticleInfo
    path::String       # Relative path from docs/
    title::String      # Article title
    order::Int         # Sort order (from frontmatter or 999)
end

"""
    get_article_info(filepath::String) -> ArticleInfo

Extract metadata from an article file.

# Arguments
- `filepath::String`: Path to the .qmd file
"""
function get_article_info(filepath::String)
    title = get_article_title(filepath)
    order = get_article_order(filepath)
    rel_path = replace(filepath, r"^docs/" => "")

    ArticleInfo(rel_path, title, order)
end

"""
    get_article_order(filepath::String) -> Int

Extract the order from an article's YAML frontmatter.
Returns 999 as default if not specified.
"""
function get_article_order(filepath::String)
    if !isfile(filepath)
        return 999
    end

    content = read(filepath, String)
    lines = split(content, "\n")

    in_frontmatter = false
    for line in lines
        if line == "---"
            in_frontmatter = !in_frontmatter
            continue
        end

        if in_frontmatter
            m = match(r"^order:\s*(\d+)\s*$", line)
            if m !== nothing
                return parse(Int, m.captures[1])
            end
        end
    end

    999
end

"""
    create_article_template(filepath::String; title::String="", order::Int=999)

Create a template article file.

# Arguments
- `filepath::String`: Path where to create the article
- `title::String`: Article title
- `order::Int`: Sort order
"""
function create_article_template(filepath::String; title::String="", order::Int=999)
    if isfile(filepath)
        @warn "Article already exists: $filepath"
        return
    end

    # Generate title from filename if not provided
    if isempty(title)
        title = titlecase(replace(basename(filepath), ".qmd" => "", "-" => " ", "_" => " "))
    end

    content = """---
title: "$title"
order: $order
---

Write your article content here.

## Section 1

Your content...

## Section 2

More content...
"""

    # Create parent directory if needed
    mkpath(dirname(filepath))

    write(filepath, content)
    @info "Created article template: $filepath"
end
