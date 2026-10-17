# 04: ExDoc cheatsheet

**Spec:** none. Documentation only.

**What to build:** A developer opens the generated docs and finds a cheatsheet page. The page gives one entry for each public helper and one entry for each common idiom. Each entry shows the `~q` code and the rendered SQL and params.

Idioms: optional filters with `and_/1` and `where/1`, `IN` with `list/1`, the Postgres array form with `ANY`, `UPDATE` with `set/1`, `INSERT` with `identifier/1` and `values/1`, and a `DELETE` guard with `empty?/1`.

**Blocked by:** 02 (Render multi-row `VALUES` with `values/1`).

**Status:** ready-for-agent

- [ ] `mix docs` builds the cheatsheet page and lists it in the sidebar.
- [ ] The page has one entry for each public function of `PlainSQL`.
- [ ] Each rendered SQL string and param list on the page matches the output of `render/2` for the shown code.
- [ ] The page links to the README for the rules and the pitfalls. It does not repeat them.
- [ ] The text follows the vocabulary in `CONTEXT.md`.
