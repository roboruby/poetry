// The prose beside a controller's code, harvested for the manifest: the
// comment block above the class (its purpose), the comment lines above
// each value (its meaning), and the JSDoc summary of each method (what
// the action does). Absence is recorded as absence - the docs floor
// counts it - never invented.
import fs from "node:fs"
import * as espree from "espree"

const PARSE = { ecmaVersion: "latest", sourceType: "module", comment: true, loc: true, range: true }

// A comment's text without its markers: the leading slashes of a line
// comment, the stars of a block; blank comment lines become paragraph
// breaks, the rest joins with single spaces.
export const commentText = (comments) => {
  const lines = comments.flatMap((comment) =>
    comment.type === "Line"
      ? [comment.value.replace(/^\s?/, "")]
      : comment.value.split("\n").map((line) => line.replace(/^\s*\*+\s?/, "").replace(/^\*\s?/, ""))
  )
  const paragraphs = []
  let current = []
  for (const line of lines.map((line) => line.trimEnd())) {
    if (line.trim() === "") {
      if (current.length) paragraphs.push(current.join(" "))
      current = []
    } else {
      current.push(line.trim())
    }
  }
  if (current.length) paragraphs.push(current.join(" "))
  return paragraphs.join("\n\n").trim()
}

// The description of a JSDoc block: the text before its first tag.
const jsdocSummary = (comment) => {
  const text = commentText([comment])
  const tagAt = text.search(/(^|\n)@\w+/)
  return (tagAt === -1 ? text : text.slice(0, tagAt)).trim()
}

// The comments ending directly above a position (only whitespace
// between), walking upward through a contiguous run; nearest last.
const leadingComments = (comments, source, position, floor = 0) => {
  const run = []
  let cursor = position
  for (let i = comments.length - 1; i >= 0; i -= 1) {
    const comment = comments[i]
    if (comment.range[1] > cursor || comment.range[0] < floor) continue
    const gap = source.slice(comment.range[1], cursor)
    if (gap.trim() !== "" || gap.split("\n").length > 2) break
    run.unshift(comment)
    cursor = comment.range[0]
  }
  return run
}

const defaultClass = (program) => {
  const exported = program.body.find((node) => node.type === "ExportDefaultDeclaration")
  if (!exported) return null
  const declaration = exported.declaration
  if (declaration.type === "ClassDeclaration" || declaration.type === "ClassExpression") return { node: declaration, exported }
  if (declaration.type === "Identifier") {
    const named = program.body.find((node) => node.type === "ClassDeclaration" && node.id?.name === declaration.name)
    return named ? { node: named, exported: named } : null
  }
  return null
}

// The docs of one controller file: `doc` (the purpose above the class),
// `values` (name => meaning) and `methods` (name => summary); each key
// present only when the source carries the prose.
export const harvestDocs = (file) => {
  const source = fs.readFileSync(file, "utf8")
  const program = espree.parse(source, PARSE)
  const comments = program.comments
  const found = defaultClass(program)
  if (!found) return {}
  const { node, exported } = found
  const docs = {}

  const purpose = commentText(leadingComments(comments, source, exported.range[0]))
  if (purpose) docs.doc = purpose

  const values = node.body.body.find(
    (member) => member.type === "PropertyDefinition" && member.static && member.key.name === "values"
  )
  if (values?.value?.type === "ObjectExpression") {
    const valueDocs = {}
    let floor = values.value.range[0]
    for (const property of values.value.properties) {
      const text = commentText(leadingComments(comments, source, property.range[0], floor))
      if (text) valueDocs[property.key.name ?? property.key.value] = text
      floor = property.range[1]
    }
    if (Object.keys(valueDocs).length) docs.values = valueDocs
  }

  const methodDocs = {}
  for (const member of node.body.body) {
    if (member.type !== "MethodDefinition" || !["method", "get"].includes(member.kind)) continue
    if (member.key.type !== "Identifier") continue
    const block = leadingComments(comments, source, member.range[0]).at(-1)
    if (!block || block.type !== "Block" || !block.value.startsWith("*")) continue
    const summary = jsdocSummary(block)
    if (summary) methodDocs[member.key.name] = summary
  }
  if (Object.keys(methodDocs).length) docs.methods = methodDocs
  return docs
}

// The docs merged down a class chain of files (parent first, child
// overriding), the way Stimulus merges the statics.
export const mergedDocs = (files) => {
  const merged = { values: {}, methods: {} }
  for (const file of files) {
    const docs = harvestDocs(file)
    if (docs.doc) merged.doc = docs.doc
    Object.assign(merged.values, docs.values ?? {})
    Object.assign(merged.methods, docs.methods ?? {})
  }
  if (!Object.keys(merged.values).length) delete merged.values
  if (!Object.keys(merged.methods).length) delete merged.methods
  return merged
}

// The manifest entry with the docs folded in: `doc` on the entry, `doc`
// on each value, and `method_docs` beside the methods list.
export const withDocs = (entry, docs) => {
  const values = Object.fromEntries(Object.entries(entry.values ?? {}).map(([name, definition]) => [
    name, docs.values?.[name] ? { ...definition, doc: docs.values[name] } : definition
  ]))
  return {
    ...(docs.doc ? { doc: docs.doc } : {}),
    ...entry,
    values,
    ...(docs.methods ? { method_docs: Object.fromEntries(entry.methods.filter((m) => docs.methods[m]).map((m) => [m, docs.methods[m]])) } : {})
  }
}
