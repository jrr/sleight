// Minimal, dependency-free DOM binding: set document.body's text content.
type element
@val @scope("document") external body: element = "body"
@set external setTextContent: (element, string) => unit = "textContent"

setTextContent(body, Core.greeting())
