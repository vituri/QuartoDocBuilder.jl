# Documentation build script for QuartoDocBuilder.jl
# This script uses QuartoDocBuilder to document itself, and is meant to be a
# working example of the package's capabilities. It demonstrates:
#
#   - Grouped reference pages (the `reference` field below).
#   - Multiple navbar sections with dropdowns (the `sections` field).
#   - A changelog page generated from NEWS.md (`news = true`).
#   - Automatic cross-reference autolinking (on by default; `autolink = true`).
#   - Strict link checking: `strict = true` makes the build FAIL on any broken
#     internal link, the way Documenter.jl does. This site must pass it.
#   - An emitted `docs/objects.inv` (written on every build) so other packages
#     can cross-link back to this documentation.
#
# Submodule documentation (`include_submodules = true`) is left off here because
# QuartoDocBuilder has no documented submodules; see the "Configure the Build"
# how-to for that feature.

using Pkg
Pkg.activate(@__DIR__)
Pkg.develop(path=dirname(@__DIR__))
Pkg.instantiate()

using QuartoDocBuilder

# Full configuration demonstrating all features including MULTIPLE SECTIONS
config = QuartoConfig(
    module_name = QuartoDocBuilder,
    repo = "vituri/QuartoDocBuilder.jl",

    # Grouped reference page - organized by functionality
    reference = [
        ReferenceGroup(
            title = "Configuration",
            desc = "Types and functions for configuring documentation generation.",
            contents = [:QuartoConfig, :ReferenceGroup, :SectionConfig, :ThemeConfig,
                       :FooterConfig, :NavbarItem, :VersionConfig, :load_config,
                       :default_config, :validate_config, :merge_config,
                       :get_dark_theme, :detect_repo, :detect_version,
                       :determine_version_segment, :is_release_tag,
                       :get_current_tag, :get_current_branch]
        ),
        ReferenceGroup(
            title = "Content Selectors",
            desc = "pkgdown-style helpers for organizing reference pages by matching function names.",
            contents = [:starts_with, :ends_with, :matches, :contains,
                       :has_docstring, :is_exported, :is_function_symbol,
                       :is_type_symbol, :is_const_symbol, :parse_content_selector,
                       :apply_selector, :filter_objects, :group_objects,
                       :auto_group_objects, :autodocs_group, :reference_page_names,
                       :check_missing_docstrings, :documentation_coverage]
        ),
        ReferenceGroup(
            title = "Site Building",
            desc = "Core functions for generating documentation sites.",
            contents = [:quarto_build_site, :quarto_yaml_from_config, :quarto_index,
                       :quarto_git_ignore, :quarto_build_refpage,
                       :quarto_build_refpage_grouped, :quarto_rebuild_reference,
                       :quarto_rebuild_all, :quarto_styles_from_config]
        ),
        ReferenceGroup(
            title = "Docstring Processing",
            desc = "Functions for extracting and formatting Julia docstrings to Quarto format.",
            contents = [:quarto_format, :quarto_doc, :quarto_doc_page,
                       :quarto_doc_short, :quarto_callout_block, :get_objects_from_module]
        ),
        ReferenceGroup(
            title = "Articles & News",
            desc = "Article discovery and changelog generation.",
            contents = [:discover_articles, :discover_articles_recursive, :detect_get_started,
                       :get_article_title, :get_article_info, :ArticleInfo,
                       :get_article_order, :create_article_template, :NewsVersion,
                       :parse_news, :linkify_github_refs,
                       :quarto_news_page, :has_news, :news_summary, :create_news_template]
        ),
        ReferenceGroup(
            title = "Auto-linking",
            desc = "Automatic cross-reference linking in documentation.",
            contents = [:ReferenceIndex, :build_reference_index, :autolink_references,
                       :autolink_cross_package, :resolve_reference,
                       :find_undefined_references, :create_reference_report,
                       :link_julia_docs, :ExternalDocsRegistry,
                       :register_external_docs, :get_external_docs_url,
                       :clear_external_docs, :list_external_docs,
                       :register_common_packages, :autolink_external,
                       :ExternalRef, :parse_external_ref, :resolve_external_ref]
        ),
        ReferenceGroup(
            title = "Inventories",
            desc = "Sphinx objects.inv read/write for cross-package linking.",
            contents = [:Inventory, :InventoryItem, :load_inventory,
                       :write_inventory, :generate_inventory, :resolve_inventory]
        ),
        ReferenceGroup(
            title = "Link Checking & Versioning",
            desc = "Utilities for validating docs links and managing multi-version documentation.",
            contents = [:LinkCheckResult, :LinkCheckReport, :extract_links,
                       :extract_links_from_file, :check_link, :check_links,
                       :check_internal_links, :format_linkcheck_report,
                       :write_version_selector_assets,
                       :generate_versions_manifest, :read_versions_manifest]
        ),
        ReferenceGroup(
            title = "GitHub Integration",
            desc = "CI/CD workflow generation and deployment helpers.",
            contents = [:quarto_github_action, :quarto_github_action_simple,
                       :quarto_github_action_versioned, :quarto_makejl_template,
                       :quarto_docs_project_toml, :quarto_setup_instructions,
                       :setup_documentation]
        )
    ],

    # MULTIPLE SECTIONS
    # Each section gets its own dropdown in the navbar
    sections = [
        SectionConfig(
            title = "Tutorials",
            dir = "tutorials",
            desc = "Step-by-step guides to get you started with QuartoDocBuilder.",
            order = 1
        ),
        SectionConfig(
            title = "Explanation",
            dir = "explanation",
            desc = "Understand how QuartoDocBuilder works under the hood.",
            order = 2
        ),
        SectionConfig(
            title = "How-to Guides",
            dir = "how-to",
            desc = "Task-oriented guides for common documentation tasks.",
            order = 3
        )
    ],

    # "Get Started" link in navbar
    get_started = "tutorials/getting-started.qmd",

    # News/changelog enabled
    news = true,
    news_file = "NEWS.md",

    # Build behaviour showcase: autolink is on by default; strict turns broken
    # internal links into a hard build error so this site stays link-clean.
    autolink = true,
    strict = true,

    # # Theme configuration
    # theme = ThemeConfig(
    #     bootswatch = "flatly",
    #     dark_mode = true,
    #     code_highlight = "github"
    # ),

    # Giscus comments
    comments = true,
    giscus_repo = "vituri/QuartoDocBuilder.jl",

    # Custom footer
    footer = FooterConfig(
        left = "Developed by [G. Vituri](https://github.com/vituri)",
        right = "Built with [QuartoDocBuilder.jl](https://github.com/vituri/QuartoDocBuilder.jl)"
    ),

    # Multi-version documentation (like Documenter.jl / pkgdown). main builds
    # deploy to /dev/, release tags to /vX.Y.Z/, and /stable/ tracks the latest
    # release. Pair this with the workflow from quarto_github_action_versioned().
    version = VersionConfig(
        enabled = true,
        dev_branch = "main",
        keep_versions = 5
    )
)

# Build the documentation site
println("Building QuartoDocBuilder.jl documentation...")
println("Using multiple sections: Tutorials, Explanation, How-to Guides")
quarto_build_site(config)

println()
println("Documentation build complete!")
println("To preview locally, run: cd docs && quarto preview")
println("To render HTML, run: cd docs && quarto render")
