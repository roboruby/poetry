// The parity oracle: runs the UPSTREAM derive-tokens (agentcn, MIT - see
// LICENSE-agentcn.txt) against inputs.json and writes expected.json. The
// Ruby port must reproduce these outputs byte-for-byte.
//
// Regenerate (node only needed here, never in CI):
//   npx -y esbuild derive-tokens.ts --format=esm --outfile=derive-tokens.mjs
//   node run.mjs
import { readFileSync, writeFileSync } from "node:fs";
import { deriveTailwindTheme, deriveCssVariables } from "./derive-tokens.mjs";

const inputs = JSON.parse(readFileSync(new URL("./inputs.json", import.meta.url), "utf8"));
const expected = {};
for (const [name, c] of Object.entries(inputs)) {
  expected[name] = {
    tailwind: deriveTailwindTheme(c.domain, c.brand ?? undefined, c.styleguide ?? null),
    css: deriveCssVariables(c.domain, c.brand ?? undefined, c.styleguide ?? null),
  };
}
writeFileSync(new URL("./expected.json", import.meta.url), JSON.stringify(expected, null, 2) + "\n");
console.log(`wrote expected.json (${Object.keys(expected).length} cases)`);
