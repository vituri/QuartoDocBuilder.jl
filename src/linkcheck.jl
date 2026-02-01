# Link checking functionality for QuartoDocBuilder.jl
# Validates internal and external links in documentation

"""
    LinkCheckResult

Result of checking a single link.
"""
struct LinkCheckResult
    url::String
    status::Symbol  # :ok, :broken, :timeout, :error, :skipped
    message::String
    source_file::String
    line_number::Int
end

"""
    LinkCheckReport

Summary report of link checking results.
"""
struct LinkCheckReport
    results::Vector{LinkCheckResult}
    total::Int
    ok::Int
    broken::Int
    skipped::Int
end

"""
    extract_links(text::String) -> Vector{String}

Extract all URLs from markdown text.

# Arguments
- `text::String`: Markdown text to scan

# Returns
Vector of URLs found in the text.
"""
function extract_links(text::String)
    links = String[]

    # Markdown links: [text](url)
    for m in eachmatch(r"\[([^\]]*)\]\(([^)]+)\)", text)
        url = m.captures[2]
        # Skip anchors and relative paths that don't look like URLs
        if !startswith(url, "#") && !startswith(url, "mailto:")
            push!(links, url)
        end
    end

    # Raw URLs (http:// or https://)
    for m in eachmatch(r"https?://[^\s\)>\]\"']+", text)
        push!(links, m.match)
    end

    unique(links)
end

"""
    extract_links_from_file(filepath::String) -> Vector{Tuple{String, Int}}

Extract all URLs from a file with line numbers.

# Arguments
- `filepath::String`: Path to the file

# Returns
Vector of (url, line_number) tuples.
"""
function extract_links_from_file(filepath::String)
    links = Tuple{String, Int}[]

    if !isfile(filepath)
        return links
    end

    lines = readlines(filepath)
    for (line_num, line) in enumerate(lines)
        # Markdown links: [text](url)
        for m in eachmatch(r"\[([^\]]*)\]\(([^)]+)\)", line)
            url = m.captures[2]
            if !startswith(url, "#") && !startswith(url, "mailto:")
                push!(links, (url, line_num))
            end
        end
    end

    links
end

"""
    check_link(url::String; timeout::Int=10) -> Tuple{Symbol, String}

Check if a URL is accessible.

# Arguments
- `url::String`: URL to check
- `timeout::Int`: Timeout in seconds (default: 10)

# Returns
Tuple of (status, message) where status is :ok, :broken, :timeout, or :error.
"""
function check_link(url::String; timeout::Int=10)
    # Skip local/relative links
    if !startswith(url, "http://") && !startswith(url, "https://")
        return (:skipped, "Local or relative link")
    end

    try
        # Use curl for checking (available on most systems)
        cmd = `curl -sI -o /dev/null -w "%{http_code}" --connect-timeout $timeout -L "$url"`
        result = read(cmd, String)
        status_code = parse(Int, strip(result))

        if status_code >= 200 && status_code < 400
            return (:ok, "HTTP $status_code")
        elseif status_code == 0
            return (:timeout, "Connection timeout")
        else
            return (:broken, "HTTP $status_code")
        end
    catch e
        if e isa ProcessFailedException
            return (:error, "Failed to connect")
        else
            return (:error, string(e))
        end
    end
end

"""
    check_links(docs_dir::String; timeout::Int=10, ignore_patterns::Vector{String}=String[], verbose::Bool=true) -> LinkCheckReport

Check all links in documentation files.

# Arguments
- `docs_dir::String`: Directory containing documentation files
- `timeout::Int`: Timeout for each link check (default: 10 seconds)
- `ignore_patterns::Vector{String}`: URL patterns to skip (regex)
- `verbose::Bool`: Print progress messages (default: true)

# Returns
LinkCheckReport with all results.

# Example
```julia
# Check all links in docs/
report = check_links("docs")

# Check with ignores
report = check_links("docs";
    ignore_patterns=["localhost", "127\\\\.0\\\\.0\\\\.1"],
    timeout=5
)

# Print broken links
for r in report.results
    if r.status == :broken
        println("\$(r.source_file):\$(r.line_number) - \$(r.url)")
    end
end
```
"""
function check_links(docs_dir::String;
    timeout::Int = 10,
    ignore_patterns::Vector{String} = String[],
    verbose::Bool = true
)
    results = LinkCheckResult[]

    # Find all markdown/qmd files
    files = String[]
    for (root, dirs, filenames) in walkdir(docs_dir)
        for f in filenames
            if endswith(f, ".md") || endswith(f, ".qmd")
                push!(files, joinpath(root, f))
            end
        end
    end

    verbose && @info "Checking links in $(length(files)) files..."

    # Collect all unique URLs with their sources
    url_sources = Dict{String, Vector{Tuple{String, Int}}}()

    for filepath in files
        links = extract_links_from_file(filepath)
        for (url, line_num) in links
            if !haskey(url_sources, url)
                url_sources[url] = Tuple{String, Int}[]
            end
            push!(url_sources[url], (filepath, line_num))
        end
    end

    verbose && @info "Found $(length(url_sources)) unique URLs to check"

    # Check each URL
    for (url, sources) in url_sources
        # Check if URL should be ignored
        should_skip = false
        for pattern in ignore_patterns
            if occursin(Regex(pattern), url)
                should_skip = true
                break
            end
        end

        if should_skip
            for (filepath, line_num) in sources
                push!(results, LinkCheckResult(url, :skipped, "Matched ignore pattern", filepath, line_num))
            end
            continue
        end

        # Check the URL
        verbose && print("  Checking: $url ... ")
        status, message = check_link(url; timeout=timeout)
        verbose && println(status)

        for (filepath, line_num) in sources
            push!(results, LinkCheckResult(url, status, message, filepath, line_num))
        end
    end

    # Summarize
    total = length(results)
    ok = count(r -> r.status == :ok, results)
    broken = count(r -> r.status == :broken || r.status == :error, results)
    skipped = count(r -> r.status == :skipped, results)

    report = LinkCheckReport(results, total, ok, broken, skipped)

    if verbose
        @info """
        Link check complete:
          Total: $total
          OK: $ok
          Broken: $broken
          Skipped: $skipped
        """

        if broken > 0
            @warn "Found $broken broken links:"
            for r in results
                if r.status == :broken || r.status == :error
                    println("  $(r.source_file):$(r.line_number)")
                    println("    URL: $(r.url)")
                    println("    Status: $(r.message)")
                end
            end
        end
    end

    report
end

"""
    check_internal_links(docs_dir::String; verbose::Bool=true) -> LinkCheckReport

Check internal/relative links in documentation files.
Verifies that referenced files exist.

# Arguments
- `docs_dir::String`: Directory containing documentation files
- `verbose::Bool`: Print progress messages (default: true)

# Returns
LinkCheckReport with results for internal links only.
"""
function check_internal_links(docs_dir::String; verbose::Bool=true)
    results = LinkCheckResult[]

    # Find all markdown/qmd files
    files = String[]
    for (root, dirs, filenames) in walkdir(docs_dir)
        for f in filenames
            if endswith(f, ".md") || endswith(f, ".qmd")
                push!(files, joinpath(root, f))
            end
        end
    end

    verbose && @info "Checking internal links in $(length(files)) files..."

    for filepath in files
        links = extract_links_from_file(filepath)
        file_dir = dirname(filepath)

        for (url, line_num) in links
            # Skip external URLs
            if startswith(url, "http://") || startswith(url, "https://")
                continue
            end

            # Skip anchors
            if startswith(url, "#")
                continue
            end

            # Remove anchor from path
            path = split(url, "#")[1]

            # Handle query parameters
            path = split(path, "?")[1]

            # Skip empty paths
            if isempty(path)
                continue
            end

            # Resolve relative path
            if startswith(path, "/")
                # Absolute path from docs root
                target = joinpath(docs_dir, path[2:end])
            else
                # Relative path from current file
                target = normpath(joinpath(file_dir, path))
            end

            # Check if target exists
            if isfile(target) || isdir(target)
                push!(results, LinkCheckResult(url, :ok, "File exists", filepath, line_num))
            else
                push!(results, LinkCheckResult(url, :broken, "File not found: $target", filepath, line_num))
            end
        end
    end

    # Summarize
    total = length(results)
    ok = count(r -> r.status == :ok, results)
    broken = count(r -> r.status == :broken, results)
    skipped = 0

    report = LinkCheckReport(results, total, ok, broken, skipped)

    if verbose && broken > 0
        @warn "Found $broken broken internal links:"
        for r in results
            if r.status == :broken
                println("  $(r.source_file):$(r.line_number)")
                println("    Link: $(r.url)")
                println("    Error: $(r.message)")
            end
        end
    end

    report
end

"""
    format_linkcheck_report(report::LinkCheckReport; include_ok::Bool=false) -> String

Format a link check report as markdown.

# Arguments
- `report::LinkCheckReport`: Report to format
- `include_ok::Bool`: Include successful links in report (default: false)

# Returns
Markdown-formatted report string.
"""
function format_linkcheck_report(report::LinkCheckReport; include_ok::Bool=false)
    md = "# Link Check Report\n\n"
    md *= "## Summary\n\n"
    md *= "| Status | Count |\n"
    md *= "|--------|-------|\n"
    md *= "| Total | $(report.total) |\n"
    md *= "| OK | $(report.ok) |\n"
    md *= "| Broken | $(report.broken) |\n"
    md *= "| Skipped | $(report.skipped) |\n\n"

    # Broken links
    broken = filter(r -> r.status == :broken || r.status == :error, report.results)
    if !isempty(broken)
        md *= "## Broken Links\n\n"
        for r in broken
            md *= "- **$(r.source_file):$(r.line_number)**\n"
            md *= "  - URL: `$(r.url)`\n"
            md *= "  - Error: $(r.message)\n"
        end
        md *= "\n"
    end

    # OK links (if requested)
    if include_ok
        ok = filter(r -> r.status == :ok, report.results)
        if !isempty(ok)
            md *= "## Valid Links\n\n"
            for r in ok
                md *= "- `$(r.url)` ($(r.source_file):$(r.line_number))\n"
            end
        end
    end

    md
end
