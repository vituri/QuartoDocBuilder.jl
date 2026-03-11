using Test
using QuartoDocBuilder

module SampleDocsPackage
export documented_function, DocumentedType, DOCUMENTED_CONST, undocumented_function

"""
    documented_function(x)

Return `x + 1`.
"""
documented_function(x) = x + 1

"""
    DocumentedType

A documented sample type.
"""
struct DocumentedType
    value::Int
end

"""
    DOCUMENTED_CONST

A documented sample constant.
"""
const DOCUMENTED_CONST = 42

undocumented_function() = nothing
end

function with_temp_project(f::Function)
    mktempdir() do dir
        cd(dir) do
            f(dir)
        end
    end
end

@testset "QuartoDocBuilder" begin
    @testset "Old API Guard" begin
        err = try
            quarto_build_site(SampleDocsPackage; repo = "user/SampleDocsPackage.jl")
            nothing
        catch e
            e
        end

        @test err isa ErrorException
        @test occursin("no longer supported", sprint(showerror, err))
        @test occursin("QuartoConfig", sprint(showerror, err))
    end

    @testset "merge_config preserves base values" begin
        base = QuartoConfig(
            module_name = SampleDocsPackage,
            comments = false,
            news = false,
            repo = "user/base.jl",
            theme = ThemeConfig(
                bootswatch = "cosmo",
                dark_mode = false,
                custom_css = ".base { color: red; }"
            ),
            footer = FooterConfig(left = "Left side"),
            version = VersionConfig(enabled = true, keep_versions = 9)
        )

        merged = merge_config(
            base,
            QuartoConfig(
                module_name = SampleDocsPackage,
                theme = ThemeConfig(primary = "#123456"),
                footer = FooterConfig(right = "Right side"),
                version = VersionConfig(keep_versions = 3)
            )
        )

        @test merged.comments == false
        @test merged.news == false
        @test merged.repo == "user/base.jl"
        @test merged.theme.bootswatch == "cosmo"
        @test merged.theme.dark_mode == false
        @test merged.theme.primary == "#123456"
        @test merged.theme.custom_css == ".base { color: red; }"
        @test merged.footer.left == "Left side"
        @test merged.footer.right == "Right side"
        @test merged.version.enabled == true
        @test merged.version.keep_versions == 3
    end

    @testset "Reference index and autolinking use canonical page names" begin
        index = build_reference_index(SampleDocsPackage)

        @test index.entries["documented_function"] == "reference/documented_function.qmd"
        @test resolve_reference("documented_function", index) == "reference/documented_function.qmd"
        @test resolve_reference("SampleDocsPackage.documented_function()", index) == "reference/documented_function.qmd"

        linked = autolink_references(
            "Use `documented_function` and `SampleDocsPackage.documented_function()`.",
            index
        )
        @test occursin("[`documented_function`](reference/documented_function.qmd)", linked)
        @test occursin("[`SampleDocsPackage.documented_function()`](reference/documented_function.qmd)", linked)
    end

    @testset "Version manifests sort semantic versions correctly" begin
        with_temp_project() do dir
            manifest = generate_versions_manifest(
                joinpath(dir, "site"),
                "v1.10.0";
                existing_versions = ["v1.9.0", "dev"]
            )
            content = read(manifest, String)

            @test occursin("\"stable\": \"v1.10.0\"", content)
            @test findfirst("\"version\": \"v1.10.0\"", content) < findfirst("\"version\": \"v1.9.0\"", content)
        end
    end

    @testset "Link checking sees markdown and bare URLs" begin
        with_temp_project() do dir
            file = joinpath(dir, "links.qmd")
            write(file, """
            Bare URL: https://example.com
            Markdown URL: [Julia](https://julialang.org)
            Relative link: [Guide](guide.qmd)
            """)

            links = extract_links_from_file(file)
            urls = [url for (url, _) in links]

            @test "https://example.com" in urls
            @test "https://julialang.org" in urls
            @test "guide.qmd" in urls

            report = check_links(
                dir;
                ignore_patterns = ["example\\.com", "julialang\\.org"],
                verbose = false
            )
            checked = [result.url for result in report.results]
            @test "https://example.com" in checked
            @test "https://julialang.org" in checked
        end
    end

    @testset "Template generation uses the config API" begin
        with_temp_project() do _
            quarto_makejl_template(SampleDocsPackage; repo = "user/SampleDocsPackage.jl")
            template = read("docs/make.jl", String)

            @test occursin("config = QuartoConfig(", template)
            @test occursin("quarto_build_site(config)", template)
            @test !occursin("quarto_build_site(SampleDocsPackage;", template)

            quarto_makejl_template(
                SampleDocsPackage;
                config_file = "_quartodoc.toml",
                repo = "user/SampleDocsPackage.jl"
            )
            config_template = read("docs/make.jl", String)

            @test occursin("config = load_config(\"_quartodoc.toml\")", config_template)
            @test occursin("merge_config(default_config(", config_template)
        end
    end

    @testset "quarto_yaml_from_config emits navbar items and custom SCSS" begin
        with_temp_project() do _
            config = QuartoConfig(
                module_name = SampleDocsPackage,
                navbar_left = [NavbarItem(text = "Extra", href = "extra.qmd")],
                navbar_right = [NavbarItem(text = "Right", href = "right.qmd")],
                theme = ThemeConfig(
                    bootswatch = "flatly",
                    primary = "#123456",
                    custom_scss = "// test"
                )
            )

            quarto_yaml_from_config(config; force = true)
            yaml = read("docs/_quarto.yml", String)

            @test occursin("text: \"Extra\"", yaml)
            @test occursin("text: \"Right\"", yaml)
            @test occursin("custom.scss", yaml)
        end
    end

    @testset "quarto_build_site smoke test" begin
        with_temp_project() do _
            write("README.md", "# SampleDocsPackage\n\nWelcome to the docs.\n")
            write("NEWS.md", "# v1.0.0\n\n## Changes\n\n- Added `documented_function()`.\n")

            mkpath("docs/guides")
            write("docs/guides/getting-started.qmd", """
            ---
            title: "Guide"
            ---

            # Guide
            """)

            config = QuartoConfig(
                module_name = SampleDocsPackage,
                repo = "user/SampleDocsPackage.jl",
                reference = [
                    ReferenceGroup(title = "Core", contents = [:documented_function, :DocumentedType, :DOCUMENTED_CONST])
                ],
                sections = [
                    SectionConfig(title = "Guides", dir = "guides", order = 1)
                ],
                navbar_left = [NavbarItem(text = "Extra", href = "extra.qmd")],
                navbar_right = [NavbarItem(text = "Right", href = "right.qmd")],
                comments = false,
                theme = ThemeConfig(
                    bootswatch = "flatly",
                    primary = "#123456",
                    custom_scss = "// custom theme"
                )
            )

            quarto_build_site(config)

            @test isfile("docs/_quarto.yml")
            @test isfile("docs/styles.css")
            @test isfile("docs/custom.scss")
            @test isfile("docs/index.qmd")
            @test isfile("docs/reference.qmd")
            @test isfile("docs/reference/documented_function.qmd")
            @test isfile("docs/reference/DocumentedType.qmd")
            @test isfile("docs/reference/DOCUMENTED_CONST.qmd")
            @test isfile("docs/news.qmd")

            yaml = read("docs/_quarto.yml", String)
            @test occursin("text: \"Extra\"", yaml)
            @test occursin("text: \"Right\"", yaml)
            @test occursin("custom.scss", yaml)
            @test occursin("guides.qmd", yaml)
        end
    end

    @testset "setup_documentation creates a config-based scaffold" begin
        with_temp_project() do _
            write("README.md", "# SampleDocsPackage\n")

            setup_documentation(SampleDocsPackage; repo = "user/SampleDocsPackage.jl")

            makejl = read("docs/make.jl", String)
            @test isfile("docs/Project.toml")
            @test isfile(".github/workflows/docs.yml")
            @test isfile("docs/_quarto.yml")
            @test occursin("config = QuartoConfig(", makejl)
            @test occursin("quarto_build_site(config)", makejl)
            @test !occursin("quarto_build_site(SampleDocsPackage;", makejl)
        end
    end
end
