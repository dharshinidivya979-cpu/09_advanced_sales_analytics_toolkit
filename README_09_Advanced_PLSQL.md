# Module 09: Advanced PL/SQL
**Mini project:** Sales Analytics Toolkit
**Script:** `09_advanced_sales_analytics_toolkit.sql`
**Database created:** `m9_advanced_db`

## What this project does
Shows advanced techniques on a sales table: collections, dynamic SQL, bulk operations, logging, indexing and security.

## Topic mapping
| Oracle topic | MySQL used here |
|---|---|
| Records | Several variables loaded by `SELECT ... INTO` (`sp_show_record`) |
| Collections, VARRAY | JSON array (`JSON_ARRAY`) |
| Associative array | JSON object (`JSON_OBJECT`) |
| Nested table | `TEMPORARY TABLE` and `JSON_TABLE` |
| Dynamic SQL, `EXECUTE IMMEDIATE` | `PREPARE`, `EXECUTE`, `DEALLOCATE PREPARE` |
| `BULK COLLECT`, `FORALL` | One `INSERT ... SELECT`, `UPDATE` or `DELETE` for many rows (`sp_archive_old_sales`) |
| Autonomous transaction | Log table with `ENGINE = MyISAM`, so `ROLLBACK` does not remove the log rows |
| Performance optimization | Bulk load of 1000 rows, `CREATE INDEX`, `EXPLAIN` before and after |
| PL/SQL security | `CREATE USER`, `GRANT EXECUTE`, a view, `SQL SECURITY DEFINER`, bind variables |

## How to run
Execute the whole file. Run it in sections for the video, since it covers 7 topics.

## What you should see
- Archive procedure moves the 2025 rows into `sales_archive`.
- `sp_autonomous_demo` shows 2 log rows and 0 test rows in `sales`, even after the rollback. MySQL may show a warning about a non-transactional table. This is expected.
- The two `EXPLAIN` results differ: the first scans many rows, the second uses `idx_sales_region_date` and scans fewer.
- The security section grants and revokes access for `sales_viewer`, then drops the user.

## Notes for the video
- Run as root, because it creates and drops a user.
- `VARRAY`, `BULK COLLECT`, `FORALL` and autonomous transactions do not exist in MySQL. Say so, then show the closest equivalent.
