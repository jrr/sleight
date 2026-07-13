import assert from "node:assert"
import { execFileSync } from "node:child_process"

// Run the bundled artifact exactly as a user would and assert its output, so
// `mise run ci` both builds and runs the CLI end-to-end.
const output = execFileSync("node", ["dist/cli.js"], { encoding: "utf8" }).trim()

assert.strictEqual(output, "Hello from ReScript core!")
console.log("cli: node dist/cli.js ok")
