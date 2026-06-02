# SQL Server Tips from erikdarling.com
# Crawled: pages 50-196
# Format: [category] Title (URL)\n# Tip: ...\n# SQL: ...\n\n---
[exec_plans] Cursor Declarations That Use LOB Local Variables Can Bloat Your Plan Cache (https://erikdarling.com/cursor-declarations-that-use-openjson-can-bloat-your-plan-cache/)
Tip: Cursor declarations containing LOB local variables consume excessive plan cache memory. Always use the LOCAL argument for cursor declarations or use NVARCHAR(4000) instead of MAX.
SQL: DECLARE json_cursor CURSOR LOCAL FAST_FORWARD FOR 
SELECT Number, OrderDate, Customer, Quantity
FROM OPENJSON(@json) WITH (
    Number VARCHAR(200) '$.Order.Number',
    OrderDate DATETIME '$.Order.Date',
    Customer VARCHAR(200) '$.AccountNumber',
    Quantity INT '$.Item.Quantity'
);
---

---
[query_perf] Loops, Transactions, and Transaction Log Writes In SQL Server (https://erikdarling.com/loops-transactions-and-transaction-log-writes-in-sql-server/)
Tip: For looped DML operations, avoid auto-commit transactions. Instead, use explicit transactions with conditional commits every 1,000 iterations. SQL Server writes to the log more efficiently when you batch commits.
SQL: none
---

---
[misc] Who Made That Change? Low Rent User Auditing Using Temporal Tables (https://erikdarling.com/who-made-that-change-low-rent-user-auditing-using-temporal-tables/)
Tip: Use temporal tables with computed columns calling ORIGINAL_LOGIN() and SUSER_SNAME() to capture who modified data. This detects who made the change and what data was updated/deleted, but won't track inserts.
SQL: CREATE TABLE dbo.things
(
  thing_id int CONSTRAINT pk_thing_id PRIMARY KEY,
  first_thing nvarchar(100) NOT NULL,
  original_modifier AS ISNULL(CONVERT(sysname, ORIGINAL_LOGIN()), N'?'),
  current_modifier AS ISNULL(CONVERT(sysname, SUSER_SNAME()), N'?'),
  valid_from datetime2 GENERATED ALWAYS AS ROW START HIDDEN NOT NULL,
  valid_to datetime2 GENERATED ALWAYS AS ROW END HIDDEN NOT NULL,
  PERIOD FOR SYSTEM_TIME (valid_from, valid_to)
)
WITH
(
    SYSTEM_VERSIONING = ON  
    (
        HISTORY_TABLE = dbo.things_history,
        HISTORY_RETENTION_PERIOD = 7 DAYS
    )
);
---

---
[indexes] Indexing SQL Server Queries For Performance: Equality vs. Inequality Searches (https://erikdarling.com/indexing-sql-server-queries-for-performance-equality-vs-inequality-searches/)
Tip: Queries filtering on non-selective leading index columns with inequalities may trigger Eager Index Spool operations. Resolve by reordering index keys to place selective columns first, or rewrite predicates from "< 3" to discrete equality values using IN (1, 2).
SQL: CREATE INDEX not_badges_x ON dbo.Posts (OwnerUserId, PostTypeId) INCLUDE (Score) WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);
---

---
[waits_blocking] Why Read Committed Queries Can Still Return Bad Results In SQL Server (https://erikdarling.com/why-read-committed-queries-can-still-return-bad-results-in-sql-server/)
Tip: Read committed is not a point in time snapshot of your data. Getting blocked should be reserved for special occasions.
SQL: none
---

---
[waits_blocking] Updates To sp_QuickieStore, sp_HumanEventsBlockViewer, and sp_PressureDetector (https://erikdarling.com/updates-to-sp_quickiestore-sp_humaneventsblockviewer-and-sp_pressuredetector/)
Tip: To enable parallel execution when analyzing blocking data, move contentious object name resolution to an update after the initial insert because calling OBJECT_ID() in the query forces a serial plan.
SQL: none
---

---
[indexes] Lookup Costing Is Really Weird In SQL Server (https://erikdarling.com/lookup-costing-is-really-weird-in-sql-server/)
Tip: Heaps make great staging tables; clustered indexes are very good for transactional stuff. SQL Server doesn't actually cost key or rid lookups any differently despite key lookups requiring more logical reads to navigate the clustered index structure.
SQL: none
---

---
[query_perf] The How To Write SQL Server Queries Correctly Cheat Sheet: Conditional Join and Where Clauses (https://erikdarling.com/the-how-to-write-sql-server-queries-correctly-cheat-sheet-conditional-join-and-where-clauses/)
Tip: OR operators across multiple WHERE or JOIN columns prevent efficient index seeks. Rewrite these as UNION ALL queries with supporting indexes on individual predicate columns. Don't be afraid of OPTION(RECOMPILE) when troubleshooting parameter sensitivity.
SQL: SELECT p.* FROM dbo.Posts AS p WHERE p.OwnerUserId = 22656 AND p.Score > 0
UNION ALL
SELECT p.* FROM dbo.Posts AS p WHERE p.LastEditorUserId = 22656 AND p.Score > 0;
---

---
[query_perf] Why Logical Reads Are A Bad Metric For Query Tuning In SQL Server (https://erikdarling.com/why-logical-reads-are-a-bad-metric-for-query-tuning-in-sql-server/)
Tip: Physical reads are the absolute devil. Logical reads are stuff that's already from memory. Focus on physical reads, CPU, and duration rather than logical reads when tuning queries.
SQL: none
---

---
[waits_blocking] What Else Happens When Queries Try To Compile In SQL Server: COMPILE LOCKS! (https://erikdarling.com/what-else-happens-when-queries-try-to-compile-in-sql-server-compile-locks/)
Tip: Enable auto update stats async to prevent queries from blocking on synchronous statistics refreshes during compilation. When one session waits for StatMan during compile, others acquire LCK_M_X waits until the plan generates.
SQL: UPDATE STATISTICS Votes WITH SAMPLE 20 PERCENT, PERSIST_SAMPLE_PERCENT = ON
---

---
[exec_plans] sp_QuickieStore: Now Handling The Biggest XML (https://erikdarling.com/sp_quickiestore-now-handling-the-biggest-xml/)
Tip: When Query Store XML exceeds 128 nested nodes deep, SSMS fails to render it. You can still open plans greater than 128 nested nodes deep as graphical query plans by saving the output as a .sqlplan file.
SQL: none
---

---
[anti_patterns] The How To Write SQL Server Queries Correctly Cheat Sheet: Views And Common Table Expressions Are The Same Thing (https://erikdarling.com/the-how-to-write-sql-server-queries-correctly-cheat-sheet-views-and-common-table-expressions-are-the-same-thing/)
Tip: Views and CTEs are functionally equivalent from a performance perspective; both execute their contained query for each reference. You can put equally terrible queries in either one and expect equally terrible results.
SQL: CREATE OR ALTER VIEW dbo.u_p AS SELECT TOP (100) PERCENT u.* FROM dbo.Users AS u;
---

---
[waits_blocking] A Little About PAGEIOLATCH Waits In SQL Server (https://erikdarling.com/a-little-about-pageiolatch-waits-in-sql-server/)
Tip: Every time you double memory, you'll cut your page IO latch waits in half. Before adding indexes, assess indexes - look for unused and duplicative indexes. Avoid non-sargable predicates like IS NULL, COALESCE, SUBSTRING, LEFT, RIGHT in the WHERE clause.
SQL: none
---

---
[exec_plans] SQL Server Query Transformations With ROW_NUMBER And ANY Aggregates (https://erikdarling.com/sql-server-query-transformations-with-row_number-and-any-aggregates/)
Tip: When filtering ROW_NUMBER=1 without selecting the column, SQL Server may group everything together using an any aggregate instead of the usual windowing functions. The filter must restrict the row number to one and the expression must not form part of the query result.
SQL: none
---

---
[misc] Returning A Row When Your Query Has No Results (https://erikdarling.com/returning-a-row-when-your-query-has-no-results/)
Tip: When debugging stored procedures with multiple result sets, empty results can be confusing. Use a CTE with UNION ALL and NOT EXISTS to return a placeholder row, but avoid this for long running queries since the CTE executes twice.
SQL: WITH d AS (SELECT d.database_id, d.name FROM sys.databases AS d WHERE d.database_id > 32766)
SELECT d.* FROM d
UNION ALL
SELECT 0, 'table @t is empty!'
WHERE NOT EXISTS (SELECT 1/0 FROM d AS d2);
---

---
[query_perf] bit OBSCENE Episode 3: The Habits Of Highly Successful Performance Tuners (https://erikdarling.com/bit-obscene-episode-3-the-habits-of-highly-successful-performance-tuners/)
Tip: Follow a three-step process: identify specifically why the query is slow, understand why SQL Server chose that plan, and implement a permanent fix.
SQL: none
---
[exec_plans] bit OBSCENE Episode 3: The Habits Of Highly Successful Performance Tuners (https://erikdarling.com/bit-obscene-episode-3-the-habits-of-highly-successful-performance-tuners/)
Tip: Use actual plan shows you at the operator level, IO, CPU time, elapsed time to pinpoint specific bottlenecks.
SQL: none
---
[param_sniffing] bit OBSCENE Episode 3: The Habits Of Highly Successful Performance Tuners (https://erikdarling.com/bit-obscene-episode-3-the-habits-of-highly-successful-performance-tuners/)
Tip: For parameter sniffing analysis, create a temporary stored procedure with the query text and the parameter values that are stored in the XML to test different values.
SQL: none
---
[param_sniffing] bit OBSCENE Episode 3: The Habits Of Highly Successful Performance Tuners (https://erikdarling.com/bit-obscene-episode-3-the-habits-of-highly-successful-performance-tuners/)
Tip: Adding OPTION (RECOMPILE) takes the sting out of queries with optional parameters or local variables without full rewrites.
SQL: OPTION (RECOMPILE)
---
[waits_blocking] bit OBSCENE Episode 3: The Habits Of Highly Successful Performance Tuners (https://erikdarling.com/bit-obscene-episode-3-the-habits-of-highly-successful-performance-tuners/)
Tip: Check query level wait stats like PAGE_IO_LATCH to distinguish between query issues and server-wide memory pressure.
SQL: none
---
[anti_patterns] bit OBSCENE Episode 3: The Habits Of Highly Successful Performance Tuners (https://erikdarling.com/bit-obscene-episode-3-the-habits-of-highly-successful-performance-tuners/)
Tip: Don't be overly dogmatic about things - be less dogmatic and more analytical when diagnosing performance issues.
SQL: none
---

---
[query_perf] Join Algorithm Limitations In SQL Server (https://erikdarling.com/join-algorithm-limitations-in-sql-server/)
Tip: Without an equality predicate, we cannot have a merge join, and we cannot have a hash join. Avoid joining utility tables using range conditions on large result sets as this forces nested loops joins.
SQL: none
---
---
[query_perf] The How To Write SQL Server Queries Correctly Cheat Sheet: INTERSECT And EXCEPT (https://erikdarling.com/the-how-to-write-sql-server-queries-correctly-cheat-sheet-intersect-and-except/)
Tip: Use INTERSECT to return distinct rows present in both result sets, and EXCEPT for rows found only in the first query. Both operators handle NULL comparisons natively without ISNULL, COALESCE, or confusing OR logic.
SQL: SELECT c.* FROM dbo.Comments AS c WHERE c.UserId IS NULL AND c.Score > 2
INTERSECT
SELECT c.* FROM dbo.Comments AS c WHERE c.UserId IS NULL AND c.Score > 3;
---
---
[query_perf] The How To Write SQL Server Queries Correctly Cheat Sheet: UNION vs. UNION ALL (https://erikdarling.com/the-how-to-write-sql-server-queries-correctly-cheat-sheet-union-vs-union-all/)
Tip: Avoid UNION when selecting many columns or large strings; use UNION ALL with ROW_NUMBER partitioned by key columns instead. Consider which columns actually identify a unique row rather than deduplicating every column.
SQL: SELECT x.*, ROW_NUMBER() OVER (PARTITION BY x.UserId, x.Score, x.CreationDate, x.PostId ORDER BY ...)
FROM (SELECT ... UNION ALL SELECT ...) AS x;
---
---
[indexes] Reviewing The New DACPAC Code Analysis Rules For T-SQL (https://erikdarling.com/reviewing-the-new-dacpac-code-analysis-rules-for-t-sql/)
Tip: If you're just not sure, make your primary key a bigint. You'll have a hard time going wrong there.
SQL: none
---
[anti_patterns] Reviewing The New DACPAC Code Analysis Rules For T-SQL (https://erikdarling.com/reviewing-the-new-dacpac-code-analysis-rules-for-t-sql/)
Tip: TOP without ORDER BY guarantees nothing.
SQL: none
---
[anti_patterns] Reviewing The New DACPAC Code Analysis Rules For T-SQL (https://erikdarling.com/reviewing-the-new-dacpac-code-analysis-rules-for-t-sql/)
Tip: Close your cursors, deallocate your cursors.
SQL: none
---
[query_perf] Reviewing The New DACPAC Code Analysis Rules For T-SQL (https://erikdarling.com/reviewing-the-new-dacpac-code-analysis-rules-for-t-sql/)
Tip: Avoid wrapping columns within a function in the WHERE clause.
SQL: none
---
[query_perf] Reviewing The New DACPAC Code Analysis Rules For T-SQL (https://erikdarling.com/reviewing-the-new-dacpac-code-analysis-rules-for-t-sql/)
Tip: Avoid the use of OR in a JOIN clause - joins with OR clauses really screw things up.
SQL: none
---
[configuration] Reviewing The New DACPAC Code Analysis Rules For T-SQL (https://erikdarling.com/reviewing-the-new-dacpac-code-analysis-rules-for-t-sql/)
Tip: Use SET XACT_ABORT ON for proper error handling.
SQL: SET XACT_ABORT ON
---
---
[query_perf] Fixing Parallel Row Skew With TOP In SQL Server (https://erikdarling.com/fixing-parallel-row-skew-with-top-in-sql-server-with-a-brief-re-complaint-about-cxconsumer-waits/)
Tip: Use CROSS APPLY with TOP instead of CROSS JOIN to fix parallel row skew. TOP is your friend when you have uneven parallel threads because it forces a serial zone to gather streams then distribute streams evenly across parallel workers.
SQL: CROSS APPLY (SELECT TOP 1 ...)
---
---
[anti_patterns] The How To Write SQL Server Queries Correctly Cheat Sheet: IN And NOT IN (https://erikdarling.com/the-how-to-write-sql-server-queries-correctly-cheat-sheet-in-and-not-in/)
Tip: Only use IN/NOT IN when you have a list of literal values. When querying tables, use EXISTS or NOT EXISTS instead to avoid NULL handling issues and performance hospice.
SQL: SELECT COUNT_BIG(*) FROM #NewUsers AS nu WHERE NOT EXISTS (SELECT 1/0 FROM #OldUsers AS ou WHERE nu.UserId = ou.UserId);
---
---
[query_perf] The How To Write SQL Server Queries Correctly Cheat Sheet: Cross Apply And Outer Apply (https://erikdarling.com/the-how-to-write-sql-server-queries-correctly-cheat-sheet-cross-apply-and-outer-apply/)
Tip: If someone says 'cross apply is always slow', you can bet they stink at indexes.
SQL: SELECT u.Id, u.DisplayName, p.Title, p.Score FROM dbo.Users AS u CROSS APPLY (SELECT p.* FROM dbo.Posts AS p WHERE p.OwnerUserId = u.Id ORDER BY p.CreationDate DESC OFFSET 0 ROWS FETCH NEXT 3 ROWS ONLY) AS p;
---
---
[query_perf] The How To Write SQL Server Queries Correctly Cheat Sheet: Select List Subqueries (https://erikdarling.com/the-how-to-write-sql-server-queries-correctly-cheat-sheet-select-list-subqueries/)
Tip: Ensure select list subqueries have good supporting indexes to remain fast. They can only return one row and one column, but using separate subqueries often outperforms combined joins while improving observability.
SQL: CREATE INDEX p ON dbo.Posts (OwnerUserId, PostTypeId, Score) WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);
---
---
[indexes] SQL Server Index Design: Getting Key Column Order Right (https://erikdarling.com/sql-server-index-design-getting-key-column-order-right/)
Tip: You can think of each column in the key of an index as sort of like a gatekeeper to the next column. Without searching the leading key column first, subsequent columns remain logically unordered and inefficient to seek.
SQL: none
---
---
[indexes] How To Evaluate Index Effectiveness While Tuning SQL Server Queries (https://erikdarling.com/how-to-evaluate-index-effectiveness-while-tuning-sql-server-queries/)
Tip: Use trace flag 9130 to expose residual predicates as explicit Filter operators in execution plans. This reveals whether your index narrows the result set during the seek or applies filtering later.
SQL: none
---
---
[query_perf] The How To Write SQL Server Queries Correctly Cheat Sheet: EXISTS and NOT EXISTS (https://erikdarling.com/the-how-to-write-sql-server-queries-correctly-cheat-sheet-exists-and-not-exists/)
Tip: Both EXISTS and NOT EXISTS already set a row goal of 1 since they only need to verify a row exists. Use them instead of DISTINCT or LEFT JOIN with IS NULL checks to improve efficiency on large datasets.
SQL: SELECT u.Id, u.DisplayName FROM dbo.Users AS u WHERE EXISTS (SELECT 1/0 FROM dbo.Posts AS p WHERE p.OwnerUserId = u.Id);
---
---
[query_perf] The How To Write SQL Server Queries Correctly Cheat Sheet: Joins (https://erikdarling.com/the-how-to-write-sql-server-queries-correctly-cheat-sheet/)
Tip: Always start with a SELECT to validate results before converting to INSERT, UPDATE, or DELETE. For outer joins, specify a non-nullable column to pass into the counting function rather than (*) to avoid counting NULL values.
SQL: BEGIN TRANSACTION UPDATE TOP (100) u SET u.Reputation += 1000 OUTPUT 'D' AS d, Deleted.*, 'I' AS i, Inserted.* FROM dbo.Users AS u WHERE u.Reputation < 1000 AND u.Reputation > 1; ROLLBACK TRANSACTION;
---
---
[exec_plans] What SQL Server's Query Optimizer Doesn't Know About Numbers (https://erikdarling.com/what-sql-servers-query-optimizer-doesnt-know-about-numbers/)
Tip: Sometimes the way you phrase your queries makes a very big difference for performance. SQL Server cannot infer that IN (1, 2) equals < 3 even with check constraints, causing it to build an index spool instead of performing a seek.
SQL: post_type_id IN (1, 2) -- vs post_type_id < 3
---
---
[indexes] Indexing SQL Server Queries For Performance: Fixing Unpredictable Search Queries (https://erikdarling.com/indexing-sql-server-queries-for-performance-fixing-unpredictable-search-queries/)
Tip: For unpredictable search patterns, nonclustered columnstore indexes can go a lot further for performance with unpredictable predicates compared to rowstore indexes with rigid key column ordering.
SQL: CREATE NONCLUSTERED COLUMNSTORE INDEX nodependent ON dbo.Posts (OwnerUserId, Score, CreationDate, LastActivityDate, PostTypeId, Id, Title) WITH(MAXDOP = 1);
---
---
[indexes] Indexing SQL Server Queries For Performance: Fixing Windowing Functions (https://erikdarling.com/indexing-sql-server-queries-for-performance-fixing-windowing-functions/)
Tip: To optimize ranking windowing functions, ensure indexes include the PARTITION BY and ORDER BY columns. The index needs to match the sort directions of those columns exactly or the optimizer cannot eliminate the sort.
SQL: CREATE INDEX v ON dbo.Votes (PostId, VoteTypeId, CreationDate DESC) INCLUDE (UserId, BountyAmount) WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE, DROP_EXISTING = ON);
---
---
[indexes] Indexing SQL Server Queries For Performance: Fixing A Sort (https://erikdarling.com/indexing-sql-server-queries-for-performance-fixing-a-sort/)
Tip: Design composite indexes with equality predicate columns first so subsequent columns remain ordered for joins without additional sorts. Query cost has nothing to do with query speed and not every query can or should have perfect indexes.
SQL: CREATE INDEX v ON dbo.Votes (PostId, VoteTypeId) WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);
---
---
[exec_plans] A Little About Nested Loops, Parallelism, and the Perils of Recursive Common Table Expressions (https://erikdarling.com/a-little-about-nested-loops-parallelism-and-the-perils-of-recursive-common-table-expressions/)
Tip: Parallel nested loops are only chosen for the inner side when the outer side has a one row guarantee and are highly sensitive to parallel skew. Adding TOP forces a serial zone using distribute streams to evenly redistribute rows.
SQL: none
---
---
[indexes] When SQL Server Isn't Smart About Aggregates Part 2 (https://erikdarling.com/when-sql-server-isnt-smart-about-aggregates-part-2/)
Tip: Additional indexes are not always helpful for aggregation queries and may result in really weird plan choices. When optimizer avoids early aggregation, manual rewrite is necessary.
SQL: CREATE INDEX p2 ON dbo.Posts (OwnerUserId, Score) WITH (MAXDOP = 8, SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);
---
---
[query_perf] When SQL Server Isn't Smart About Aggregates Part 1 (https://erikdarling.com/when-sql-server-isnt-smart-about-aggregates-part-1/)
Tip: SQL Server's optimizer occasionally makes poor aggregate placement decisions, fully joining both tables prior to doing the final aggregation. Manually pre-aggregating tables via CTEs can reduce execution time from 23 seconds to under one second.
SQL: WITH p AS (SELECT UserId = p.OwnerUserId, Score = MAX(p.Score) FROM dbo.Posts AS p GROUP BY p.OwnerUserId) SELECT PScore = MAX(p.Score), CScore = MAX(c.Score) FROM p JOIN dbo.Comments AS c ON c.UserId = p.UserId;
---
---
[indexes] Indexing SQL Server Queries For Performance: Fixing Aggregates With An Indexed View (https://erikdarling.com/indexing-sql-server-queries-for-performance-fixing-aggregates-with-an-indexed-view/)
Tip: Creating indexed views spanning multiple tables creates significant maintenance overhead. They are borderline unusable due to restrictions, and creating them may take hours while base table modifications become slow.
SQL: CREATE UNIQUE CLUSTERED INDEX RTG ON dbo.ReadyToGo (Id) WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);
---
---
[exec_plans] What Happens To Queries With Recompile Hints In Query Store (https://erikdarling.com/what-happens-to-queries-with-recompile-hints-in-query-store/)
Tip: When analyzing Query Store data for queries using OPTION(RECOMPILE), look for literal values in predicates rather than Parameter List attributes, as the optimizer will compile a plan based on the literal values that get passed in.
SQL: SELECT c = COUNT_BIG(*) FROM dbo.Posts AS p WHERE p.OwnerUserId = @OwnerUserId OPTION(RECOMPILE);
---
---
[waits_blocking] A Follow Up On HT Waits, Row Mode, Batch Mode, and SQL Server Error 666 (https://erikdarling.com/a-follow-up-on-ht-waits-row-mode-batch-mode-and-sql-server-error-666/)
Tip: When processing lots of rows, batch mode is usually way better than row mode. If using row mode with multiple distinct aggregates, pre-aggregate data to avoid Error 666.
SQL: none
---
---
[waits_blocking] Performance Tuning Batch Mode HTDELETE and HTBUILD Waits In SQL Server (https://erikdarling.com/performance-tuning-batch-mode-htdelete-and-htbuild-waits-in-sql-server/)
Tip: High HT build and HT delete waits indicate batch mode hash operations spilling due to cardinality misestimations. Isolate joins to contain misestimations and keep bad estimates self-contained using temp tables or derived tables.
SQL: -- Isolate joins with temp tables or derived tables to contain cardinality misestimations
---
---
[indexes] Why Partially Fixing Key Lookups Doesn't Work In SQL Server (https://erikdarling.com/why-partially-fixing-key-lookups-doesnt-work-in-sql-server/)
Tip: Key lookups incur identical per-loop costs whether retrieving one or all columns, so widening indexes creates unnecessary maintenance overhead without improving query plans. Key lookup has the exact same per loop cost.
SQL: none
---
---
[indexes] Indexing SQL Server Queries For Performance: Fixing A Non-SARGable Predicate (https://erikdarling.com/indexing-sql-server-queries-for-performance-fixing-a-non-sargable-predicate/)
Tip: When unable to modify third-party queries containing non-SARGable predicates, change the key column order of your index so the column with a seekable predicate can go first to improve performance without code changes.
SQL: CREATE INDEX p ON dbo.Posts (Score, CommunityOwnedDate) WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE, DROP_EXISTING = ON);
---
---
[exec_plans] Creating Uncacheable Stored Procedures In SQL Server (https://erikdarling.com/creating-uncacheable-stored-procedures-in-sql-server/)
Tip: To prevent SQL Server from caching a stored procedure's query plan, include a conditional branch referencing a non-existent object that never executes, ensuring no query plan will ever be cached for this stored procedure.
SQL: IF @decider='false' BEGIN SELECT whatever.* FROM dbo.AnObjectThatDoesntEvenPretendToExist AS whatever; END;
---
---
[query_perf] sp_QuickieStore: Find Your Worst Performing Queries During Working Hours (https://erikdarling.com/sp_quickiestore-find-your-worst-performing-queries-during-working-hours/)
Tip: Use @work_days=1 with @work_start and @work_end to find queries that end users complain about instead of off-hours noise. Anyone can find a slow query, but you want what end users will be happy if you tune.
SQL: EXEC sp_QuickieStore @work_days = 1, @work_start = '8:00 AM', @work_end = '5:00 PM';
---
---
[indexes] Indexing SQL Server Queries For Performance: Fixing Predicate Key Lookups (https://erikdarling.com/indexing-sql-server-queries-for-performance-good-practices/)
Tip: Changing existing indexes in a way that rearranges key column order can be perilous. Consider adding predicate columns to the index key to eliminate key lookups.
SQL: CREATE INDEX p ON dbo.Posts (Score, CreationDate, PostTypeId, OwnerUserId) WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE, DROP_EXISTING = ON);
---
---
[indexes] Indexing SQL Server Queries For Performance: Common Questions (https://erikdarling.com/indexing-sql-server-queries-for-performance-common-questions/)
Tip: In general, there's not a lot of sense to leaving tables as heaps in SQL Server, at least for OLTP workloads. If you don't access the leading key, accessing any following keys is less efficient. The most selective column should not always come first.
SQL: none
---
---
[tools] Free SQL Server Troubleshooting Stored Procedures (https://erikdarling.com/free-sql-server-troubleshooting-stored-procedures/)
Tip: Execute sp_HealthParser with @warnings_only = 1 to surface only rows where columns flip to WARNING, or use sp_QuickieStore with @workdays = 1 to exclude overnight problems from results.
SQL: EXEC dbo.sp_QuickieStore @workdays = 1, @work_start = '9am', @work_end = '5pm';
---
