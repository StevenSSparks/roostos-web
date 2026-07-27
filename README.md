# roostos-web

Marketing site for **RoostOS** — https://roostos.dev

Static multi-page site in `public/`, served on Cloudflare (Workers Assets).

## Pages
- `public/index.html` — hub: hero with both devices, "what it does" photo strip,
  the two builds, what's unique, build-it-yourself steps, where-to-buy (Micro
  Center / GigaParts with live prices), and docs links.
- `public/tdeck/` — **RoostOS Communicator** (LILYGO T-Deck) page + real photos
  (`tdeck/img/`) and the browser **config builder** (`tdeck/config/`).
- `public/roost/` — **Roost Server** page (captive-portal appliance).
- `public/img/`, `public/favicon.*` — shared assets.

Branding: **RoostOS** is the umbrella (one word, two-color wordmark); the two
builds are **RoostOS Communicator** and **Roost Server**.

## Deploy
Use the repo's own wrangler config (npx can pick the wrong directory):

```sh
/opt/homebrew/bin/wrangler deploy --config ./wrangler.toml
```

Local preview: `npx wrangler dev` or serve `public/`.

Projects: https://github.com/StevenSSparks/roost-tdeck ·
https://github.com/StevenSSparks/roost
