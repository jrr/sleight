// Minimal ReScript bindings to the parts of Vitest we use. Kept local rather
// than pulling in a third-party binding package so the test setup has no
// dependencies beyond `vitest` itself. Extend as more matchers are needed.
//
// If maintaining these bindings by hand becomes too burdensome, we could switch
// to https://github.com/cometkim/rescript-vitest instead.

type assertion<'a>

@module("vitest") external test: (string, unit => unit) => unit = "test"
@module("vitest") external describe: (string, unit => unit) => unit = "describe"
@module("vitest") external expect: 'a => assertion<'a> = "expect"

@send external toBe: (assertion<'a>, 'a) => unit = "toBe"
@send external toEqual: (assertion<'a>, 'a) => unit = "toEqual"
