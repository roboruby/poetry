# Third-party notices - poetry-extract

## agentcn (extract-design-md recipe)

- Source: https://github.com/shadcn-labs/agentcn (MIT) - the `extract-design-md`
  recipe, itself "verbatim from designmd-supply"
- Adapted: `lib/poetry/extract/derive_tokens.rb` is a function-for-function
  Ruby port of the recipe's `derive-tokens.ts`; `lib/poetry/extract/compose.rb`
  adapts its `design-md.ts` prompt spec and `compose.ts` orchestration shape.
  The upstream `derive-tokens.ts` is vendored as the parity ORACLE at
  `test/fixtures/oracle/` (test-only, not packaged) with its license alongside.

```
MIT License

Copyright (c) 2026 Shadcn Labs

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
