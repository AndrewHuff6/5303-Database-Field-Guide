# 09 — When to choose it: SQLite

> **Fixed question:** Yes or no on the standard scenarios, citing your own numbers.
>
> **Student artifact:** Conclusions in your FINDINGS ([template](../../../lab/findings_template.md))

## The rule of thumb

> **SQLite competes with `fopen()`, not with database servers.**
> If the data belongs to one program on one machine, start with SQLite.
> If many clients, users, or machines share it, start with a server.

## Standard scenarios

For each one: **SQLite, yes or no**, in 1–2 sentences, citing **one number**
from your own §7 or §8 results.

| #   | Scenario                                                             | SQLite? | The number that decides it |
| --- | -------------------------------------------------------------------- | ------- | -------------------------- |
| 1   | Internal read-only dashboard, ~10 analysts                           |         |                            |
| 2   | A mobile app's offline local storage                                 |         |                            |
| 3   | Ingesting thousands of events per second from many servers           |         |                            |
| 4   | A fresh throwaway database for each automated test                   |         |                            |
| 5   | A web API with many users who write                                  |         |                            |
| 6   | A desktop app's document format                                      |         |                            |
| 7   | Several applications sharing one database with different permissions |         |                            |

Decide first, then go find the number. If the number argues against your
verdict, change the verdict. That's a better answer than the one you started
with.

## Sweet spots and red flags

| SQLite fits when…                                         | Look elsewhere when…                                                                |
| --------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| one process (or a few readers) owns the data              | many processes write concurrently                                                   |
| the data travels with the app (mobile, desktop, embedded) | clients are on other machines                                                       |
| you want zero operations: no server, no patching          | you need users, roles, and permissions                                              |
| tests need a fresh database every time                    | you need replication or failover                                                    |
| reads dominate and the dataset fits on one disk           | analytics scan huge tables ([DuckDB](../../05_duckdb/) is the embedded alternative) |

## Your artifact

The seven verdicts above in your FINDINGS, each with one sentence and one
number from your own results.
