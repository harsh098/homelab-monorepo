## ast-grep

Use ast-grep for quick code traversal before broad text search when the target is a syntactic construct, symbol shape, call expression, import/export, JSX element, or language-aware pattern.

Rules:
- Prefer `ast-grep`/`sg` structural queries for code navigation that depends on syntax; fall back to regex search only for plain text, comments, logs, or exact string literals.
- Use ast-grep to narrow candidate files and call sites before opening source, especially in large directories where raw grep would spend tokens on irrelevant matches.
- Keep traversal read-only unless performing an intentional codemod; review matches before editing.

## graphify

This project has a knowledge graph at graphify-out/ with god nodes, community structure, and cross-file relationships.

When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.

Setup:
- If `graphify` is missing but Python is available, install `graphifyy` and write `graphify-out/.graphify_python` with the interpreter that can import `graphify`.
- Prefer graphify queries/path/explain over raw source browsing to save context tokens; use wiki or GRAPH_REPORT only when scoped graph commands are insufficient.

Rules:
- For codebase questions, first run `graphify query "<question>"` when graphify-out/graph.json exists. Use `graphify path "<A>" "<B>"` for relationships and `graphify explain "<concept>"` for focused concepts. These return a scoped subgraph, usually much smaller than GRAPH_REPORT.md or raw grep output.
- Dirty graphify-out/ files are expected after hooks or incremental updates; dirty graph files are not a reason to skip graphify. Only skip graphify if the task is about stale or incorrect graph output, or the user explicitly says not to use it.
- If graphify-out/wiki/index.md exists, use it for broad navigation instead of raw source browsing.
- Read graphify-out/GRAPH_REPORT.md only for broad architecture review or when query/path/explain do not surface enough context.
- After modifying code, run `graphify update .` to keep the graph current (AST-only, no API cost).
