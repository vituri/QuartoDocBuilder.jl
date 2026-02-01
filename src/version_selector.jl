# Version selector UI for QuartoDocBuilder.jl
# Generates JavaScript, CSS, and HTML for the version dropdown in navbar

"""
    _version_selector_js() -> String

Generate JavaScript for the version selector dropdown.
Handles fetching versions.json and navigating between versions.
"""
function _version_selector_js()
    return """
// QuartoDocBuilder Version Selector
document.addEventListener('DOMContentLoaded', function() {
  // Find the base path for the site (go up from versioned directory)
  const pathParts = window.location.pathname.split('/').filter(p => p);
  let basePath = '/';

  // Try to find versions.json by going up the path
  const versionsUrls = [
    window.location.origin + '/versions.json',
    window.location.origin + '/' + pathParts[0] + '/../versions.json'
  ];

  // Function to try fetching versions.json
  function fetchVersions(urls, index = 0) {
    if (index >= urls.length) {
      console.warn('Version selector: Could not find versions.json');
      return;
    }

    fetch(urls[index])
      .then(response => {
        if (!response.ok) throw new Error('Not found');
        return response.json();
      })
      .then(data => initVersionSelector(data))
      .catch(() => fetchVersions(urls, index + 1));
  }

  function initVersionSelector(data) {
    const selector = document.getElementById('version-selector');
    if (!selector) return;

    // Clear loading option
    selector.innerHTML = '';

    // Populate dropdown
    data.versions.forEach(v => {
      const option = document.createElement('option');
      option.value = v.url;
      option.text = v.version;
      if (v.aliases && v.aliases.length > 0) {
        option.text += ' (' + v.aliases.join(', ') + ')';
      }
      // Mark current version as selected based on URL path
      const currentPath = window.location.pathname;
      if (currentPath.startsWith(v.url) ||
          (v.aliases && v.aliases.some(a => currentPath.includes('/' + a + '/')))) {
        option.selected = true;
      }
      selector.appendChild(option);
    });

    // Show the selector container
    const container = selector.closest('.version-selector-container');
    if (container) {
      container.style.display = 'flex';
    }
  }

  // Handle version change
  const selector = document.getElementById('version-selector');
  if (selector) {
    selector.addEventListener('change', function(e) {
      const targetBase = e.target.value;
      const currentPath = window.location.pathname;

      // Extract the page path (after version segment)
      // e.g., /v1.0.0/reference/func.html -> reference/func.html
      const pathMatch = currentPath.match(/^\\/[^\\/]+\\/(.*)\$/);
      const pagePath = pathMatch ? pathMatch[1] : '';

      // Build target URL
      const targetUrl = targetBase + pagePath;

      // Check if page exists in target version, fallback to index
      fetch(targetUrl, { method: 'HEAD' })
        .then(response => {
          if (response.ok) {
            window.location.href = targetUrl;
          } else {
            window.location.href = targetBase;
          }
        })
        .catch(() => {
          window.location.href = targetBase;
        });
    });
  }

  // Start fetching versions
  fetchVersions(versionsUrls);
});
"""
end

"""
    _version_selector_css() -> String

Generate CSS for the version selector dropdown styling.
"""
function _version_selector_css()
    return """
/* QuartoDocBuilder Version Selector Styles */
.version-selector-container {
  display: none; /* Hidden until JS loads versions */
  align-items: center;
  margin-left: 1rem;
  margin-right: 0.5rem;
}

.version-selector-container label {
  margin-right: 0.5rem;
  font-size: 0.875rem;
  color: var(--bs-navbar-color, rgba(255,255,255,0.85));
  white-space: nowrap;
}

#version-selector {
  padding: 0.25rem 0.5rem;
  border-radius: 4px;
  border: 1px solid var(--bs-border-color, rgba(255,255,255,0.3));
  background-color: transparent;
  color: var(--bs-navbar-color, rgba(255,255,255,0.85));
  font-size: 0.8125rem;
  cursor: pointer;
  min-width: 100px;
}

#version-selector:hover {
  border-color: var(--bs-navbar-hover-color, #fff);
}

#version-selector:focus {
  outline: none;
  border-color: var(--bs-primary, #0d6efd);
  box-shadow: 0 0 0 2px rgba(var(--bs-primary-rgb, 13, 110, 253), 0.25);
}

#version-selector option {
  background-color: var(--bs-body-bg, #fff);
  color: var(--bs-body-color, #212529);
}

/* Light navbar support */
.navbar-light .version-selector-container label {
  color: var(--bs-navbar-color, rgba(0,0,0,0.65));
}

.navbar-light #version-selector {
  color: var(--bs-navbar-color, rgba(0,0,0,0.65));
  border-color: var(--bs-border-color, rgba(0,0,0,0.2));
}

/* Mobile responsive */
@media (max-width: 991.98px) {
  .version-selector-container {
    margin: 0.5rem 0;
    padding: 0.5rem 1rem;
    width: 100%;
  }

  #version-selector {
    flex-grow: 1;
  }
}
"""
end

"""
    _version_selector_html() -> String

Generate the HTML for the version selector dropdown.
"""
function _version_selector_html()
    return """<div class="version-selector-container">
  <label for="version-selector">Version:</label>
  <select id="version-selector" aria-label="Select documentation version">
    <option value="#">Loading...</option>
  </select>
</div>"""
end

"""
    write_version_selector_assets(docs_dir::String)

Write the version selector JavaScript and CSS files to the docs directory.

# Arguments
- `docs_dir::String`: The docs directory path (default: "docs")
"""
function write_version_selector_assets(docs_dir::String="docs")
    # Write JavaScript file
    js_path = joinpath(docs_dir, "version-selector.js")
    open(js_path, "w") do io
        write(io, _version_selector_js())
    end
    @info "Created $js_path"

    # Write CSS file
    css_path = joinpath(docs_dir, "version-selector.css")
    open(css_path, "w") do io
        write(io, _version_selector_css())
    end
    @info "Created $css_path"
end

"""
    generate_versions_manifest(output_dir::String, current_version::String;
                               existing_versions::Vector{String}=String[],
                               stable_version::String="",
                               dev_url::String="dev") -> String

Generate or update the versions.json manifest file.

# Arguments
- `output_dir::String`: Directory where versions.json will be written
- `current_version::String`: The version being built (e.g., "v1.0.0", "dev")
- `existing_versions::Vector{String}`: List of existing versions to include
- `stable_version::String`: Which version is "stable" (empty = latest semver)
- `dev_url::String`: URL segment for dev docs (default: "dev")

# Returns
Path to the generated versions.json file.
"""
function generate_versions_manifest(output_dir::String, current_version::String;
                                    existing_versions::Vector{String}=String[],
                                    stable_version::String="",
                                    dev_url::String="dev")
    # Merge versions
    all_versions = unique(vcat(existing_versions, [current_version]))

    # Sort: dev first, then semver descending
    function version_sort_key(v)
        if v == dev_url
            return (0, "")
        elseif startswith(v, "v")
            return (1, v)
        else
            return (2, v)
        end
    end
    sort!(all_versions, by=version_sort_key)

    # Find stable version (latest semver if not specified)
    if isempty(stable_version)
        semver_versions = filter(v -> occursin(r"^v\d+\.\d+\.\d+", v), all_versions)
        if !isempty(semver_versions)
            # Sort semver and take latest
            stable_version = sort(semver_versions, rev=true)[1]
        end
    end

    # Build versions array
    versions_array = []

    # Add stable entry if we have one
    if !isempty(stable_version)
        push!(versions_array, Dict(
            "version" => "stable",
            "url" => "/stable/",
            "aliases" => [stable_version]
        ))
    end

    # Add all versions
    for v in all_versions
        push!(versions_array, Dict(
            "version" => v,
            "url" => "/$v/"
        ))
    end

    # Build manifest
    manifest = Dict(
        "current" => current_version,
        "stable" => stable_version,
        "dev" => dev_url,
        "versions" => versions_array
    )

    # Write manifest
    manifest_path = joinpath(output_dir, "versions.json")
    mkpath(dirname(manifest_path))
    open(manifest_path, "w") do io
        # Simple JSON serialization without external dependencies
        _write_json(io, manifest)
    end
    @info "Generated $manifest_path"

    return manifest_path
end

"""
Internal: Simple JSON writer without external dependencies.
"""
function _write_json(io::IO, data, indent::Int=0)
    spaces = "  " ^ indent
    if data isa Dict
        println(io, "{")
        items = collect(pairs(data))
        for (i, (k, v)) in enumerate(items)
            print(io, spaces, "  \"", k, "\": ")
            _write_json(io, v, indent + 1)
            if i < length(items)
                println(io, ",")
            else
                println(io)
            end
        end
        print(io, spaces, "}")
    elseif data isa Vector
        println(io, "[")
        for (i, item) in enumerate(data)
            print(io, spaces, "  ")
            _write_json(io, item, indent + 1)
            if i < length(data)
                println(io, ",")
            else
                println(io)
            end
        end
        print(io, spaces, "]")
    elseif data isa String
        print(io, "\"", escape_string(data), "\"")
    elseif data isa Number
        print(io, data)
    elseif data isa Bool
        print(io, data ? "true" : "false")
    elseif data === nothing
        print(io, "null")
    else
        print(io, "\"", string(data), "\"")
    end
end

"""
    read_versions_manifest(path::String) -> Vector{String}

Read existing versions from a versions.json manifest file.

# Arguments
- `path::String`: Path to the versions.json file

# Returns
Vector of version strings found in the manifest.
"""
function read_versions_manifest(path::String)
    if !isfile(path)
        return String[]
    end

    try
        content = read(path, String)
        # Simple JSON parsing for versions array
        versions = String[]
        for m in eachmatch(r"\"version\"\s*:\s*\"([^\"]+)\"", content)
            v = m.captures[1]
            if v != "stable"  # Skip stable alias
                push!(versions, v)
            end
        end
        return unique(versions)
    catch e
        @warn "Could not read versions manifest: $e"
        return String[]
    end
end
