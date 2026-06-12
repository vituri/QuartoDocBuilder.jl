using Test
using QuartoDocBuilder

# Helper: run a function in a temp directory, restoring original dir after
function with_temp_project(f)
    original = pwd()
    tmp = mktempdir()
    try
        cd(tmp)
        f(tmp)
    finally
        cd(original)
        rm(tmp; recursive=true, force=true)
    end
end

@testset "quarto_github_action_versioned" begin
    with_temp_project() do tmp
        quarto_github_action_versioned()

        path = joinpath(tmp, ".github", "workflows", "docs.yml")
        @test isfile(path)

        yaml = read(path, String)

        # 1. Valid YAML (pyyaml must parse it without error)
        ok = success(pipeline(`python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" $path`; stderr=devnull))
        @test ok

        # 2. No symlink creation
        @test !occursin("ln -s", yaml)

        # 3. Real directory copy and stable present
        @test occursin("cp -r", yaml)
        @test occursin("stable", yaml)

        # 4. .stable-version marker file written
        @test occursin(".stable-version", yaml)

        # 5. Python reads the marker file (not islink)
        @test occursin("open('.stable-version')", yaml)
        @test !occursin("os.path.islink('stable')", yaml)

        # 6. Root redirect: both stable/ and dev/ appear in redirect logic
        @test occursin("stable/", yaml)
        @test occursin("dev/", yaml)
        # The fallback logic must be present: redirect to dev/ when stable doesn't exist
        @test occursin("gh-pages/stable", yaml) || occursin("[ -d gh-pages/stable ]", yaml) || occursin("-d gh-pages/stable", yaml)

        # 7. GitHub expressions survived un-interpolated (not consumed by Julia)
        @test occursin("\${{ github.ref }}", yaml)
        @test occursin("VERSION_PATH", yaml)

        # 8. versions.json schema keys present
        @test occursin("'stable'", yaml) || occursin("\"stable\"", yaml)
        @test occursin("'versions'", yaml) || occursin("\"versions\"", yaml)
        @test occursin("/stable/", yaml)
        @test occursin("/dev/", yaml)

        # 9. Deploys are serialized so concurrent branch+tag runs can't
        #    force-push over each other (a fixed deploy concurrency group with
        #    cancel-in-progress: false).
        @test occursin("gh-pages-deploy", yaml)
        @test occursin("cancel-in-progress: false", yaml)
    end
end
