using QuartoDocBuilder

module_name = "QuartoDocBuilder"
module_name = QuartoDocBuilder

fs = names(@eval $(Symbol(module_name)))[2:end]
fs = get_objects_from_module(module_name)
fs .|> quarto_doc_page

quarto_build_refpage(module_name)
# quarto_yaml(module_name)



# quarto_build_site(module_name, repo = "vituri/QuartoDocBuilder.jl")