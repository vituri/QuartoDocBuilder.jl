"""
    QuartoDocBuilder

A Julia package for building documentation websites using Quarto,
inspired by R's pkgdown package and Documenter.jl.

# Features
- Generate documentation from Julia docstrings
- Organized reference pages with grouping
- Multiple navbar sections with dropdowns
- Articles/vignettes support
- Changelog generation from NEWS.md
- GitHub Actions integration
- Customizable themes and navigation
- Optional default styles (applied when no theme is specified)
- **Multi-version documentation** with version selector dropdown
- **Edit on GitHub links** for easy contributions
- **Auto-documentation** of all module symbols (`autodocs_group`)
- **Missing docstring detection** (`check_missing_docstrings`)
- **External cross-references** to other packages' documentation
- **Link checking** for broken URLs

# Quick Start
```julia
using MyPackage
using QuartoDocBuilder

# Simple usage (uses default styles)
config = QuartoConfig(
    module_name = MyPackage,
    repo = "user/MyPackage.jl"
)
quarto_build_site(config)

# With Quarto theme (default styles NOT applied)
config = QuartoConfig(
    module_name = MyPackage,
    repo = "user/MyPackage.jl",
    theme = ThemeConfig(bootswatch="flatly", dark_mode=true)
)
quarto_build_site(config)

# With multiple sections
config = QuartoConfig(
    module_name = MyPackage,
    repo = "user/MyPackage.jl",
    reference = [
        ReferenceGroup(title="Core", contents=[:main_func]),
        ReferenceGroup(title="Utils", contents=[starts_with("util_")])
    ],
    sections = [
        SectionConfig(title="Tutorials", dir="tutorials", order=1),
        SectionConfig(title="Explanation", dir="explanation", order=2),
        SectionConfig(title="How-to Guides", dir="how-to", order=3)
    ]
)
quarto_build_site(config)

# With versioned documentation (like DataFrames.jl)
config = QuartoConfig(
    module_name = MyPackage,
    repo = "user/MyPackage.jl",
    version = VersionConfig(
        enabled = true,
        dev_branch = "main",
        keep_versions = 5
    )
)
quarto_build_site(config)

# Then generate the versioned GitHub Actions workflow:
quarto_github_action_versioned()
```
"""
module QuartoDocBuilder

using Markdown
using TOML

# ============================================================================
# Configuration (must be loaded first as other modules depend on it)
# ============================================================================
include("config.jl")

export QuartoConfig, ReferenceGroup, SectionConfig, ThemeConfig, FooterConfig, NavbarItem, VersionConfig
export load_config, default_config, validate_config, merge_config
export get_dark_theme, detect_repo, detect_version, determine_version_segment
export is_release_tag, get_current_tag, get_current_branch

# ============================================================================
# Content Selectors
# ============================================================================
include("selectors.jl")

export starts_with, ends_with, matches, contains
export has_docstring, is_exported, is_function_symbol, is_type_symbol, is_const_symbol
export parse_content_selector, apply_selector, filter_objects, group_objects, auto_group_objects
export autodocs_group, check_missing_docstrings, documentation_coverage

# ============================================================================
# Core Utilities
# ============================================================================

"""
    get_objects_from_module(m::Module) -> Vector{Docs.Binding}

Get all documented objects from a module using Base.Docs.meta().
Returns a vector of Docs.Binding objects (preserving module context).
"""
function get_objects_from_module(m::Module)
    [k for (k, _) in Base.Docs.meta(m)]
end

export get_objects_from_module

# ============================================================================
# Markdown to Quarto Conversion
# ============================================================================
include("quarto_format.jl")

export quarto_format, quarto_doc, quarto_callout_block, quarto_doc_short, quarto_doc_page

# ============================================================================
# Articles System
# ============================================================================
include("articles.jl")

export discover_articles, discover_articles_recursive, detect_get_started
export get_article_title, get_article_info, ArticleInfo, get_article_order
export create_article_template

# ============================================================================
# News/Changelog System
# ============================================================================
include("news.jl")

export NewsVersion, parse_news, linkify_github_refs
export quarto_news_page, has_news, news_summary, create_news_template

# ============================================================================
# Auto-linking
# ============================================================================
include("autolink.jl")

export ReferenceIndex, build_reference_index, autolink_references
export resolve_reference, find_undefined_references, create_reference_report
export link_julia_docs
export ExternalDocsRegistry, register_external_docs, get_external_docs_url
export clear_external_docs, list_external_docs, register_common_packages
export autolink_external, ExternalRef, parse_external_ref, resolve_external_ref

# ============================================================================
# Styles
# ============================================================================
include("styles.jl")

export quarto_styles_from_config

# ============================================================================
# Version Selector
# ============================================================================
include("version_selector.jl")

export write_version_selector_assets, generate_versions_manifest, read_versions_manifest

# ============================================================================
# Link Checking
# ============================================================================
include("linkcheck.jl")

export LinkCheckResult, LinkCheckReport
export extract_links, extract_links_from_file, check_link
export check_links, check_internal_links, format_linkcheck_report

# ============================================================================
# Site Building (depends on all above)
# ============================================================================
include("build.jl")

export quarto_yaml_from_config
export quarto_index, quarto_git_ignore
export quarto_build_site, quarto_build_refpage, quarto_build_refpage_grouped
export quarto_rebuild_reference, quarto_rebuild_all

# ============================================================================
# GitHub Actions
# ============================================================================
include("github_actions.jl")

export quarto_github_action, quarto_github_action_simple, quarto_github_action_versioned
export quarto_makejl_template, quarto_docs_project_toml
export quarto_setup_instructions, setup_documentation

end # module QuartoDocBuilder
