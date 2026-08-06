// Hostname router: one worker, one asset tree, three sites.
//   roostos.dev / www        → public/            (the hub)
//   perch.roostos.dev        → public/perch/      (Perch dashboard demo)
//   coop.roostos.dev         → public/coop/       (Coop engine simulation)
// Subdomain requests are rewritten into their folder so the demos' absolute
// asset paths (/assets/…, /demo/…) keep working unchanged.
const SUBSITES = {
  'perch.roostos.dev': '/perch',
  'coop.roostos.dev': '/coop',
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url)
    const prefix = SUBSITES[url.hostname]
    if (prefix) {
      // Plain concatenation: "/" → "/perch/" (the directory form the assets
      // layer serves without a canonicalizing redirect that would leak the
      // folder into the visitor's URL bar).
      url.pathname = prefix + url.pathname
      return env.ASSETS.fetch(new Request(url, req))
    }
    return env.ASSETS.fetch(req)
  },
}
