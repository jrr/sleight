import { defineConfig } from "vite";

// Bundle the compiled ReScript entry into a single self-contained Node script
// (`dist/cli.js`) that runs with `node dist/cli.js`. This reuses the same
// bundler as web-app, but in SSR/Node mode:
//   - `build.ssr` targets Node rather than the browser (no HTML, no asset URLs).
//   - `ssr.noExternal: ["core"]` inlines the workspace `core` dependency so the
//     artifact is standalone and needs no node_modules to run.
export default defineConfig({
  build: {
    ssr: "src/Cli.res.mjs",
    target: "node20",
    outDir: "dist",
    rollupOptions: {
      output: {
        entryFileNames: "cli.js",
      },
    },
  },
  ssr: {
    noExternal: ["core"],
  },
});
