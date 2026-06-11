using Test
using QuartoDocBuilder

# ---------------------------------------------------------------------------
# Sample module with cross-references and an intentionally broken one
# ---------------------------------------------------------------------------
module AutolinkSample
export alpha_func, beta_func, gamma_func

"""
    alpha_func(x)

Primary entry point. See `beta_func` for the next step and `ghost_function` for
something that does not exist.

```julia
# code block — backticks here should NOT be linked: `beta_func`
result = alpha_func(1)
```
"""
alpha_func(x) = x

"""
    beta_func(x)

Second step. Calls `alpha_func` internally.
"""
beta_func(x) = x

"""
    gamma_func(x)

Final step. Uses both `alpha_func` and `beta_func`.
"""
gamma_func(x) = x
end

# ---------------------------------------------------------------------------
# Local copy of the helper used in runtests.jl (must not import from there)
# ---------------------------------------------------------------------------
function with_temp_project(f::Function)
    mktempdir() do dir
        cd(dir) do
            f(dir)
        end
    end
end

# ---------------------------------------------------------------------------
# Helper: build a minimal site and return the docs/ dir path
# ---------------------------------------------------------------------------
function build_sample_site(; autolink::Bool=true, strict::Bool=false)
    write("README.md", "# AutolinkSample\n\nWelcome.\n")

    config = QuartoConfig(
        module_name = AutolinkSample,
        repo = "user/AutolinkSample.jl",
        reference = [
            ReferenceGroup(title="All", contents=[:alpha_func, :beta_func, :gamma_func])
        ],
        comments = false,
        news = false,
        autolink = autolink,
        strict = strict
    )
    quarto_build_site(config)
    "docs"
end

# ===========================================================================
@testset "AutolinkSample build tests" begin

    # -----------------------------------------------------------------------
    @testset "autolink=true: sibling-relative links inside reference pages" begin
        with_temp_project() do _
            build_sample_site(autolink=true)

            alpha_page = read("docs/reference/alpha_func.qmd", String)
            beta_page  = read("docs/reference/beta_func.qmd", String)
            gamma_page = read("docs/reference/gamma_func.qmd", String)

            # beta_func is mentioned in alpha_func's docstring; should be a
            # sibling-relative link (NOT "reference/beta_func.qmd")
            @test occursin("[`beta_func`](./beta_func.qmd)", alpha_page) ||
                  occursin("[`beta_func`](beta_func.qmd)", alpha_page)

            # alpha_func is mentioned in beta_func's docstring
            @test occursin("[`alpha_func`](./alpha_func.qmd)", beta_page) ||
                  occursin("[`alpha_func`](alpha_func.qmd)", beta_page)

            # gamma_func mentions both
            @test occursin("alpha_func", gamma_page)
            @test occursin("beta_func", gamma_page)

            # Self-reference: alpha_func page should NOT link alpha_func to itself
            # (the entry for self is deleted from the index before autolinking)
            # Check that alpha_func doesn't appear as a link target pointing to itself
            @test !occursin("[`alpha_func`](./alpha_func.qmd)", alpha_page) &&
                  !occursin("[`alpha_func`](alpha_func.qmd)", alpha_page)

            # Sibling links must NOT use the "reference/" prefix
            @test !occursin("reference/reference/", alpha_page)
            @test !occursin("reference/reference/", beta_page)
            @test !occursin("reference/reference/", gamma_page)
        end
    end

    # -----------------------------------------------------------------------
    @testset "build writes objects.inv and resources entry" begin
        with_temp_project() do _
            build_sample_site(autolink=true)

            # objects.inv is emitted and parseable.
            @test isfile("docs/objects.inv")
            inv = QuartoDocBuilder.load_inventory("docs/objects.inv")
            names = [it.name for it in inv.items]
            @test "AutolinkSample.alpha_func" in names
            @test "AutolinkSample.beta_func" in names
            @test "AutolinkSample.gamma_func" in names

            # URIs follow the reference/<name>.html#sec-doc layout.
            alpha = inv.items[findfirst(it -> it.name == "AutolinkSample.alpha_func", inv.items)]
            @test alpha.uri == "reference/alpha_func.html#sec-doc"

            # _quarto.yml registers objects.inv as a resource so Quarto copies it.
            yaml = read("docs/_quarto.yml", String)
            @test occursin("resources:", yaml)
            @test occursin("objects.inv", yaml)
        end
    end

    # -----------------------------------------------------------------------
    @testset "autolink=true: no double-links in reference.qmd" begin
        with_temp_project() do _
            build_sample_site(autolink=true)

            ref_page = read("docs/reference.qmd", String)

            # Must not contain nested link syntax like [[`foo`](...)
            @test !occursin("[[`", ref_page)

            # Must not contain reference/reference/ paths
            @test !occursin("reference/reference/", ref_page)
        end
    end

    # -----------------------------------------------------------------------
    @testset "autolink=true: fenced code blocks are not linkified" begin
        with_temp_project() do _
            build_sample_site(autolink=true)

            alpha_page = read("docs/reference/alpha_func.qmd", String)

            # The code block in alpha_func's docstring contains the literal text
            # "`beta_func`". After autolinking, it must remain plain inside the fence.
            # We locate the fenced block and confirm no link was inserted there.
            m = match(r"```[\s\S]*?```", alpha_page)
            if m !== nothing
                fence_text = m.match
                @test !occursin("[`beta_func`]", fence_text)
            end
        end
    end

    # -----------------------------------------------------------------------
    @testset "autolink=false: backtick references remain plain" begin
        with_temp_project() do _
            build_sample_site(autolink=false)

            beta_page = read("docs/reference/beta_func.qmd", String)

            # With autolinking off, "`alpha_func`" should not be a markdown link
            @test !occursin("[`alpha_func`](", beta_page)
        end
    end

    # -----------------------------------------------------------------------
    @testset "strict=false: broken link emits warning but does not throw" begin
        with_temp_project() do _
            write("README.md", "# AutolinkSample\n\nWelcome.\n")

            config = QuartoConfig(
                module_name = AutolinkSample,
                repo = "user/AutolinkSample.jl",
                comments = false,
                news = false,
                autolink = false,
                strict = false
            )

            # Build succeeds (no throw) even with ghost_function reference which
            # will never resolve to a file (it's not a documented binding).
            # Then inject a broken link and confirm _validate_internal_links
            # only warns (does not throw) when strict=false.
            quarto_build_site(config)

            ref_page = "docs/reference.qmd"
            existing = read(ref_page, String)
            write(ref_page, existing * "\n[broken](reference/nonexistent.qmd)\n")

            # strict=false should warn but not throw
            warned = false
            try
                @test_logs (:warn,) QuartoDocBuilder._validate_internal_links("docs"; strict=false)
                warned = true
            catch
                warned = false
            end
            @test warned
        end
    end

    # -----------------------------------------------------------------------
    @testset "strict=true: broken internal link causes error" begin
        with_temp_project() do _
            write("README.md", "# AutolinkSample\n\nWelcome.\n")

            config = QuartoConfig(
                module_name = AutolinkSample,
                repo = "user/AutolinkSample.jl",
                comments = false,
                news = false,
                autolink = false,
                strict = true
            )

            # Build base site first (strict=false so it won't throw on its own)
            config_permissive = QuartoConfig(
                module_name = AutolinkSample,
                repo = "user/AutolinkSample.jl",
                comments = false,
                news = false,
                autolink = false,
                strict = false
            )
            quarto_build_site(config_permissive)

            # Now manually inject a broken link into a generated file
            ref_page = "docs/reference.qmd"
            existing = read(ref_page, String)
            write(ref_page, existing * "\n[broken link](reference/missing.qmd)\n")

            # Re-running validation alone via the private helper should throw
            err = try
                QuartoDocBuilder._validate_internal_links("docs"; strict=true)
                nothing
            catch e
                e
            end

            @test err isa ErrorException
            @test occursin("missing.qmd", sprint(showerror, err))
        end
    end

    # -----------------------------------------------------------------------
    @testset "strict=true error message names missing target" begin
        with_temp_project() do _
            write("README.md", "# AutolinkSample\n\nWelcome.\n")

            config_permissive = QuartoConfig(
                module_name = AutolinkSample,
                repo = "user/AutolinkSample.jl",
                comments = false,
                news = false,
                autolink = false,
                strict = false
            )
            quarto_build_site(config_permissive)

            ref_page = "docs/reference.qmd"
            existing = read(ref_page, String)
            write(ref_page, existing * "\n[see this](reference/does_not_exist.qmd)\n")

            err = try
                QuartoDocBuilder._validate_internal_links("docs"; strict=true)
                nothing
            catch e
                e
            end

            @test err !== nothing
            @test occursin("does_not_exist.qmd", sprint(showerror, err))
        end
    end

end
