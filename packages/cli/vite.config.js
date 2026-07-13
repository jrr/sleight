import { defineConfig } from "vite";

// Bundle the CLI into a single self-contained Node script so it can be run
// with `node dist/cli.js` without needing the workspace symlinks at runtime.
// `build.ssr` targets Node (no browser polyfills, no code-splitting), and
// `ssr.noExternal: ["core"]` inlines the workspace `core` module rather than
// leaving it as a bare import Node couldn't resolve from `dist/`.
export default defineConfig({
  build: {
    ssr: "src/Cli.res.mjs",
    target: "node20",
    outDir: "dist",
    rollupOptions: {
      output: { entryFileNames: "cli.js" },
    },
  },
  ssr: {
    noExternal: ["core"],
  },
});
