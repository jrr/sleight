// Proves the compiled ReScript output is importable and behaves as expected.
// Runs after `rescript build` has produced src/Core.res.js.
import assert from "node:assert";
import { greeting } from "./src/Core.res.js";

assert.strictEqual(greeting(), "Hello from ReScript core!");
console.log("core: greeting() ->", greeting());
