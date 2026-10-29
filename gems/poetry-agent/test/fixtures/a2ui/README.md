# A2UI test data

What poetry-agent's A2UI renderer is tested against. Test-only: `test/`
never ships in the gem. The material under `upstream/` is Apache-2.0
(google/A2UI, its LICENSE inside it), credited in THIRD_PARTY_NOTICES.md.

| Path | What it is |
| --- | --- |
| `conformance/core/*.yaml` | The 17 renderer conformance suites (466 cases): expressions, functions, data model and pointers, message processing and validation for v0.9 and v1.0, RPC, actions, catalogs |
| `catalogs/basic/v1/catalog.json`, `specification/v0_9/catalogs/basic/catalog.json`, `specification/v0_9_1/catalogs/basic/catalog.json`, `conformance/test_data/catalogs/custom_catalog_v1_0.json` | The catalogs the suites name by path |
| `catalogs/basic/v1/examples/`, `specification/v0_9/catalogs/basic/examples/` | The basic catalogs' 43 v1.0 and 44 v0.9 example surfaces |
| `specification/v0_9/json/`, `specification/v0_9_1/json/`, `specification/v1_0/json/` | Each version's message, common-type, capability and catalog schemas |

Every path above is under `upstream/`, in upstream's layout, so the suites'
relative catalog paths resolve. `COMMIT` names the A2UI commit; `SHA256SUMS` lists every file.
`rake a2ui:vendor A2UI=path` re-vendors from a checkout and `rake a2ui:verify`
(part of the default task) fails when a file differs from the manifest.
The schemas strict validation reads at runtime ship in the gem as copies under
`lib/poetry/agent/a2ui/schemas/`, in the same layout; the vendor task writes
them and the verify task fails when one differs from its vendored original.
`ConformanceTest` runs every case; the ones Poetry does not pass yet are
listed in `divergences.yml`, each with what closes it.
