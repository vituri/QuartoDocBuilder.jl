"""
    quarto_styles()

Create the docs/styles.css file with some suggested css classes.
"""
function quarto_styles()
    s = """


.content-block {
    padding-top: 20px;
    padding-bottom: 10px;
    margin-left: 30px;
    margin-right: 30px;
  }
  
  
  @media(min-width: 900px) {
  .content-block {
    margin-left: 50px;
    margin-right: 50px;
  }
  }
  
  @media (min-width: 1200px) {
  .content-block {
    max-width: 1100px;
    margin-left: auto;
    margin-right: auto;
  }
  }
  
  .hero-banner {
    position: relative;
    background-color: rgb(240,245,249);
    display: flex;
    justify-content: center;
  }
  
  .hero-banner h1 {
    color: #39729E;
    font-size: 2.5rem;
  }
  
  
  .hero-banner .hero-image {
    position: absolute;
    display: none;
    height: auto;
  }
  
  .hero-banner .content-block {
    display: flex;
    flex-direction: row;
  }
  
  .hero-banner .content-block .hero-text {
    width: 65%;
  }
  
  .hero-banner .content-block .hero-animation {
    margin-left: 40px;
    margin-top: 45px;
    width: 350px;
    height: 455px;
  }
  
  .hero-banner .content-block .hero-animation video {
    width: 350px;
    height: 455px;
  }
  
  @media (min-width: 1000px) {
  .hero-banner .hero-image {
    display: initial;
    width: 270px;
  }
  }
  
  @media (min-width: 1200px) {
  .hero-banner .hero-image {
    width: 340px;
  }
  }
  
  @media (min-width: 1400px) {
  .hero-banner .hero-image {
    width: 440px;
  }
  }
  
  .hero-banner .hero-image p {
    margin-bottom: 0;
  }
  
  .hero-banner .hero-image-left {
    left: 0;
    bottom: 0;
  }
  
  .hero-banner .hero-image-right {
    right: 0;
    bottom: 0;
  }
  
  
  .hero-banner .content-block {
    z-index: 2;
  }
  
  @media (prefers-reduced-motion: reduce) {
    .hero-banner .content-block {
      max-width: 660px;
    }
    .hero-banner .content-block .hero-text {
      width: 100%;
    }
    
    .hero-banner .content-block .hero-animation {
      display: none;
    }
  }
  
  @media (max-width: 1200px)  {
    .hero-banner .content-block {
      max-width: 660px;
    }
    .hero-banner .content-block .hero-text {
      width: 100%;
    }
    
    .hero-banner .content-block .hero-animation {
      display: none;
    }
  }
  
  
  .hero-banner a {
    text-decoration: none;
  }
  
  .hero-banner h3 {
    margin-top: 1.3rem;
    margin-bottom: 1.3rem;
  }
  
  .hero-banner h4 {
    margin-top: 0;
  }
  
  .hero-banner a[role="button"] {
    margin-right: 17px;
    margin-top: 0.6rem;
    margin-bottom: 1.6rem;
  }
  
  
  .hero-banner #btn-guide {
    background-color: #959595 !important;
    border: none;
  }
  
  
  
  
  .hero-banner ul {
    padding-inline-start: 21px;
    font-size: 1.1rem;
  }
  
  .hero-banner ul li {
    padding-bottom: 0.4rem;
  }
  
  
  .alt-background {
    background-color: rgb(247,249,251);
    border-top: 1px solid #dee2e6;
    border-bottom: 1px solid #dee2e6;
  }
  
  .hello-quarto {
    padding-bottom: 1rem;
  }
  
  @media (min-width: 600px) {
  .hello-quarto-banner {
    display: inline-flex;
    align-content: center;
    justify-content: center;
  }
  
  .hello-quarto-banner h1 {
    margin-right: 40px;
  }
  }
  
  .hello-quarto-banner .nav-pills .nav-link.active, .nav-pills .show>.nav-link {
    border: none;
    border-bottom: 2px solid #39729E !important;
    color: #39729E;
    background-color: transparent;
    
  }
  
  .hello-quarto-banner .nav-pills button {
    width: 125px;
  }
  
  .hello-quarto .tab-content {
    border: none;
    padding: 0;
    color: rgb(84, 85, 85);
  }
  
  .hello-quarto .tab-content p {
    font-size: 1.1em;
    margin-bottom: 1.5em;
  }
  
  .hello-quarto div.sourceCode {
    background-color: white;
    border: 1px solid #dee2e6;
  }
  
  .hello-output {
    background-color: white;
    border: 1px solid #dee2e6;
    max-height: 660px;
  }
  
  .features {
    padding-bottom: 2em;
  }
  
  .feature {
    margin-top: 20px;
  }
  
  @media (min-width: 800px) { 
  .features {
    display: flex;
    flex-direction: row;
    flex-wrap: wrap;
    margin: 0 0 0 -30px;
    width: calc(100% + 30px);
  }
  .feature {
    width: calc(33% - 30px);
    margin: 20px 0 0 30px;
  }
  }
  
  .feature h3 {
    margin-top: 0;
  }
  
  .feature p:first-of-type {
    margin-bottom: 0.2rem;
    color: rgb(84, 85, 85);
  }
  
  .get-started {
     text-align: center;
     padding-bottom: 2rem;
  }
  
  .get-started h3 {
     margin-top: 1rem;
     margin-bottom: 2rem;
  }
  
  nav.page-navigation {
    display: none;
  }
  
  .nav-footer {
    border-top: none !important; 
  }
  
  .nav-pills .nav-link.active, .nav-pills .show>.nav-link {
    color: #fff;
    background-color: #ff7518;
  }

@media (min-width: 1020px) {
    .navbar-brand-container {
      margin-right: 1em;
    }
    }
    
    
    
    @media (max-width: 1060px) and (min-width: 991.98px) {
    
    #navbarCollapse ul:last-of-type a.nav-link {
      padding-left: .25em;
      padding-right: .25em;
    }
    
    .navbar #quarto-search {
      margin-left: .1em;
    }
    
    .navbar .bi-twitter,
    .navbar .bi-github,
    .navbar .bi-rss
     {
      font-size: .8em;
    }
    }
    
    
    @media (min-width: 991.98px) {
    #quarto-header {
      border-bottom: 1px solid #dee2e6;
    }
    }
    
    .navbar-brand > img {
      max-height: 36px;
    }
    
    
    .platform-table td {
      vertical-align: middle;
    }
    
    .platform-table td > div.sourceCode {
      margin-top: 0.3rem;
      margin-bottom: 0.3rem;
    }
    
    
    .document-example {
      opacity: 0.9;
      padding: 6px; 
      font-weight: 500;
      margin-bottom: 1rem;
    }
    
    .document-example div {
      padding: 5px;
    }
    
    
    .document-example .citation {
      color: blue;
    }
    
    .trademark {
      font-size: 0.6rem;
      display: inline-block;
      margin-left: -3px;
    }
    
    .search-attribution {
      margin-top: 20px;
      padding-bottom: 20px;
      height: 40px;
    }
    
    .download-button {
      margin-top: 1em;
    }
    
    .download-table {
      margin-bottom: 2em;  
    }
    
    .download-table p {
      margin-bottom: 0;
    }
    
    .download-table .checksum {
      color: var(--bs-primary);
      font-size: .775em;
      cursor: pointer;
      padding-top: 4px;
    }
    
    .download-button {
      display:flex;
      padding-bottom: 10px;
      padding-top: 10px;
    }
    
    .download-button .secondary {
      font-size: .775em;
      margin-bottom: 0;
    }
    
    .download-button .container {
      display: flex;
      padding-left: 10px;
      padding-right: 40px;
    }
    
    .download-button .icon-container {
      fill: white;
      width: 30px;
      margin-right: 15px;
    }
    
    iframe.reveal-demo {
      width: 100%;
      height: 350px;
      outline: none;
    }
    
    
    .slide-deck {
      border: 3px solid #dee2e6;
      width: 100%;
      height: 475px;
    }
    
    @media only screen and (max-width: 600px) {
     .slide-deck {
        height: 400px;
      }
    }
    
    
    @media (max-width: 575px) {
    
    .link-cards .card {
      margin-bottom: 20px;
      margin-right: 35px;
    }
    
    }
    
    @media (min-width: 576px) { 
    .link-cards {
      display: flex;
      flex-direction: row;
      flex-wrap: wrap;
    }
    
    .link-cards .card {
      width: 190px;
      margin: 0 20px 12px 0;
    }
    
    
    }
    
    
    .link-cards .card {
      border: none;
      padding: 0;
    }
    
    .link-cards .card-title h4 {
      margin-top: 0;
    }
    
    .link-cards .card-title p {
      margin-bottom: 0;
    }
    
    .link-cards .card-subtitle {
      margin-bottom: 0.7rem;
    }
    
    .link-cards .card-body {
      padding: 0.5rem;
      padding-left: 0.1rem;
    }
    
    .link-cards .card-body ul {
      margin-bottom: 0;
      padding-left: 0;
      list-style-type: none;
    }
    
    .link-cards .card-body ul a {
      text-decoration: none;
    }
    
    .link-cards .card-body ul li {
      padding-bottom: 0.2rem;
    }
    
    
    .card .source-code {
      margin-top: 3px;
    }
    
    .carousel.card {
      font-size: 16px;
      padding-top: 2em;
    }
    
    .carousel.card a {
      text-decoration: none;
    }
    
    .carousel img {
      width: 70%;
      margin-bottom: 110px;
    }
    
    .carousel .carousel-control-prev-icon, 
    .carousel .carousel-control-next-icon {
      margin-bottom: 110px;
    }
    
    
    .gallery-category {
      column-gap: 10px;
    }
    
    .btn-action-primary {
      color: white;
      background-color: #447099 !important;
    }
    
    .btn-action-primary:hover {
      color: white;
    }
    
    .btn-action {
      min-width: 165px;
      border-radius: 30px;
      border: none;
    }
    
    .panel-tabset[data-group="tools-tabset"] .choose-your-tool {
      max-width: 90px;
      margin-right: 25px;
      margin-top: 30px;
      font-weight: 300;
      font-size: 1.3rem;
      text-align: left;
      vertical-align: center;
    }
    
    .panel-tabset[data-group="tools-tabset"] .tab-content {
      border: none;
      padding-left: 5px;
    }
    
    .panel-tabset[data-group="tools-tabset"] .nav-tabs {
      border-bottom: none;
    }
    
    .panel-tabset[data-group="tools-tabset"] .nav-tabs .nav-link {
      text-align: center;
      margin-right: 10px;
      margin-top: 10px;
      color: inherit;
      width: 102px;
      font-size: 0.8em;
    }
    
    .panel-tabset[data-group="tools-tabset"] .nav-tabs .nav-link, 
    .panel-tabset[data-group="tools-tabset"] .nav-tabs .nav-link.active, 
    .panel-tabset[data-group="tools-tabset"] .nav-tabs .nav-item.show .nav-link {
      border: 1px solid  rgb(222, 226, 230);
      border-radius: 10px;
    }
    .panel-tabset[data-group="tools-tabset"] .nav-tabs .nav-link:hover {
       border-color: rgb(80,146,221);
       border-width: 1px;
    } 
    
    .panel-tabset[data-group="tools-tabset"] .nav-tabs .nav-link.active, 
    .panel-tabset[data-group="tools-tabset"] .nav-tabs .nav-item.show .nav-link {
      border-color: rgb(80,146,221);
      border-width: 2px;
    }
    
    .panel-tabset[data-group="tools-tabset"] .nav-tabs .nav-link img {
      width: 65px;
      height: 65px;
      display: block;
      margin-bottom: 2px;
    }
    
    /*
    .panel-tabset[data-group="tools-tabset"] .nav-tabs .nav-link {
      text-align: center;
      margin-right: 10px;
      margin-top: 10px;
      color: inherit;
      width: 102px;
      font-size: 0.8em;
    }
     
    .panel-tabset[data-group="tools-tabset"] .nav-tabs .nav-link img {
      width: 45px;
      height: 45px;
      margin-left: 10px;
      display: block;
      margin-bottom: 2px;
    }
    */
    
    
    .download-text {
      font-size: 1.1em;
      font-weight: 500;  
    }
    
    .preview-image-grid {
      gap: .75em;
    }
    
    .preview-image-grid p {
      margin-bottom: 0;
    }
    
    .preview-image-label {
      text-align: center;
      font-size: .75em;
      font-weight: 600;
    }
    
    .illustration {
      border: 1px solid #dee2e6;
    }

"""

write("docs/styles.css", s)

end

"""
    quarto_styles_from_config(config::QuartoConfig)

Generate CSS/SCSS files based on configuration.

Creates:
- `docs/styles.css` - Main CSS file with base styles and custom CSS
- `docs/custom.scss` - SCSS variables (if custom colors/fonts specified)

# Arguments
- `config::QuartoConfig`: Configuration with theme settings
"""
function quarto_styles_from_config(config::QuartoConfig)
    theme = config.theme

    # Generate SCSS variables if custom colors/fonts specified
    has_custom_scss = !isempty(theme.primary) || !isempty(theme.bg) ||
                      !isempty(theme.fg) || !isempty(theme.accent) ||
                      !isempty(theme.font_base) || !isempty(theme.font_heading) ||
                      !isempty(theme.font_code) || !isempty(theme.custom_scss)

    if has_custom_scss
        scss = "// Custom theme variables generated by QuartoDocBuilder\n\n"

        !isempty(theme.primary) && (scss *= "\$primary: $(theme.primary);\n")
        !isempty(theme.bg) && (scss *= "\$body-bg: $(theme.bg);\n")
        !isempty(theme.fg) && (scss *= "\$body-color: $(theme.fg);\n")
        !isempty(theme.accent) && (scss *= "\$link-color: $(theme.accent);\n")
        !isempty(theme.font_base) && (scss *= "\$font-family-sans-serif: $(theme.font_base);\n")
        !isempty(theme.font_heading) && (scss *= "\$headings-font-family: $(theme.font_heading);\n")
        !isempty(theme.font_code) && (scss *= "\$font-family-monospace: $(theme.font_code);\n")

        if !isempty(theme.custom_scss)
            scss *= "\n// Custom SCSS\n$(theme.custom_scss)\n"
        end

        write("docs/custom.scss", scss)
        @info "Created docs/custom.scss with theme customizations"
    end

    # Generate base CSS
    css = _base_styles()

    # Add CSS for custom primary color (as CSS variables for runtime)
    if !isempty(theme.primary)
        css *= """

/* Custom primary color */
:root {
  --primary-color: $(theme.primary);
}

a {
  color: var(--primary-color);
}

.btn-primary {
  background-color: var(--primary-color);
  border-color: var(--primary-color);
}
"""
    end

    # Add custom CSS
    if !isempty(theme.custom_css)
        css *= "\n/* Custom CSS */\n$(theme.custom_css)\n"
    end

    write("docs/styles.css", css)
    @info "Created docs/styles.css"
end

"""
Internal: Return the base CSS styles.
This is the same CSS as quarto_styles() but as a separate function for reuse.
"""
function _base_styles()
    """


.content-block {
    padding-top: 20px;
    padding-bottom: 10px;
    margin-left: 30px;
    margin-right: 30px;
  }


  @media(min-width: 900px) {
  .content-block {
    margin-left: 50px;
    margin-right: 50px;
  }
  }

  @media (min-width: 1200px) {
  .content-block {
    max-width: 1100px;
    margin-left: auto;
    margin-right: auto;
  }
  }

  .hero-banner {
    position: relative;
    background-color: rgb(240,245,249);
    display: flex;
    justify-content: center;
  }

  .hero-banner h1 {
    color: #39729E;
    font-size: 2.5rem;
  }


  .hero-banner .hero-image {
    position: absolute;
    display: none;
    height: auto;
  }

  .hero-banner .content-block {
    display: flex;
    flex-direction: row;
  }

  .hero-banner .content-block .hero-text {
    width: 65%;
  }

  .hero-banner .content-block .hero-animation {
    margin-left: 40px;
    margin-top: 45px;
    width: 350px;
    height: 455px;
  }

  .hero-banner .content-block .hero-animation video {
    width: 350px;
    height: 455px;
  }

  @media (min-width: 1000px) {
  .hero-banner .hero-image {
    display: initial;
    width: 270px;
  }
  }

  @media (min-width: 1200px) {
  .hero-banner .hero-image {
    width: 340px;
  }
  }

  @media (min-width: 1400px) {
  .hero-banner .hero-image {
    width: 440px;
  }
  }

  .hero-banner .hero-image p {
    margin-bottom: 0;
  }

  .hero-banner .hero-image-left {
    left: 0;
    bottom: 0;
  }

  .hero-banner .hero-image-right {
    right: 0;
    bottom: 0;
  }

  .feature-card h2 {
    font-size: 1.75rem;
  }

  .gallery-card {
    background-color: rgb(240,240,240);
    padding: 10px 5px;
    height: 100%;
  }

  .gallery-card p {
    text-align: center;
    font-size: 14px;
  }

  .gallery-card img {
    display: block;
    margin-left: auto;
    margin-right: auto;
  }

  .platform-table th, .platform-table td {
    padding: 15px;
    line-height: 1.0;
  }

  .platform-table h3 {
    font-size: 1.25rem;
    margin-bottom: 0;
  }

  .platform-table p, .platform-table tr > td:last-child {
    font-size: .9rem;
    margin-bottom: 0;
  }

  .tabset-block {
    padding-top: 20px;
    padding-bottom: 20px;
  }

  .hello-output {
    margin-top: 10px;
    overflow-x: auto;
  }

  .carousel {
    padding-top: 10px;
    padding-bottom: 10px;
    background-color: rgb(238, 243, 249);
    width: auto;
    /* Default: do not show */
    display: none;
  }

  @media(min-width: 575px) {
    .carousel {
      display: block;
    }
  }

  .carousel-control-prev-icon {
    background-image: url("data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' fill='rgb(130,130,130)' class='bi bi-chevron-left' viewBox='0 0 16 16'><path fill-rule='evenodd' d='M11.354 1.646a.5.5 0 0 1 0 .708L5.707 8l5.647 5.646a.5.5 0 0 1-.708.708l-6-6a.5.5 0 0 1 0-.708l6-6a.5.5 0 0 1 .708 0z'/></svg>") !important;
  }

  .carousel-control-next-icon {
    background-image: url("data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' fill='rgb(130,130,130)' class='bi bi-chevron-right' viewBox='0 0 16 16'><path fill-rule='evenodd' d='M4.646 1.646a.5.5 0 0 1 .708 0l6 6a.5.5 0 0 1 0 .708l-6 6a.5.5 0 0 1-.708-.708L10.293 8 4.646 2.354a.5.5 0 0 1 0-.708z'/></svg>") !important;
  }

  .carousel-control-prev-icon,
  .carousel-control-next-icon {
    width: 2rem;
    height: 2rem;
  }

  .carousel-inner {
    width: 85%;
    margin: auto;
    overflow: initial !important;
  }

  .carousel-item.active,
  .carousel-item-next,
  .carousel-item-prev {
    display: flex !important;
  }

  .carousel-gallery {
    display: flex;
    gap: 10px;
    justify-content: center;
    flex-wrap: wrap;
  }

  .carousel-gallery .gallery-item {
    flex: 1 1 auto;
    border: 3px solid white;
  }

  .carousel-gallery .gallery-item img,
  .carousel-gallery .gallery-item video {
    width: 100%;
    object-fit: cover;
    object-position: top;
  }

  @media(min-width: 575px) {
    .carousel-gallery .gallery-item {
      flex: 1 1 45%;
      max-width: 45%;
      aspect-ratio: auto;
    }

    .carousel-gallery .gallery-item img,
    .carousel-gallery .gallery-item video {
      aspect-ratio: 16/9;
    }
  }

  @media(min-width: 700px) {
    .carousel-gallery .gallery-item {
      flex: 1 1 30%;
      max-width: 30%;
    }
  }

  @media(min-width: 850px) {
    .carousel-gallery .gallery-item {
      flex: 1 1 24%;
      max-width: 24%;
    }
  }

  @media(min-width: 1200px) {
    .carousel-gallery .gallery-item {
      flex: 1 1 19%;
      max-width: 19%;
    }
  }

  .carousel-indicators {
    position: relative;
  }

  .carousel-indicators [data-bs-target] {
    border-radius: 50%;
    width: 8px;
    height: 8px;
    background-color: rgb(130,130,130);
    border-top: 0;
    border-bottom: 0;
    margin-right: 8px;
    margin-left: 8px;
  }

  .code-tabset {
    padding-bottom: 5px;
    font-size: 15px;
    margin-bottom: 5px;
    margin-top: -15px;
  }

  .code-tabset .nav-tabs {
    padding-bottom: 10px;
  }

  .code-tabset .tab-content {
    border: none;
  }

  .code-tabset .tab-content > .tab-pane {
    padding: 0;
  }

  .tab-content > .tab-pane > div {
    margin-top: 0;
  }

  .tab-content > .tab-pane .sourceCode {
    margin-top: 0;
  }

  .code-tabset .nav-tabs .nav-link {
    color: gray;
    background-color: transparent;
    border: none;
    padding-left: 0;
    padding-right: 0;
    margin-right: 10px;
  }

  .code-tabset .nav-tabs .nav-link.active {
    color: gray;
    border-bottom: solid 2px black;
  }

  .hello-output + pre, .hello-output + div + pre {
    margin-top: 10px;
  }

  .callout {
    margin-top: 10px;
    margin-bottom: 15px;
  }

  .get-started {
    margin-top: 50px;
    margin-bottom: 50px;
    font-size: 1.25rem;
  }

  .get-started p {
    margin-bottom: 0px;
  }

  .get-started .btn-primary {
    background-color: rgb(0, 130, 175);
    padding: 15px;
    padding-top: 12px;
    padding-bottom: 12px;
    border: none;
  }

  .get-started .btn-primary:hover {
    background-color: #39729E;
  }

  .get-started-gallery {
    flex-wrap: wrap;
    justify-content: center;
  }

  .get-started-gallery .gallery-item {
    flex: 1 1 auto;
    max-width: 200px;
  }

  .get-started-gallery img,
  .get-started-gallery video {
    aspect-ratio: 16/9;
    width: 100%;
    object-fit: cover;
    object-position: center;
  }

  @media(max-width: 575px) {
    .get-started-gallery .gallery-item {
      flex: 1 1 45%;
      max-width: 45%;
    }
  }

  .about-quarto {
    padding-bottom: 30px;
  }

  .about-quarto a {
    color: #0082af;
    text-decoration: none;
  }

  .about-quarto h2 {
    font-size: 20px;
    border-bottom: none;
    padding-bottom: 0;
    color: rgb(85,85,85);
  }

  .about-quarto ul {
    padding-inline-start: 0px;
  }

  .about-quarto li {
    list-style: none;
    font-size: 15px;
    padding-bottom: 2px;
  }

  .about-quarto hr {
    margin-bottom: 20px;
  }


    .download-text {
      font-size: 1.1em;
      font-weight: 500;
    }

    .preview-image-grid {
      gap: .75em;
    }

    .preview-image-grid p {
      margin-bottom: 0;
    }

    .preview-image-label {
      text-align: center;
      font-size: .75em;
      font-weight: 600;
    }

    .illustration {
      border: 1px solid #dee2e6;
    }

"""
end