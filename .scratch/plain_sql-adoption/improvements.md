# plain_sql improvements from the next_number adoption

Source: the plan in `next_number_plug/dev/handoffs/PLAN_PLAIN_SQL.md`, 2026-09-27. Each entry states the evidence. Each entry is a candidate. None is decided.

## 1. A String module attribute in `#{}` binds

Evidence: `~q"SELECT 1 #{@text}"` with `@text "FROM t"` renders `{"SELECT 1 ?", ["FROM t"]}`. SQLite runs the statement. It returns the text `FROM t` as a column. The fault gives a wrong result with no error.

next_number has twelve SQL module attributes. Four of them splice into other statements.

Candidates:

- README: state that a reusable SQL piece must be a `~q` attribute, not a String attribute.
- `sigil_q`: at expansion, read the value of a `#{@name}` attribute. Warn when the value is a binary. Not verified: the module must be open at expansion of a function body. A binary attribute can also be a real value, so a warning can be a false positive.

Analysis 2026-09-27:

- Verified: `Module.get_attribute(__CALLER__.module, :text)` inside a macro expanded in a function body returns the attribute value. The mechanism for the warning exists.
- The warning contradicts spec section 4: "No check on a string literal in `#{}`. It binds as a value at runtime." and "No configuration and no strict mode." `@default "open"` in `~q"status = #{@default}"` is a correct Binding. The warning fires on it.
- Recount of next_number: eleven SQL String attributes. Three splice into other statements: `@priced_lines` (3 sites), `@page_scope` (3 sites), `@service_select` (2 sites). `@callable_ceiling` is an integer. It binds correctly under `~q`.
- Recommendation: reject the warning. Take the README candidate together with entry 7.

## 2. Helper names conflict with local functions

Evidence: `import PlainSQL` in a module that defines `list/1` stops the compile with "imported PlainSQL.list/1 conflicts with local function". `NextNumber.Store.Catalogues` defines `list/1`. `where`, `set`, `join`, and `raw` are also common function names.

Candidate: the README examples use `import PlainSQL, only: [...]`. Or the README states the conflict.

Analysis 2026-09-27:

- Correction, verified: the compile stops only when the module defines `list/1` and also calls `list(...)` unqualified. A module that defines `list/1` and never calls `list/1` compiles. `NextNumber.Store.Catalogues.list/1` has no `IN` predicate today, so it compiles as is.
- `import PlainSQL, except: [list: 1]` plus `PlainSQL.list(ids)` at the call site compiles. This is the standard Elixir remedy. It needs no library change.
- Recommendation: one README sentence in the Usage section. No API change. `import PlainSQL, only: [...]` in every example adds noise to every example for a case that concerns one helper name.
- Decision 2026-09-27: no README change. An import clash with a local function is standard Elixir. The developer renames the function or restricts the import.

## 3. `values/1` helper

Evidence: next_number has three multi-row inserts. Each writes `join(Enum.map(rows, &list/1), ~q", ")` after `VALUES`.

Candidate: `values/1` takes a non-empty list of rows. It renders `VALUES (?, ?), (?, ?)`. The name follows the rule of spec section 2.4: a helper is a SQL keyword. Spec section 2.4 also rejects `INSERT` from a map. A list of lists is not a map. The spec must decide.

Analysis 2026-09-27:

- `values/1` passes the three rules of spec section 2.4. Naming: `VALUES` is a keyword. Boundary: it takes values and emits text at its own position. Skip rule: not applicable, a row is a list of values, not a Fragment.
- The current form is one expression. The README and the spec idioms both show it. Three call sites save `join(Enum.map(rows, &list/1), ~q", ")` each.
- Open decision for the spec: `values([])` must raise, like `list([])`. `values([[]])` renders `VALUES ()`, which is invalid SQL. Both cases need an `ArgumentError` at the call. That is two new rows in the error table of section 2.6.
- Recommendation: defer. The idiom is documented and one line. Revisit after a second consumer.

## 4. The same value in two positions

Evidence: five next_number statements use one value two times. Each use needs its own `#{}`.

Spec section 6 puts named Bindings out of scope. This entry is evidence for that item. It is not a request.

Analysis 2026-09-27: no action. The workaround at each site is a local variable in two `#{}`. The Driver receives the value two times.

## 5. The installation section fails for every consumer

Evidence: the README gives `{:plain_sql, "~> 0.1.0"}`. `mix hex.info plain_sql` returns "No package with name plain_sql". The repository is private.

Candidate: publish to Hex, or give the Git form in the README.

Analysis 2026-09-27:

- Verified: `mix.exs` has no `package/0` and no `description`. A Hex publish needs both, plus a public repository or a Hex organization.
- Tag `v0.1.0` exists on `origin`. The Git form that works today: `{:plain_sql, git: "git@github.com:visciang/plain_sql.git", tag: "v0.1.0"}`.
- Recommendation: replace the Hex line in the README with the Git form now. Publishing to Hex is a separate decision about making the repository public.

## 6. No example for `Exqlite.Sqlite3`

Evidence: the Execution section shows Postgrex, an Ecto repo, and Tds. `Exqlite.Sqlite3` has no `query` function. The application calls `prepare/2`, `bind/2`, `fetch_all/2`, and `release/2`.

Candidate: add the SQLite form of the application module to the Execution section.

Analysis 2026-09-27:

- Verified in exqlite 0.41: `Exqlite.Sqlite3` exposes `execute/2` (no params), `prepare/2`, `bind/2`, `fetch_all/2`, `release/2`. There is no `query/3`.
- The README Execution section states the application module holds "a Driver with a param shape of its own". SQLite is the only Driver in the test suite and has no example. The gap is real.
- Recommendation: add one `Exqlite.Sqlite3` example to the Execution section. Take the shape from `test/plain_sql/live_test.exs`.

## 7. A Fragment in a module attribute

Evidence: `@frag ~q"FROM t"` then `~q"SELECT 1 #{@frag}"` renders `{"SELECT 1 FROM t", []}`. The README does not show this form.

Candidate: one README example. It also fixes entry 1 for most users.

Analysis 2026-09-27:

- Verified: `@frag ~q"FROM t"` compiles. The struct is stored in the attribute. `~q"SELECT 1 #{@frag}"` splices it. `@text "FROM t"` in the same position binds.
- Recommendation: accept. One README paragraph after the splicing example, with both forms side by side. This closes entries 1 and 7.

## Summary

| Entry | Decision | Change |
|---|---|---|
| 1 | README only, no warning | with 7 |
| 2 | none | none |
| 3 | defer | none |
| 4 | none | none |
| 5 | accept | Installation: Git form |
| 6 | accept | Execution: Exqlite example |
| 7 | accept | Usage: `~q` attribute vs String attribute |

All accepted changes are README edits. No API or spec change.
