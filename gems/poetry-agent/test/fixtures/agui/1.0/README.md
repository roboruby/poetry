# AG-UI 1.0 test data

What poetry-agent's AG-UI pipeline is tested against. Test-only: `test/`
never ships in the gem. The AG-UI material is MIT (ag-ui-protocol/ag-ui),
credited in THIRD_PARTY_NOTICES.md.

| Path | What it is | Source |
| --- | --- | --- |
| `schema.json` | The 1.0 schema (sha256 `4b5c93226838a0e7...`) | `spec/1.0/schema.json` at ag-ui `7e7c1109f` |
| `fixtures/<Definition>/{valid,invalid}/` | 219 per-definition documents: valid ones pass untouched, invalid ones are rejected or stripped | `spec/1.0/fixtures` |
| `conformance/streams/` | The 68-stream receiver conformance corpus and its manifest | `spec/1.0/conformance/streams` |
| `vectors/` | 388 events-in, outcome-out vectors extracted from the TypeScript client's unit tests (chunks, verify, the compatibility boundary), each confirmed against the TypeScript stages | `sdks/typescript/packages/client/src/*/__tests__` |
| `vectors/apply--*.json` | 244 vectors from the TypeScript client's message-assembly tests (metadata, reasoning, subagents, tool calls, result attribution, snapshot tool order, activities, state, run input) and 17 probes of its data model (encrypted values, run fields), each with held history and state in and the messages, state, runs and next input out, all 261 confirmed by running the reference's own stages and reducer under bun; `ApplyVectorsTest` names the 24 Poetry answers differently | `sdks/typescript/packages/client/src/apply/__tests__` |
| `streams/` | 62 streams captured 2026-10-28 from keyless runs of real AG-UI producers: the scripted Python starter, LangGraph on a mock model, Strands with chunks, the A2UI and MCP Apps middlewares, and the Ruby `ag-ui` gem. 60 are non-empty and pass the TypeScript reference verifier | recorded locally |

`rake agui:contract` regenerates `config/agui/contract-1.0.json` from
`schema.json`; `rake agui:verify` fails when the committed table is stale.
A schema bump replaces `schema.json`, `fixtures/`, `conformance/` and
`vectors/` together, then regenerates the table.
