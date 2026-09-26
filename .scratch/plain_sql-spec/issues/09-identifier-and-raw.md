# Identifier binding and the raw-text escape hatch

Type: grilling
Status: open
Blocked by: 02

## Question

How does a developer bind an identifier (table or column name) and how does a developer insert trusted raw SQL text, so that neither can be confused with a value Binding?

Settle:

1. Identifier binding: a function such as `ident("users")` that the Dialect quotes, or a sigil modifier.
2. Raw text: whether an escape hatch exists at all, its name, and the documentation warning that accompanies it.
3. Whether a plain string can ever splice as SQL text without an explicit marker. Leaning: no.
4. Composite identifiers (`schema.table`) and identifier lists (column lists for `INSERT`).

## Blocks

10
