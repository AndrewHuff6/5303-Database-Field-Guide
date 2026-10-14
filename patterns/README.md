# Query Patterns

Engine-independent techniques. Each pattern is a folder with a `README.md`
(the idea, engine-neutral) and one section per engine. Pattern names are the
single key: the [query catalog](../datasets/store/query_catalog.md) uses the
same names.

| Pattern | Queries | The idea |
| ------- | ------- | -------- |
| [keyset_pagination](keyset_pagination/) | Q11, Q02 | Paging deep into a result without paying for every skipped row |
| [full_text_search](full_text_search/) | Q16 (proposed — needs `reviews`) | Finding words inside text: `LIKE '%x%'` vs. an inverted index |
| [counting_and_summaries](counting_and_summaries/) | Q05, Q13 | Why `COUNT(*)` isn't free, and keeping precomputed summaries fresh |
| [window_ranking](window_ranking/) | Q07 | Ranking and running totals over a sliding window |
| [gaps_and_islands](gaps_and_islands/) | Q06 | Finding consecutive runs (streaks) and the breaks between them |
| [multi_cte_reports](multi_cte_reports/) | Q14 | Multi-level aggregate reports built in readable stages |
| [random_sampling](random_sampling/) | Q12 | Picking random rows without shuffling the whole table |
| [anti_joins](anti_joins/) | Q08 | "Rows with no match": `NOT EXISTS`, `LEFT JOIN … IS NULL`, `NOT IN` |

Queries without a pattern (Q01, Q03, Q04, Q09, Q10) are **plan basics**: they're
taught in each unit's `07_explain/`, not here.

_Status: stub — content to be added._
