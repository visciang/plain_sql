# 01: Inspect a Fragment as text and values

**Spec:** `docs/spec.md` section 2.1 (Fragment). Add the inspect form.

**What to build:** A developer inspects a Fragment in IEx, in an ExUnit failure, or with `dbg/1`. The output shows the SQL text and the ordered value list, not the parts list. Inspecting is not Rendering. No Dialect is involved.

Form: `#PlainSQL.Fragment<"SELECT * FROM orders WHERE (status = ?)", ["open"]>`.

- A Binding shows as `?`.
- A list part shows as `(?, ?, ...)`, with one `?` for each element.
- An Identifier shows inside double quotes, the delimiter of the SQL standard.
- The values show in text order. Each value is inspected with the caller's inspect options.
- The text never contains a value.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] `inspect(~q"SELECT * FROM orders WHERE status = #{"open"} AND total > #{10}")` returns `#PlainSQL.Fragment<"SELECT * FROM orders WHERE status = ? AND total > ?", ["open", 10]>`.
- [ ] `inspect(~q"id IN #{list([1, 2])}")` returns `#PlainSQL.Fragment<"id IN (?, ?)", [1, 2]>`.
- [ ] `inspect(identifier("orders"))` returns `#PlainSQL.Fragment<"\"orders\"", []>`.
- [ ] `inspect(~q"")` returns `#PlainSQL.Fragment<"", []>`.
- [ ] An inspect option such as `limit:` applies to the value list.
- [ ] An Identifier that contains `"` does not raise on inspect.
- [ ] The `PlainSQL.Fragment` moduledoc and spec section 2.1 state the form and that inspecting is not Rendering.
