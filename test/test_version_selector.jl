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

// Minimal functional DOM so the script can inject the selector into a navbar
// (the real page has no pre-existing #version-selector element).
function makeEl(tag) {
  const el = {
    tag, children: [], attrs: {}, className: '', id: '', style: {}, _change: null,
    _text: '', _matchers: [],
    setAttribute(k, v) { this.attrs[k] = v; },
    appendChild(c) { this.children.push(c); c.parentNode = this; return c; },
    insertBefore(c, ref) {
      const i = this.children.indexOf(ref);
      this.children.splice(i < 0 ? this.children.length : i, 0, c);
      c.parentNode = this; return c;
    },
    addEventListener(ev, fn) { if (ev === 'change') this._change = fn; },
    matchesSel(sel) {
      if (sel[0] === '#') return this.id === sel.slice(1);
      if (sel[0] === '.') return this.className.split(/\s+/).indexOf(sel.slice(1)) !== -1;
      return false;
    },
    closest(sel) { let n = this; while (n) { if (n.matchesSel && n.matchesSel(sel)) return n; n = n.parentNode; } return null; },
    set innerHTML(v) { if (v === '') this.children = []; },
    get innerHTML() { return ''; },
  };
  Object.defineProperty(el, 'text', { set(v){el._text=v;}, get(){return el._text;}, configurable:true });
  Object.defineProperty(el, 'textContent', { set(v){el._text=v;}, get(){return el._text;}, configurable:true });
  return el;
}

function walk(node, fn) { fn(node); (node.children||[]).forEach(c => walk(c, fn)); }

function runScenario({pathname, siteRootPath, expectSelected, change, expectNav}) {
  const collapse = makeEl('div'); collapse.id = 'navbarCollapse';
  const win = { location: { origin: 'https://example.test', pathname, href: '' } };
  globalThis.window = win;
  globalThis.document = {
    _h: null,
    addEventListener(ev, fn) { if (ev === 'DOMContentLoaded') this._h = fn; },
    getElementById(id) { let found = null; walk(collapse, n => { if (n.id === id) found = n; }); return found; },
    querySelector(sel) {
      if (sel.indexOf('navbarCollapse') !== -1 || sel.indexOf('navbar-collapse') !== -1) return collapse;
      return null; // no .quarto-navbar-tools, no fallback navbar needed
    },
    createElement(tag) { return makeEl(tag); },
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
    const sel = globalThis.document.getElementById('version-selector');
    if (!sel) { console.error('FAIL: selector was not injected for', pathname); return false; }
    const container = sel.closest('.version-selector-container');
    const shown = container && container.style.display === 'flex';
    const options = sel.children;
    const selected = options.filter(o => o.selected).map(o => o.value);
    let navResult = null;
    if (change && sel._change) { await sel._change({ target: { value: change } }); await new Promise(r => setTimeout(r, 15)); navResult = win.location.href; }
    const ok = shown &&
      JSON.stringify(selected) === JSON.stringify([expectSelected]) &&
      (!change || navResult === expectNav);
    if (!ok) console.error('FAIL', pathname, {selected, navResult, expectSelected, expectNav, shown, injected: !!sel});
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
        # Builds and injects the dropdown into the navbar (Quarto escapes navbar
        # `text:` HTML, so the markup must not come from _quarto.yml).
        @test occursin("ensureSelector", js)
        @test occursin("navbar", js)
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
