# Dialect inference from a connection or repo

Type: research
Status: open
Blocked by: none

## Question

Given a live connection or an Ecto repo, can a library discover which Dialect to render for, without configuration?

Check from primary sources (library source code and hexdocs):

1. Postgrex: what a connection pid or `DBConnection` handle exposes.
2. Exqlite and `ecto_sqlite3`: same.
3. MyXQL and Tds: same.
4. Ecto: `Repo.__adapter__/0` and `Ecto.Adapters.SQL` entry points that accept `{sql, params}`.
5. Whether `DBConnection` carries the connection module in a way a caller can read.

Record the concrete call for each Driver, or state that none exists.

## Blocks

07
