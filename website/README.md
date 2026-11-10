# lightmix website

The homepage of lightmix, built with [Ziex](https://github.com/ziex-dev/ziex).

This is a separate Zig project with its own `build.zig.zon`, so the Ziex dependency never reaches the lightmix package. Ziex is pinned to `v0.1.0-dev.1259`, the latest release that supports Zig `0.16.0`.

## Commands

Run these in this directory:

| Command | Description |
| :--- | :--- |
| `zig build dev` | Starts a development server with hot reload |
| `zig build export` | Writes the static site to `dist/` |

The site is served from `/lightmix` on GitHub Pages, so every route and asset path is prefixed with `/lightmix` (`base_path` in `build.zig`).

## Deployment

`.github/workflows/deploy-pages.yml` publishes the exported site at the root of GitHub Pages and the API documentation (`zig build docs`) under `/docs/`.
