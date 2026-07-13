// Entry point for the web app. Pulls the greeting from the shared `core`
// package and renders it into the page.

type element

@val @scope("document") external body: element = "body"
@set external setTextContent: (element, string) => unit = "textContent"

setTextContent(body, Core.greeting())
