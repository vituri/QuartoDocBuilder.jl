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
