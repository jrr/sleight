import assert from "node:assert";
import { execFileSync } from "node:child_process";

// Run the bundled artifact end-to-end and assert on its stdout, so `mise run
// ci` both builds (via `bundle`) and actually runs the CLI.
const out = execFileSync("node", ["dist/cli.js"], { encoding: "utf8" }).trim();

assert.strictEqual(out, "Hello from ReScript core!");
console.log("cli: node dist/cli.js ok");
