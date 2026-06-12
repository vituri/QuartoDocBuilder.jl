// QuartoDocBuilder Version Selector
//
// Works whether docs are hosted at a domain root (e.g. mydocs.org/dev/) or
// under a project-page subpath (e.g. user.github.io/Repo.jl/dev/). The site
// layout is assumed to be:
//
//   <siteBase>/versions.json
//   <siteBase>/dev/...
//   <siteBase>/stable/...
//   <siteBase>/v1.2.3/...
//
// where <siteBase> is discovered at runtime by walking up the URL path until
// versions.json is found. Each versions.json entry's `url` is treated as a
// version SEGMENT (leading/trailing slashes are stripped) and joined back onto
// the discovered base, so the manifest never needs to know the deploy prefix.
document.addEventListener('DOMContentLoaded', function() {
  const origin = window.location.origin;
  const segments = window.location.pathname.split('/').filter(s => s.length > 0);

  // Treat a trailing "...html" (or any segment containing a dot) as a file, not
  // a directory, so we start walking up from the directory that contains it.
  let dirCount = segments.length;
  if (dirCount > 0 && segments[dirCount - 1].indexOf('.') !== -1) {
    dirCount -= 1;
  }

  // Candidate site-base prefixes, deepest first. The deepest directory that
  // actually contains versions.json is the site base; version directories do
  // not contain a versions.json, so the first hit is the correct base.
  const basePrefixes = [];
  for (let i = dirCount; i >= 0; i--) {
    basePrefixes.push('/' + segments.slice(0, i).join('/'));
  }

  function normalizeBase(base) {
    // Collapse '//' (from the root case) and drop a trailing slash so we can
    // append '/versions.json' or '/<segment>/...' uniformly.
    let b = base.replace(/\/+/g, '/');
    if (b.length > 1 && b.endsWith('/')) b = b.slice(0, -1);
    return b === '' ? '/' : b;
  }

  function segmentOf(entry) {
    // entry.url like "/stable/" -> "stable"; tolerate a bare "stable" too.
    const raw = (entry.url || entry.version || '').toString();
    return raw.replace(/^\/+|\/+$/g, '');
  }

  function tryBases(index) {
    if (index >= basePrefixes.length) {
      console.warn('Version selector: could not locate versions.json');
      return;
    }
    const base = normalizeBase(basePrefixes[index]);
    const url = (base === '/' ? '' : base) + '/versions.json';
    fetch(url)
      .then(response => {
        if (!response.ok) throw new Error('not found');
        return response.json();
      })
      .then(data => initVersionSelector(data, base, segments.slice(
        base === '/' ? 0 : base.split('/').filter(s => s.length > 0).length)))
      .catch(() => tryBases(index + 1));
  }

  // `base` is the site base path; `rest` is the path segments after the base,
  // the first of which is the current version segment.
  function initVersionSelector(data, base, rest) {
    const selector = document.getElementById('version-selector');
    if (!selector || !data || !Array.isArray(data.versions)) return;

    const baseForUrls = (base === '/' ? '' : base);
    const currentSegment = rest.length > 0 ? rest[0] : '';
    const pageWithinVersion = rest.slice(1).join('/'); // e.g. "reference/foo.html"

    selector.innerHTML = '';

    data.versions.forEach(v => {
      const seg = segmentOf(v);
      if (!seg) return;

      const option = document.createElement('option');
      option.value = seg;
      option.text = v.version || seg;
      if (v.aliases && v.aliases.length > 0) {
        option.text += ' (' + v.aliases.join(', ') + ')';
      }

      // Mark the current version selected: either the path's version segment
      // matches this entry's segment, or it matches one of its aliases.
      if (currentSegment === seg ||
          (v.aliases && v.aliases.indexOf(currentSegment) !== -1)) {
        option.selected = true;
      }
      selector.appendChild(option);
    });

    selector.addEventListener('change', function(e) {
      const seg = e.target.value;
      const versionRoot = baseForUrls + '/' + seg + '/';
      const candidate = versionRoot + pageWithinVersion;

      // Try the same page in the target version; fall back to its index.
      fetch(candidate, { method: 'HEAD' })
        .then(response => {
          window.location.href = response.ok ? candidate : versionRoot;
        })
        .catch(() => {
          window.location.href = versionRoot;
        });
    });

    const container = selector.closest('.version-selector-container');
    if (container) {
      container.style.display = 'flex';
    }
  }

  tryBases(0);
});
