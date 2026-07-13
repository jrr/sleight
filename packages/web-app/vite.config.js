import { defineConfig } from "vite";

// `base: "./"` makes emitted asset URLs relative, so the built site works when
// GitHub Pages serves it from a project subpath (https://<user>.github.io/<repo>/)
// rather than a domain root. Vite resolves the bare `core/…` specifier that the
// compiled ReScript emits via the workspace symlink and bundles the module graph.
export default defineConfig({
  base: "./",
});
