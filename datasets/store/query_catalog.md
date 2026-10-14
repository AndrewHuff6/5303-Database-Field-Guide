# Query Catalog

Stable IDs shared by every engine. The pattern names match the folders in
[patterns/](../../patterns/). Routes follow the
[route contract](../../lab/api/02_route_contract/README.md) (every route also
takes `db=`).

Per-engine fit is recorded in each unit's `06_queries/`:
✓ natural · ~ awkward · ✗ wrong tool (say why).

| ID  | Intent                            | Pattern                                                          | Method | Route                               | Parameters                |
| --- | --------------------------------- | ---------------------------------------------------------------- | ------ | ----------------------------------- | ------------------------- |
| Q01 | One customer by id                | plan basics                                                      | GET    | `/customers`                        | customer_id               |
| Q02 | One page of products              | [keyset_pagination](../../patterns/keyset_pagination/)           | GET    | `/products`                         | limit, offset             |
| Q03 | Purchases in a date range         | plan basics                                                      | GET    | `/purchases`                        | start, end                |
| Q04 | A customer's purchase history     | plan basics                                                      | GET    | `/customers/purchases`              | customer_id               |
| Q05 | Count purchases in one department | [counting_and_summaries](../../patterns/counting_and_summaries/) | GET    | `/stats/department_count`           | department                |
| Q06 | A customer's purchase streaks     | [gaps_and_islands](../../patterns/gaps_and_islands/)             | GET    | `/customers/streaks`                | customer_id               |
| Q07 | 90-day spending leaderboard       | [window_ranking](../../patterns/window_ranking/)                 | GET    | `/stats/leaderboard`                | start, end                |
| Q08 | Products never bought in a state  | [anti_joins](../../patterns/anti_joins/)                         | GET    | `/products/dead`                    | state                     |
| Q09 | Revenue by state                  | plan basics                                                      | GET    | `/stats/revenue_by_state`           | —                         |
| Q10 | Top 10 products by revenue        | plan basics                                                      | GET    | `/products/top`                     | —                         |
| Q11 | Deep pagination: OFFSET vs keyset | [keyset_pagination](../../patterns/keyset_pagination/)           | GET    | `/purchases/page` · `/fast`         | offset · fast: after_id   |
| Q12 | Random sample                     | [random_sampling](../../patterns/random_sampling/)               | GET    | `/purchases/sample` · `/fast`       | —                         |
| Q13 | Revenue by month: scan vs summary | [counting_and_summaries](../../patterns/counting_and_summaries/) | GET    | `/stats/revenue_by_month` · `/fast` | —                         |
| Q14 | State × department × month report | [multi_cte_reports](../../patterns/multi_cte_reports/)           | GET    | `/reports/cube` · `/fast`           | start, end, min_purchases |
| Q15 | Insert a purchase                 | — (unit `08_concurrency/`)                                       | POST   | `/purchases`                        | JSON body                 |

**Plan basics** (Q01, Q03, Q04, Q09, Q10) are taught in each unit's
`07_explain/`: point lookups, range scans, foreign-key lookups, and covering
indexes.

**Proposed:** Q16, search review text ([full_text_search](../../patterns/full_text_search/)),
once the `reviews` table is added.

_Status: stub — content to be added._
