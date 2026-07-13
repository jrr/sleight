import { defineConfig } from "vite";

// Reuse the same bundler as web-app, but target Node instead of the browser:
// bundle the compiled ReScript entry into a single self-contained artifact that
// runs with `node dist/cli.js`. `build.ssr` builds for Node (keeping built-in
// modules external), and `ssr.noExternal` forces the workspace `core` dependency
// to be inlined so the emitted file has no runtime dependency on node_modules.
export default defineConfig({
  build: {
    ssr: "src/Cli.res.mjs",
    outDir: "dist",
    target: "node20",
    rollupOptions: {
      output: { entryFileNames: "cli.js" },
    },
  },
  ssr: {
    noExternal: ["core"],
  },
});
