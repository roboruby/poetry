# Third-party notices - poetry-agent

The gem's own code is MIT, per LICENSE.txt. Its AG-UI 1.0 pipeline is
adapted from the AG-UI protocol's reference material, also MIT.

## AG-UI

- Source: https://github.com/ag-ui-protocol/ag-ui (MIT), at commit `7e7c1109f` (2026-10-28)
- Shipped, derived: `config/agui/contract-1.0.json`, generated from the protocol's `spec/1.0/schema.json` by `rake agui:contract`
- Shipped, adapted: the processing stages under `lib/poetry/agent/agui/` follow the reference TypeScript client's behaviour, rewritten in Ruby: enforcement (unrecognised-material stripping), chunk expansion, stream verification, the compatibility boundary and legacy content upgrade, and the 0.0.39 and 0.0.57 era shims; warning and rejection messages keep the reference's wording where tests match on it
- Shipped, adapted: `lib/poetry/agent/agui/tool_results.rb` ports the reference client's `keepToolResultsWithCalls` (`client/src/apply/default.ts`), which pairs tool results with their calls and moves a drifted result back beside its call; the Transcript's placement of a streamed result, its metadata merge and its encrypted-value storage follow the same file's behaviour
- Test-only, never shipped: `test/fixtures/agui/1.0/` holds the schema, the per-definition fixtures, the receiver conformance corpus, and vectors extracted from the reference client's unit tests, the message-assembly (`apply`) tests among them (provenance in that directory's README)

```
MIT License

Copyright (c) 2025

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
