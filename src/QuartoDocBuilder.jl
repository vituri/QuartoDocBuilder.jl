module QuartoDocBuilder

using Markdown

function get_objects_from_module(m::Module)
    [k for (k, v) ∈ Base.Docs.meta(m)]
end

export get_objects_from_module;

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