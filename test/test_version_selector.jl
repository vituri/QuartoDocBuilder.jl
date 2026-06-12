using Test
using QuartoDocBuilder

# Behavioural harness for the generated version-selector JavaScript. It stubs
# the bits of the browser the script touches (window.location, document, fetch)
# and checks that, given a versions.json published at the site root, the script:
#   * discovers versions.json by walking up the URL path (works under a project
#     subpath like user.github.io/Repo.jl/ as well as at a domain root),
#   * marks the current version as selected, and
#   * navigates to the correct URL when a different version is chosen.
const _VSEL_HARNESS = raw"""
import fs from 'fs';
const jsSource = fs.readFileSync(process.argv[2], 'utf8');

const manifest = {
  stable: 'v0.4.0', dev: 'dev',
  versions: [
    { version: 'stable', url: '/stable/', aliases: ['v0.4.0'] },
    { version: 'dev', url: '/dev/' },
    { version: 'v0.4.0', url: '/v0.4.0/' },
  ],
};

function runScenario({pathname, siteRootPath, expectSelected, change, expectNav}) {
  const options = [];
  let changeHandler = null;
  const selectEl = {
    innerHTML: '',
    appendChild(o) { options.push(o); },
    addEventListener(ev, fn) { if (ev === 'change') changeHandler = fn; },
    closest() { return { style: {} }; },
  };
  const win = { location: { origin: 'https://example.test', pathname, href: '' } };
  globalThis.window = win;
  globalThis.document = {
    _h: null,
    addEventListener(ev, fn) { if (ev === 'DOMContentLoaded') this._h = fn; },
    getElementById(id) { return id === 'version-selector' ? selectEl : null; },
    createElement() { const o = {}; Object.defineProperty(o,'text',{set(v){o._t=v;},get(){return o._t;},configurable:true}); return o; },
  };
  globalThis.fetch = (url, opts) => {
    if (opts && opts.method === 'HEAD') return Promise.resolve({ ok: true });
    return url === siteRootPath + '/versions.json'
      ? Promise.resolve({ ok: true, json: () => Promise.resolve(manifest) })
      : Promise.resolve({ ok: false });
  };
  eval(jsSource);
  return Promise.resolve(globalThis.document._h()).then(async () => {
    await new Promise(r => setTimeout(r, 15));
    const selected = options.filter(o => o.selected).map(o => o.value);
    let navResult = null;
    if (change && changeHandler) { await changeHandler({ target: { value: change } }); await new Promise(r => setTimeout(r, 15)); navResult = win.location.href; }
    const ok = JSON.stringify(selected) === JSON.stringify([expectSelected]) && (!change || navResult === expectNav);
    if (!ok) console.error('FAIL', pathname, {selected, navResult, expectSelected, expectNav});
    return ok;
  });
}

const scenarios = [
  { pathname: '/QuartoDocBuilder.jl/dev/reference/foo.html', siteRootPath: '/QuartoDocBuilder.jl', expectSelected: 'dev', change: 'stable', expectNav: '/QuartoDocBuilder.jl/stable/reference/foo.html' },
  { pathname: '/QuartoDocBuilder.jl/stable/', siteRootPath: '/QuartoDocBuilder.jl', expectSelected: 'stable', change: 'v0.4.0', expectNav: '/QuartoDocBuilder.jl/v0.4.0/' },
  { pathname: '/dev/reference.html', siteRootPath: '', expectSelected: 'dev', change: 'stable', expectNav: '/stable/reference.html' },
];
const results = [];
for (const s of scenarios) results.push(await runScenario(s));
process.exit(results.every(Boolean) ? 0 : 1);
"""

@testset "Version selector JS" begin
    js = QuartoDocBuilder._version_selector_js()

    @testset "structural markers" begin
        # Walks up the path to find versions.json instead of assuming a fixed location.
        @test occursin("versions.json", js)
        @test occursin("basePrefixes", js)
        # Treats manifest urls as version segments joined back onto the discovered base.
        @test occursin("segmentOf", js)
        # Does not hardcode the old root-only assumption.
        @test !occursin("origin + '/versions.json'", js)
    end

    @testset "behaviour (node)" begin
        node = Sys.which("node")
        if node === nothing
            @test_skip "node not available; skipping behavioural test"
        else
            mktempdir() do dir
                jspath = joinpath(dir, "vsel.js")
                harness = joinpath(dir, "harness.mjs")
                write(jspath, js)
                write(harness, _VSEL_HARNESS)
                ok = success(pipeline(`$node $harness $jspath`; stdout=stderr, stderr=stderr))
                @test ok
            end
        end
    end
end
