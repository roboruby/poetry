# poetry islands

Contracts generated from the poetry-island registry. An island is the
declared exception to "state lives on the server and the URL": a
bounded mount for a widget whose state changes many times a second
(an editor, a canvas, a map, a 3D scene). Everything else is a
component with a Stimulus behavior. The block is the shell the server
renders; the module is an importmap specifier exporting
mount(element, props); state that must outlive the page leaves
through name:, a hidden input inside the island. Reach for it last.

## island (`poetry_island`)

A bounded client mount: a module from the importmap takes over a server-rendered shell, for a widget whose state lives on the client.

Class: Poetry::Island::Island::Component - BEM block `poetry-island-island`.
- `import:` (string) - required - The importmap specifier of the island's module, which exports mount(element, props).
- `mode:` (symbol) - one of fill|flow, default "fill" - fill paints the shell's box (a canvas, a map, a scene); flow takes the shell's place in the page (an editor).
- `name:` (string) - A form field name: renders a hidden input inside the island, props.input, for the module to write its state to.
- `props:` () - default {} - What the module mounts with, a Hash serialized as JSON.
- `value:` (string) - The hidden input's initial value.
- PART `island` - The island: the shell, the hidden input, the props, then the root the module mounts in
- PART `island-shell` - The server-rendered content the island takes over
- PART `island-input` - The hidden input the module writes its state to, with name:
- WIRING root: `poetry--island--island` registers; values import, mode
- WIRING shell: `poetry--island--island` targets shell
- WIRING input: `poetry--island--island` targets input
- RULE: An island is the exception, for client-owned state that changes many times a second (an editor, a canvas, a map, a 3D scene); anything else is a component with a Stimulus behavior.
- RULE: The block is the shell: what a reader gets before the module mounts and whenever it cannot, and in fill mode the box the island paints. Put the content a reader needs there, never nothing.
- RULE: State that must outlive the page leaves through the form: name: renders a hidden input inside the island, and the module writes to props.input.
- RULE: import: is an importmap specifier the host pins (app/javascript/islands/map.js is islands/map); poetry check warns when config/importmap.rb does not.

