import { execFileSync } from "node:child_process"
import assert from "node:assert"

// Run the bundled artifact exactly as a user would (`node dist/cli.js`) and
// assert it prints core's greeting — proving the single-file bundle wired up
// the `core` dependency correctly.
const out = execFileSync("node", ["dist/cli.js"], { encoding: "utf8" }).trim()
assert.strictEqual(out, "Hello from ReScript core!")
console.log("cli: bundled artifact ran and printed core's greeting")
