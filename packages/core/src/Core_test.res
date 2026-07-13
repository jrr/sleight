open Vitest

test("greeting returns the expected message", () => {
  expect(Core.greeting())->toBe("Hello from ReScript core!")
})
