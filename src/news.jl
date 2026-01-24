# News/Changelog system for QuartoDocBuilder.jl
# Parses NEWS.md and generates a changelog page

"""
    NewsVersion

Represents a version entry in NEWS.md.

# Fields
- `version::String`: Version number (e.g., "1.0.0")
- `date::String`: Release date (if available)
- `categories::Dict{String, Vector{String}}`: Categories and their items
"""
struct NewsVersion
    version::String
    date::String
    categories::Dict{String, Vector{String}}
end

"""
    parse_news(path::String="NEWS.md") -> Vector{NewsVersion}

Parse NEWS.md into structured version entries.

Supports common formats:
- `# Package 1.0.0 (2024-01-15)`
- `# v1.0.0`
- `## Version 1.0.0`
- `# 1.0.0 - 2024-01-15`

Categories are identified by level-2 headers (`##`).

# Arguments
- `path::String`: Path to the NEWS.md file

# Returns
Vector of NewsVersion structs, most recent first.

# Example
```julia
versions = parse_news("NEWS.md")
for v in versions
    println("Version \$(v.version)")
    for (cat, items) in v.categories
        println("  \$cat: \$(length(items)) items")
    end
end
```
"""
function parse_news(path::String="NEWS.md")
    if !isfile(path)
        return NewsVersion[]
    end

    content = read(path, String)
    lines = split(content, "\n")

    versions = NewsVersion[]
    current_version = nothing
    current_category = "Changes"

    # Patterns for version headers
    # Matches: # Package 1.0.0 (2024-01-15), # v1.0.0, # 1.0.0 - date, ## Version 1.0.0
    version_patterns = [
        r"^#\s+\S+\s+v?(\d+\.\d+(?:\.\d+)?(?:-\w+)?)\s*(?:\(([^)]+)\))?",  # # Package 1.0.0 (date)
        r"^#\s+v?(\d+\.\d+(?:\.\d+)?(?:-\w+)?)\s*(?:-\s*(.+))?$",           # # v1.0.0 - date
        r"^##?\s+[Vv]ersion\s+v?(\d+\.\d+(?:\.\d+)?(?:-\w+)?)\s*(?:\(([^)]+)\))?",  # ## Version 1.0.0
    ]

    # Pattern for category headers
    category_pattern = r"^##\s+([^#].+)$"

    # Pattern for list items
    item_pattern = r"^[-*]\s+(.+)$"

    for line in lines
        line = rstrip(line)

        # Check for version header
        version_matched = false
        for pattern in version_patterns
            m = match(pattern, line)
            if m !== nothing
                # Save previous version if exists
                if current_version !== nothing
                    push!(versions, current_version)
                end

                version_str = m.captures[1]
                date_str = length(m.captures) >= 2 && m.captures[2] !== nothing ? strip(m.captures[2]) : ""

                current_version = NewsVersion(
                    version_str,
                    date_str,
                    Dict{String, Vector{String}}()
                )
                current_category = "Changes"
                version_matched = true
                break
            end
        end

        if version_matched
            continue
        end

        # Check for category header (only if we're in a version)
        if current_version !== nothing
            m = match(category_pattern, line)
            if m !== nothing
                current_category = strip(m.captures[1])
                # Skip if it looks like a version header that wasn't caught
                if !occursin(r"^\d+\.\d+", current_category) && !occursin(r"^[Vv]ersion", current_category)
                    if !haskey(current_version.categories, current_category)
                        current_version.categories[current_category] = String[]
                    end
                end
                continue
            end

            # Check for list item
            m = match(item_pattern, line)
            if m !== nothing
                item_text = strip(m.captures[1])
                if !haskey(current_version.categories, current_category)
                    current_version.categories[current_category] = String[]
                end
                push!(current_version.categories[current_category], item_text)
            end
        end
    end

    # Don't forget the last version
    if current_version !== nothing
        push!(versions, current_version)
    end

    versions
end

"""
    linkify_github_refs(text::String, repo::String) -> String

Convert GitHub references in text to clickable links.

Converts:
- `#123` -> `[#123](https://github.com/repo/issues/123)`
- `@username` -> `[@username](https://github.com/username)`
- `user/repo#123` -> `[user/repo#123](https://github.com/user/repo/issues/123)`

# Arguments
- `text::String`: Text containing references
- `repo::String`: Repository in "user/repo" format

# Returns
Text with references converted to markdown links.

# Example
```julia
text = "Fixed bug #42 reported by @user"
linkify_github_refs(text, "myorg/mypackage")
# "Fixed bug [#42](https://github.com/myorg/mypackage/issues/42) reported by [@user](https://github.com/user)"
```
"""
function linkify_github_refs(text::String, repo::String)
    if isempty(repo)
        return text
    end

    result = text

    # Link cross-repo issues: user/repo#123 -> [user/repo#123](https://github.com/user/repo/issues/123)
    result = replace(result, r"(\w+/\w+)#(\d+)" => s"[\1#\2](https://github.com/\1/issues/\2)")

    # Link issues/PRs in same repo: #123 -> [#123](https://github.com/repo/issues/123)
    # But not if already part of a link or cross-repo reference
    result = replace(result, r"(?<![/\[])#(\d+)" => SubstitutionString("[#\\1](https://github.com/$repo/issues/\\1)"))

    # Link usernames: @user -> [@user](https://github.com/user)
    # But not email addresses
    result = replace(result, r"(?<![a-zA-Z0-9.])@(\w+)(?!\.\w)" => s"[@\1](https://github.com/\1)")

    result
end

"""
    format_news_item(item::String, repo::String) -> String

Format a single news item with GitHub links and proper escaping.
"""
function format_news_item(item::String, repo::String)
    # Add GitHub links
    formatted = linkify_github_refs(item, repo)

    # Escape any remaining special characters that might break markdown
    # But preserve existing links
    formatted
end

"""
    quarto_news_page(config::QuartoConfig; output::String="docs/news.qmd")

Generate a formatted changelog page from NEWS.md.

Features:
- Most recent version expanded, older versions collapsed
- GitHub issue/PR links automatically created
- Categories organized as subsections

# Arguments
- `config::QuartoConfig`: Configuration with news settings
- `output::String`: Output file path

# Example
```julia
quarto_news_page(config)
# Creates docs/news.qmd with formatted changelog
```
"""
function quarto_news_page(config::QuartoConfig; output::String="docs/news.qmd")
    if !config.news
        return nothing
    end

    versions = parse_news(config.news_file)

    if isempty(versions)
        @info "No news found in $(config.news_file)"
        return nothing
    end

    repo = config.repo

    s = """---
title: "Changelog"
toc: true
toc-depth: 2
---

"""

    for (i, v) in enumerate(versions)
        version_header = "Version $(v.version)"
        if !isempty(v.date)
            version_header *= " ($(v.date))"
        end

        if i == 1
            # First (most recent) version - expanded
            s *= "## $version_header\n\n"
        else
            # Older versions - collapsible
            s *= "::: {.callout-note collapse=\"true\" title=\"$version_header\"}\n\n"
        end

        # Sort categories for consistent output
        sorted_categories = sort(collect(keys(v.categories)))

        for category in sorted_categories
            items = v.categories[category]
            if isempty(items)
                continue
            end

            s *= "### $category\n\n"
            for item in items
                formatted_item = format_news_item(item, repo)
                s *= "- $formatted_item\n"
            end
            s *= "\n"
        end

        if i == 1
            s *= "---\n\n"
        else
            s *= ":::\n\n"
        end
    end

    write(output, s)
    @info "Changelog page created at $output"
end

"""
    has_news(config::QuartoConfig) -> Bool

Check if a NEWS.md file exists.

# Arguments
- `config::QuartoConfig`: Configuration with news_file path
"""
function has_news(config::QuartoConfig)
    config.news && isfile(config.news_file)
end

"""
    news_summary(config::QuartoConfig) -> String

Get a brief summary of the latest version from NEWS.md.
Useful for including in the README or homepage.

# Arguments
- `config::QuartoConfig`: Configuration

# Returns
A markdown string with the latest version info, or empty string if no news.
"""
function news_summary(config::QuartoConfig)
    versions = parse_news(config.news_file)

    if isempty(versions)
        return ""
    end

    v = versions[1]  # Most recent

    summary = "### Latest: v$(v.version)"
    if !isempty(v.date)
        summary *= " ($(v.date))"
    end
    summary *= "\n\n"

    # Include up to 5 items from the first category
    if !isempty(v.categories)
        first_category = first(keys(v.categories))
        items = v.categories[first_category]
        for item in items[1:min(5, length(items))]
            summary *= "- $item\n"
        end
        if length(items) > 5
            summary *= "- *...and $(length(items) - 5) more*\n"
        end
    end

    summary
end

"""
    create_news_template(path::String="NEWS.md"; package_name::String="Package")

Create a template NEWS.md file.

# Arguments
- `path::String`: Path where to create the file
- `package_name::String`: Name of the package
"""
function create_news_template(path::String="NEWS.md"; package_name::String="Package")
    if isfile(path)
        @warn "NEWS.md already exists at $path"
        return
    end

    content = """# $package_name 0.1.0

## Features

- Initial release
- Add your new features here

## Bug fixes

- List bug fixes here

## Breaking changes

- List breaking changes here (if any)

---

*Format: Use `# Package X.Y.Z (YYYY-MM-DD)` for version headers and `## Category` for sections.*
"""

    write(path, content)
    @info "Created NEWS.md template at $path"
end
