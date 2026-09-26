# PlainSQL

An Elixir library for writing SQL as SQL. A query is SQL text with bound values, composed from smaller pieces and rendered for one database at a time.

## Language

**Fragment**:
A piece of SQL text together with the values bound inside it. A complete query is a Fragment.
_Avoid_: Query object, statement builder, snippet

**Binding**:
The act of placing a value inside a Fragment so that the Dialect renders it as a placeholder, never as text.
_Avoid_: Interpolation, escaping, parameterisation

**Splicing**:
The act of placing a Fragment inside another Fragment. The inner text joins the outer text and the inner bindings join the outer bindings.
_Avoid_: Embedding, nesting, concatenation

**Empty Fragment**:
A Fragment with no text and no bindings. Splicing it changes nothing. It is the value of an optional clause that is absent.
_Avoid_: Nil fragment, blank, no-op

**Dialect**:
The rendering rules for one SQL variant. A Dialect decides how bindings and identifiers appear in the rendered text. A Dialect does not change what the SQL says.
_Avoid_: Adapter, backend, flavour

**Driver**:
The library that sends a rendered query to a database and returns the result. Postgrex and Exqlite are Drivers. PlainSQL does not contain a Driver.
_Avoid_: Adapter, connection, repo

**Rendering**:
The act of turning a Fragment into the SQL string and the ordered value list that a Driver accepts, for one Dialect.
_Avoid_: Compilation, serialisation, to_sql
