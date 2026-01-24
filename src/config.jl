# Configuration system for QuartoDocBuilder.jl
# Provides type-safe configuration with TOML file support

using TOML

"""
Configuration for a reference section group.

# Fields
- `title::String`: Section title displayed in the reference page
- `desc::String`: Optional description below the title
- `subtitle::String`: Optional subtitle for subsections
- `contents::Vector{Any}`: List of function names, symbols, or selector functions
"""
Base.@kwdef struct ReferenceGroup
    title::String
    desc::String = ""
    subtitle::String = ""
    contents::Vector{Any} = Any[]
end

"""
Configuration for navbar items.

# Fields
- `text::String`: Display text for the menu item
- `href::String`: Link URL (empty for dropdown parents)
- `icon::String`: Bootstrap icon name (e.g., "github", "sun")
- `menu::Vector{NavbarItem}`: Nested items for dropdowns
"""
Base.@kwdef mutable struct NavbarItem
    text::String = ""
    href::String = ""
    icon::String = ""
    menu::Vector{NavbarItem} = NavbarItem[]
end

"""
Configuration for a navbar section (supports multiple dropdowns).

Each section can have its own directory of .qmd files that appear as a dropdown
in the navbar and as a sidebar when browsing that section.

# Fields
- `title::String`: Display title in navbar (required)
- `dir::String`: Directory containing .qmd files for this section
- `desc::String`: Description for the section index page
- `dropdown::Bool`: Whether to show as dropdown menu (default: true)
- `dropdown_limit::Int`: Max items before falling back to index link (default: 15)
- `index_file::String`: Name of index file (default: "{dir}.qmd" in docs/)
- `sidebar::Bool`: Whether to show sidebar when in this section (default: true)
- `order::Int`: Order in navbar (lower = more left, default: 100)

# Example
```julia
sections = [
    SectionConfig(title="Tutorials", dir="tutorials", order=1),
    SectionConfig(title="Explanation", dir="explanation", order=2),
    SectionConfig(title="How-to Guides", dir="how-to", order=3, dropdown_limit=20)
]
```
"""
Base.@kwdef struct SectionConfig
    title::String
    dir::String = ""
    desc::String = ""
    dropdown::Bool = true
    dropdown_limit::Int = 15
    index_file::String = ""
    sidebar::Bool = true
    order::Int = 100
end

"""
Configuration for page footer.

# Fields
- `left::String`: Left section content (markdown supported)
- `center::String`: Center section content
- `right::String`: Right section content
"""
Base.@kwdef struct FooterConfig
    left::String = ""
    center::String = ""
    right::String = ""
end

"""
Configuration for theming and appearance.

# Fields
- `bootswatch::String`: Bootswatch theme name (default: "flatly")
- `dark_mode::Bool`: Enable light/dark mode toggle (default: true)
- `primary::String`: Primary color (CSS color value)
- `bg::String`: Background color
- `fg::String`: Foreground/text color
- `accent::String`: Accent/link color
- `font_base::String`: Base font family
- `font_heading::String`: Heading font family
- `font_code::String`: Code font family
- `code_highlight::String`: Syntax highlighting theme (default: "github")
- `custom_css::String`: Additional CSS to include
- `custom_scss::String`: Additional SCSS variables
"""
Base.@kwdef struct ThemeConfig
    bootswatch::String = "flatly"
    dark_mode::Bool = true
    primary::String = ""
    bg::String = ""
    fg::String = ""
    accent::String = ""
    font_base::String = ""
    font_heading::String = ""
    font_code::String = ""
    code_highlight::String = "github"
    custom_css::String = ""
    custom_scss::String = ""
end

"""
Main configuration struct for QuartoDocBuilder.

# Fields
## Basic
- `module_name::Union{Module, Nothing}`: The module to document
- `output_dir::String`: Output directory for rendered site (default: "site")
- `repo::String`: GitHub repository in "user/repo" format

## Execution
- `freeze::String`: Quarto freeze option (default: "auto")
- `cache::String`: Quarto cache option (default: "true")
- `warning::String`: Show warnings (default: "false")

## Reference
- `reference::Vector{ReferenceGroup}`: Reference page organization

## Sections (Multiple Navbar Dropdowns)
- `sections::Vector{SectionConfig}`: Multiple navbar sections with dropdowns
- `get_started::String`: Path to "Get Started" page (shown prominently in navbar)

## News
- `news::Bool`: Generate news page from NEWS.md (default: true)
- `news_file::String`: Path to news file (default: "NEWS.md")

## Navigation
- `navbar_left::Vector{NavbarItem}`: Custom left navbar items
- `navbar_right::Vector{NavbarItem}`: Custom right navbar items

## Comments
- `comments::Bool`: Enable Giscus comments (default: true)
- `giscus_repo::String`: Repository for Giscus (defaults to `repo`)

## Appearance
- `theme::ThemeConfig`: Theme configuration

## Footer
- `footer::FooterConfig`: Footer configuration

# Example (with multiple sections)

```julia
config = QuartoConfig(
    module_name = MyPackage,
    repo = "user/MyPackage.jl",
    reference = [
        ReferenceGroup(title="Core", contents=[:main_func, :helper_func]),
        ReferenceGroup(title="Utils", contents=[starts_with("util_")])
    ],
    sections = [
        SectionConfig(title="Tutorials", dir="tutorials", order=1),
        SectionConfig(title="Explanation", dir="explanation", order=2),
        SectionConfig(title="How-to Guides", dir="how-to", order=3)
    ],
    theme = ThemeConfig(bootswatch="cosmo", dark_mode=true)
)
```
"""
Base.@kwdef struct QuartoConfig
    # Basic
    module_name::Union{Module, Nothing} = nothing
    output_dir::String = "site"
    repo::String = ""

    # Execution
    freeze::String = "auto"
    cache::String = "true"
    warning::String = "false"

    # Reference
    reference::Vector{ReferenceGroup} = ReferenceGroup[]

    # Sections (multiple navbar dropdowns)
    sections::Vector{SectionConfig} = SectionConfig[]
    get_started::String = ""

    # News
    news::Bool = true
    news_file::String = "NEWS.md"

    # Navigation
    navbar_left::Vector{NavbarItem} = NavbarItem[]
    navbar_right::Vector{NavbarItem} = NavbarItem[]

    # Comments
    comments::Bool = true
    giscus_repo::String = ""

    # Appearance
    theme::ThemeConfig = ThemeConfig()

    # Footer
    footer::FooterConfig = FooterConfig()
end

# Theme pairing for light/dark modes
const DARK_THEME_MAP = Dict{String, String}(
    "flatly" => "darkly",
    "cosmo" => "cyborg",
    "journal" => "slate",
    "litera" => "superhero",
    "lumen" => "solar",
    "minty" => "vapor",
    "pulse" => "quartz",
    "sandstone" => "slate",
    "simplex" => "superhero",
    "sketchy" => "slate",
    "spacelab" => "cyborg",
    "united" => "slate",
    "yeti" => "slate",
    "zephyr" => "vapor",
    "cerulean" => "cyborg",
    "lux" => "superhero",
    "materia" => "slate",
    "morph" => "vapor"
)

"""
    get_dark_theme(light_theme::String) -> String

Get the corresponding dark theme for a light Bootswatch theme.
"""
function get_dark_theme(light_theme::String)
    get(DARK_THEME_MAP, lowercase(light_theme), "darkly")
end

"""
    detect_repo() -> String

Try to detect the GitHub repository from git remote.
Returns empty string if not found.
"""
function detect_repo()
    try
        remote = read(`git remote get-url origin`, String)
        m = match(r"github\.com[:/](.+/.+?)(?:\.git)?$", strip(remote))
        return m !== nothing ? m.captures[1] : ""
    catch
        return ""
    end
end

"""
    default_config(module_name::Module) -> QuartoConfig

Generate a configuration with sensible defaults for a module.
Attempts to auto-detect repository from git remote.

# Arguments
- `module_name::Module`: The module to document

# Example
```julia
config = default_config(MyPackage)
```
"""
function default_config(module_name::Module)
    repo = detect_repo()
    QuartoConfig(
        module_name = module_name,
        repo = repo,
        giscus_repo = repo
    )
end

"""
    load_config(path::String="_quartodoc.toml") -> Union{QuartoConfig, Nothing}

Load configuration from a TOML file.
Returns `nothing` if the file doesn't exist.

# Arguments
- `path::String`: Path to the TOML configuration file

# Example
```julia
config = load_config("_quartodoc.toml")
if config !== nothing
    quarto_build_site(config)
end
```
"""
function load_config(path::String="_quartodoc.toml")
    if !isfile(path)
        return nothing
    end

    data = TOML.parsefile(path)
    _toml_to_config(data)
end

"""
    _toml_to_config(data::Dict) -> QuartoConfig

Internal function to convert TOML data to QuartoConfig.
"""
function _toml_to_config(data::Dict)
    # Parse project section
    project = get(data, "project", Dict())

    # Parse execution section
    execution = get(data, "execution", Dict())

    # Parse reference groups
    reference_data = get(data, "reference", [])
    reference = ReferenceGroup[]
    for group in reference_data
        push!(reference, ReferenceGroup(
            title = get(group, "title", ""),
            desc = get(group, "desc", ""),
            subtitle = get(group, "subtitle", ""),
            contents = get(group, "contents", Any[])
        ))
    end

    # Parse sections (multiple navbar dropdowns)
    sections_data = get(data, "sections", [])
    sections = SectionConfig[]
    for sec in sections_data
        push!(sections, SectionConfig(
            title = get(sec, "title", ""),
            dir = get(sec, "dir", ""),
            desc = get(sec, "desc", ""),
            dropdown = get(sec, "dropdown", true),
            dropdown_limit = get(sec, "dropdown_limit", 15),
            index_file = get(sec, "index_file", ""),
            sidebar = get(sec, "sidebar", true),
            order = get(sec, "order", 100)
        ))
    end

    # Parse theme section
    theme_data = get(data, "theme", Dict())
    theme = ThemeConfig(
        bootswatch = get(theme_data, "bootswatch", "flatly"),
        dark_mode = get(theme_data, "dark_mode", true),
        primary = get(theme_data, "primary", ""),
        bg = get(theme_data, "bg", ""),
        fg = get(theme_data, "fg", ""),
        accent = get(theme_data, "accent", ""),
        font_base = get(theme_data, "font_base", ""),
        font_heading = get(theme_data, "font_heading", ""),
        font_code = get(theme_data, "font_code", ""),
        code_highlight = get(theme_data, "code_highlight", "github"),
        custom_css = get(theme_data, "custom_css", ""),
        custom_scss = get(theme_data, "custom_scss", "")
    )

    # Parse footer section
    footer_data = get(data, "footer", Dict())
    footer = FooterConfig(
        left = get(footer_data, "left", ""),
        center = get(footer_data, "center", ""),
        right = get(footer_data, "right", "")
    )

    # Parse news section
    news_data = get(data, "news", Dict())

    # Build config
    repo = get(project, "repo", "")
    QuartoConfig(
        module_name = nothing,  # Will be set when calling quarto_build_site
        output_dir = get(project, "output_dir", "site"),
        repo = repo,
        freeze = string(get(execution, "freeze", "auto")),
        cache = string(get(execution, "cache", "true")),
        warning = string(get(execution, "warning", "false")),
        reference = reference,
        sections = sections,
        get_started = get(project, "get_started", ""),
        news = get(news_data, "enabled", true),
        news_file = get(news_data, "file", "NEWS.md"),
        comments = get(project, "comments", true),
        giscus_repo = get(project, "giscus_repo", repo),
        theme = theme,
        footer = footer
    )
end

"""
    validate_config(config::QuartoConfig) -> Bool

Validate a configuration struct. Returns true if valid.
Prints warnings for any issues found.

# Arguments
- `config::QuartoConfig`: Configuration to validate
"""
function validate_config(config::QuartoConfig)
    valid = true

    if config.module_name === nothing
        @warn "QuartoConfig: module_name is not set"
        valid = false
    end

    if isempty(config.repo)
        @warn "QuartoConfig: repo is not set. GitHub links and Giscus comments may not work."
    end

    # Validate theme
    valid_themes = ["cerulean", "cosmo", "cyborg", "darkly", "flatly", "journal",
                    "litera", "lumen", "lux", "materia", "minty", "morph", "pulse",
                    "quartz", "sandstone", "simplex", "sketchy", "slate", "solar",
                    "spacelab", "superhero", "united", "vapor", "yeti", "zephyr"]

    if !isempty(config.theme.bootswatch) && !(lowercase(config.theme.bootswatch) in valid_themes)
        @warn "QuartoConfig: Unknown bootswatch theme '$(config.theme.bootswatch)'. Valid themes: $(join(valid_themes, ", "))"
    end

    return valid
end

"""
    merge_config(base::QuartoConfig, overrides::QuartoConfig) -> QuartoConfig

Merge two configurations, with `overrides` taking precedence.
Useful for combining file-based config with programmatic options.
"""
function merge_config(base::QuartoConfig, overrides::QuartoConfig)
    QuartoConfig(
        module_name = overrides.module_name !== nothing ? overrides.module_name : base.module_name,
        output_dir = !isempty(overrides.output_dir) && overrides.output_dir != "site" ? overrides.output_dir : base.output_dir,
        repo = !isempty(overrides.repo) ? overrides.repo : base.repo,
        freeze = overrides.freeze != "auto" ? overrides.freeze : base.freeze,
        cache = overrides.cache != "true" ? overrides.cache : base.cache,
        warning = overrides.warning != "false" ? overrides.warning : base.warning,
        reference = !isempty(overrides.reference) ? overrides.reference : base.reference,
        sections = !isempty(overrides.sections) ? overrides.sections : base.sections,
        get_started = !isempty(overrides.get_started) ? overrides.get_started : base.get_started,
        news = overrides.news,
        news_file = overrides.news_file != "NEWS.md" ? overrides.news_file : base.news_file,
        navbar_left = !isempty(overrides.navbar_left) ? overrides.navbar_left : base.navbar_left,
        navbar_right = !isempty(overrides.navbar_right) ? overrides.navbar_right : base.navbar_right,
        comments = overrides.comments,
        giscus_repo = !isempty(overrides.giscus_repo) ? overrides.giscus_repo : base.giscus_repo,
        theme = overrides.theme,
        footer = overrides.footer
    )
end
