"""
    QuartoDocBuilder

A Julia package for building documentation websites using Quarto,
inspired by R's pkgdown package.

# Features
- Generate documentation from Julia docstrings
- Organized reference pages with grouping
- Articles/vignettes support
- Changelog generation from NEWS.md
- GitHub Actions integration
- Customizable themes and navigation

# Quick Start
```julia
using MyPackage
using QuartoDocBuilder

# Simple usage
quarto_build_site(MyPackage; repo="user/MyPackage.jl")

# With configuration
config = QuartoConfig(
    module_name = MyPackage,
    repo = "user/MyPackage.jl",
    reference = [
        ReferenceGroup(title="Core", contents=[:main_func]),
        ReferenceGroup(title="Utils", contents=[starts_with("util_")])
    ],
    theme = ThemeConfig(bootswatch="flatly", dark_mode=true)
)
quarto_build_site(config)
```
"""
module QuartoDocBuilder

using Markdown
using TOML

# ============================================================================
# Configuration (must be loaded first as other modules depend on it)
# ============================================================================
include("config.jl")

export QuartoConfig, ReferenceGroup, ArticleConfig, ThemeConfig, FooterConfig, NavbarItem
export load_config, default_config, validate_config, merge_config
export get_dark_theme, detect_repo

# ============================================================================
# Content Selectors
# ============================================================================
include("selectors.jl")

export starts_with, ends_with, matches, contains
export has_docstring, is_exported, is_function_symbol, is_type_symbol, is_const_symbol
export parse_content_selector, apply_selector, filter_objects, group_objects, auto_group_objects

# ============================================================================
# Core Utilities
# ============================================================================

"""
    get_objects_from_module(m::Module) -> Vector

Get all documented objects from a module using Base.Docs.meta().
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
export get_article_title, get_article_info, ArticleInfo
export quarto_articles_index, quarto_articles_index_manual
export build_articles_navbar, build_articles_yaml
export create_articles_directory, create_article_template

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

# ============================================================================
# Styles
# ============================================================================
include("styles.jl")

export quarto_styles, quarto_styles_from_config

# ============================================================================
# Site Building (depends on all above)
# ============================================================================
include("build.jl")

export quarto_yaml, quarto_yaml_from_config
export quarto_index, quarto_git_ignore
export quarto_build_site, quarto_build_refpage, quarto_build_refpage_grouped
export quarto_rebuild_reference, quarto_rebuild_all

# ============================================================================
# GitHub Actions
# ============================================================================
include("github_actions.jl")

export quarto_github_action, quarto_github_action_simple
export quarto_makejl_template, quarto_docs_project_toml
export quarto_setup_instructions, setup_documentation

end # module QuartoDocBuilder
