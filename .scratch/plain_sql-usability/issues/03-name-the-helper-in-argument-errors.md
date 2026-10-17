# 03: Give a hint for a string in argument errors

**Spec:** `docs/spec.md` section 2.6 (errors), section 7 (open items).

**What to build:** A developer passes a string to a helper in place of a Fragment or a list of Fragments. The `ArgumentError` message tells the developer to use `~q` for SQL text or `raw/1` for runtime SQL text.

The spec does not fix the exact message text. This ticket fixes the hint that a message must contain.

Decision 2026-10-17: the message does not name the helper. The Elixir type checker warns on a literal string argument at compile time. The stacktrace shows the line of the call. The helper name added little and needed a parameter through six private functions.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] `and_(["status = 'open'"])` raises `ArgumentError`. The message contains the hint for `~q` and `raw/1`.
- [ ] `where("status = 'open'")` raises `ArgumentError`. The message contains the same hint.
- [ ] A wrong value that is not a string, for example `where(1)`, gets no hint.
- [ ] Tests assert on the hint, not on the full message text.
- [ ] Spec section 2.6 states the hint rule. Section 7 no longer lists the message text as open.
