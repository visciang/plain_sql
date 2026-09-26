# Dialect contract and Rendering output

Type: grilling
Status: open
Blocked by: 02, 04

## Question

What is the Dialect behaviour, and what does Rendering return?

Settle:

1. The callbacks a Dialect module implements, derived from the divergence list of ticket 04.
2. The Rendering output: a `{sql, params}` tuple, or a struct that Drivers and Ecto accept.
3. How a contributor adds MySQL or MSSQL without touching the core, shown as the module skeleton.
4. Whether a Dialect is passed explicitly on every Rendering call or can be a process or application default.

## Blocks

07, 10
