// Hostname router. The hub lives here; the Perch/Coop demos moved to their own
// domain — the old subdomains 301 so shared links keep working forever.
const MOVED = {
  'perch.roostos.dev': 'https://perch.perchmesh.dev',
  'coop.roostos.dev': 'https://coop.perchmesh.dev',
}

export default {
  async fetch(req, env) {
    const url = new URL(req.url)
    const dest = MOVED[url.hostname]
    if (dest) {
      return Response.redirect(dest + url.pathname + url.search, 301)
    }
    return env.ASSETS.fetch(req)
  },
}
