// Minimal ReScript bindings to the parts of Vitest we use, kept local (as in the
// `core` package) so the test setup has no dependency beyond `vitest` itself.
// Extend as more matchers are needed.

type assertion<'a>

@module("vitest") external test: (string, unit => unit) => unit = "test"
@module("vitest") external describe: (string, unit => unit) => unit = "describe"
@module("vitest") external expect: 'a => assertion<'a> = "expect"

@send external toBe: (assertion<'a>, 'a) => unit = "toBe"
@send external toEqual: (assertion<'a>, 'a) => unit = "toEqual"
