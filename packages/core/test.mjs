import assert from "node:assert"
import { greeting } from "./src/Core.res.mjs"

assert.strictEqual(greeting(), "Hello from ReScript core!")
console.log("core: greeting() ok")
