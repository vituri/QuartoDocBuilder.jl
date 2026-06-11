# QuartoDocBuilder 0.4.0 (2026-06-11)

## New Features

- **Automatic cross-reference autolinking**: backticked mentions like `` `my_function` `` in docstrings now become links to the corresponding reference pages during `quarto_build_site`. Controlled by the new `QuartoConfig` field `autolink` (default `true`). Links inside code blocks and existing links are never touched.
- **Strict mode**: new `QuartoConfig` field `strict` (default `false`). After building, all internal links are validated; with `strict = true` the build fails listing every broken link (like Documenter.jl), otherwise a warning is emitted.
- **Inventory-based external cross-references**: external package links are now resolved through Sphinx `objects.inv` inventories (the format Documenter.jl publishes) instead of guessed URLs. `register_external_docs` loads inventories automatically; unresolvable references are left unlinked instead of producing broken URLs.
- **`objects.inv` emission**: every built site now ships its own `objects.inv` (via `generate_inventory`/`write_inventory`), so other packages can reliably cross-link to your documentation.
- **Submodule documentation**: new `QuartoConfig` field `include_submodules` (default `false`) documents bindings from nested submodules, with collision-safe page names (`Inner.foo.qmd` when `foo` exists in two modules). A warning now tells you when documented submodules are being skipped.
- New exports: `Inventory`, `InventoryItem`, `load_inventory`, `write_inventory`, `generate_inventory`, `resolve_inventory`, `reference_page_names`.

## Bug Fixes

- Fixed a crash in `quarto_doc_short` (and therefore in `quarto_build_site` with the default ungrouped reference page) for docstrings that start with a paragraph instead of a signature code block.
- Docstring rendering is now structure-agnostic: it walks the Markdown AST generically instead of assuming a fixed shape, so any well-formed docstring renders without errors.
- Admonitions now map to the correct Quarto callout types (`!!! note` → `callout-note`, `!!! tip` → `callout-tip`, `!!! danger` → `callout-important`, ...) instead of always rendering as warnings.
- All docstring headers are demoted consistently (H1→H3, H2→H4, ...), so headings inside docstrings no longer pollute the page table of contents.
- `resolve_external_ref`/`autolink_external` no longer fabricate `/lib/types/#` URLs that 404 on most sites.

## Breaking Changes

- `ExternalDocsRegistry` now stores inventories alongside base URLs (its field layout changed). Code constructing it via the zero-argument constructor is unaffected.
- New dependencies: CodecZlib (zlib for `objects.inv`) and Downloads.

# QuartoDocBuilder 0.2.0 (2026-01-25)

## Breaking Changes

- Removed deprecated kwarg-based API functions (`quarto_yaml`, `quarto_build_site(module; kwargs...)`)
- Removed broken article functions that referenced non-existent `config.articles` field:
  - `quarto_articles_index`
  - `quarto_articles_index_manual`
  - `build_articles_navbar`
  - `build_articles_yaml`
  - `create_articles_directory`

## New Features

- **Optional default styles**: Default QuartoDocBuilder CSS is now only applied when no bootswatch theme is specified
- New `use_default_styles` field in `ThemeConfig` for explicit control over default CSS
- Default styles are bundled in `src/default_styles.css` and automatically applied when:
  - No `bootswatch` theme is set
  - No custom CSS/SCSS is provided
  - `use_default_styles` is `true` (default)

## Bug Fixes

- Fixed code block formatting in docstrings showing raw `{julia}` markers (#fix)
- Fixed browser tab title showing "index" instead of package name on home page

## Improvements

- `quarto_index()` now adds proper YAML front matter with the package name as title
- Cleaner config-based API is now the only supported approach
- Updated module docstring with config-based examples

---

# QuartoDocBuilder 0.1.0 (2026-01-24)

## Features

- Initial release with pkgdown-like functionality for Julia packages
- Configuration system with type-safe `QuartoConfig` struct
- Reference page grouping with pkgdown-style selectors (`starts_with`, `ends_with`, `matches`, `contains`)
- Articles/vignettes system with auto-discovery and navbar dropdowns
- NEWS.md parsing and changelog page generation with GitHub issue linking
- Light/dark mode toggle with automatic theme pairing (flatly/darkly, cosmo/cyborg, etc.)
- Auto-linking of function references in documentation
- GitHub Actions workflow generation for automated deployment
- Giscus comments integration for reader feedback
- Custom theming support (colors, fonts, CSS/SCSS)
- TOML configuration file support (`_quartodoc.toml`)

## Dependencies

- Only uses Julia stdlib packages (Markdown, TOML)
- No external dependencies required
- Minimum Julia version: 1.6
