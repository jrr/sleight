import assert from "node:assert/strict"
import { greeting } from "./src/Core.res.mjs"

assert.equal(greeting(), "Hello from ReScript core!")
console.log("core: greeting() ok")
