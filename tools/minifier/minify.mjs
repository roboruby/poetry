// Minifies one gem's importmap JavaScript tree for the release.
//
//   node minify.mjs SOURCE_DIR OUT_DIR
//
// SOURCE_DIR is a gem's app/javascript and OUT_DIR its dist/javascript. Each
// .js file is minified on its own, so the module graph, the file names and
// every bare "@poetry/..." import stay exactly as the importmap pins them.
// Beside each file sits a source map carrying the original text, so a
// browser's devtools show the source. A file that opens with a "/*!" legal
// comment is a vendored bundle that was minified when it was built (the d3
// and motion kernels), and is copied byte for byte. Output is deterministic:
// the release builds twice and compares.
import { transformSync } from "esbuild"
import { copyFileSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs"
import { basename, dirname, join, relative } from "node:path"

const [source, out] = process.argv.slice(2)
if (!source || !out) {
  console.error("usage: node minify.mjs SOURCE_DIR OUT_DIR")
  process.exit(2)
}

const walk = (dir) => readdirSync(dir).sort().flatMap((name) => {
  const path = join(dir, name)
  return statSync(path).isDirectory() ? walk(path) : [path]
})

rmSync(out, { recursive: true, force: true })
let before = 0
let after = 0
let minified = 0
let copied = 0
for (const file of walk(source)) {
  const path = relative(source, file)
  const target = join(out, path)
  mkdirSync(dirname(target), { recursive: true })
  const text = readFileSync(file, "utf8")
  if (!file.endsWith(".js") || text.startsWith("/*!")) {
    copyFileSync(file, target)
    copied += 1
    continue
  }

  const { code, map } = transformSync(text, {
    loader: "js",
    format: "esm",
    minify: true,
    sourcemap: "external",
    sourcefile: basename(path),
    sourcesContent: true
  })
  writeFileSync(target, `${code}//# sourceMappingURL=${basename(path)}.map\n`)
  writeFileSync(`${target}.map`, map)
  before += text.length
  after += code.length
  minified += 1
}
console.log(`${source}: ${minified} minified (${Math.round(before / 1024)} KB to ${Math.round(after / 1024)} KB), ${copied} copied`)
