module QuartoDocBuilder

using Markdown

include("quarto_format.jl");
export quarto_format, 
    quarto_doc,
    quarto_callout_block,
    quarto_doc_short,
    quarto_build_site;

include("build.jl");
export quarto_yaml,
    quarto_index,    
    quarto_doc_page,
    quarto_build_refpage,
    quarto_build_site;

include("styles.jl");
export quarto_styles;

end # module Pkgdown