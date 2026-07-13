// Minimal DOM binding so this package stays dependency-free while still
// proving the wiring: render core's greeting into the page.
type element
@scope("document") @val external body: element = "body"
@set external setTextContent: (element, string) => unit = "textContent"

setTextContent(body, Core.greeting())
