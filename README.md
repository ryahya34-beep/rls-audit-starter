# rls-audit-starter

[![test](https://github.com/ryahya34-beep/rls-audit-starter/actions/workflows/test.yml/badge.svg)](https://github.com/ryahya34-beep/rls-audit-starter/actions/workflows/test.yml)

A small Postgres/Supabase schema for a team task tracker that shows two things
done properly and proves both with tests:

1. **Row Level Security per role.** Members work inside their own team, viewers
   only read, admins manage everything, visitors without a session get nothing.
2. **An audit trail that cannot be skipped or forged.** Triggers record every
   write with the actor taken from the verified JWT. Nobody using the API can
   write, edit or erase the log, admins included.

The tests do not just pass. A second script breaks the schema on purpose in
18 different ways and requires the suite to fail every time.

```
$ test/local.sh
PASS  01_read_isolation (10 checks)
...
11 passed, 0 failed, 69 checks

KILLED    m03_team_move_allowed: tasks UPDATE policy without a real WITH CHECK, so tasks can change team
          caught by: 03_no_cross_team_writes
...
18 of 18 mutations killed
```

No UI, no framework. Under 300 lines of schema SQL, half of it comments, readable in ten minutes.

## Access rules

|                         | anon | viewer        | member              | admin |
|-------------------------|------|---------------|---------------------|-------|
| Read tasks              | no   | own team      | own team            | all   |
| Create / edit tasks     | no   | no            | own team only       | all   |
| Move a task to a team   | no   | no            | no                  | yes   |
| Delete tasks            | no   | no            | no                  | yes   |
| Read profiles           | no   | own team      | own team            | all   |
| Change roles            | no   | no            | no                  | yes   |
| Read the audit log      | no   | no            | no                  | yes   |
| Write the audit log     | no   | no            | no                  | no    |

## Layout

```
sql/001_schema.sql     tables: teams, profiles, tasks, audit_log
sql/002_rls.sql        grants, helper functions, policies
sql/003_audit.sql      author stamp and audit triggers
test/shim.sql          the bits of Supabase needed on plain Postgres
test/helpers.sql       tests.login(), tests.ok(), tests.affected(), tests.throws()
test/fixture.sql       two teams, four people, three tasks
test/NN_*.sql          the tests, each inside BEGIN ... ROLLBACK
test/mutations/        18 deliberate breakages
test/run.sh            build a fresh database and run the tests
test/mutation.sh       apply each mutation and require a red suite
test/local.sh          both of the above on a throwaway local cluster
```

## Running it

With Postgres installed locally (`initdb`, `pg_ctl`, `psql` on your PATH):

```bash
test/local.sh
```

It creates a temporary cluster reachable only through a socket in a temp
directory, runs everything, and deletes it. Against a server you already have,
as a superuser:

```bash
PGHOST=localhost PGUSER=postgres test/run.sh
```

CI runs both scripts on every push against `postgres:17`.

### Using it in a Supabase project

Run `sql/001_schema.sql`, `sql/002_rls.sql` and `sql/003_audit.sql` in order,
as migrations or in the SQL Editor. Skip everything in `test/`: Supabase already
has the roles, the `auth` schema and `auth.uid()` that `test/shim.sql` imitates.

## What the mutation tests found

The first run killed 17 of 18 mutations. The survivor was m03: the tasks UPDATE
policy with `with check (true)`, which should let a member move a task into
another team. The test tried exactly that:

```sql
update public.tasks set team_id = :team_b where id = :task_a1;
```

and it was still rejected, so the test could not tell the broken policy from
the correct one. The reason is a Postgres rule that is easy to miss: when an
UPDATE reads a column (here, the `WHERE`), the new row must also pass the
SELECT policy, and team B's row is invisible to a team A member. Drop the
`WHERE` and that second check disappears:

```sql
update public.tasks set team_id = :team_b;   -- moves every team A task
```

With the mutation applied, that statement moved all of team A's tasks to team
B. With the real policy it fails with 42501. Test 03 now covers both shapes,
and m03 is killed. Without the mutation run, the gap would have stayed hidden
behind a green suite.

## Pitfalls this starter handles

- **A blocked UPDATE or DELETE is not an error.** RLS filters the target rows
  first, so a forbidden `delete` finishes cleanly with 0 rows. Checking "did it
  error?" reports a working attack as blocked and a blocked one as working.
  The tests count affected rows (`tests.affected()`) and compare the data
  before and after.
- **Policies that query their own table recurse.** A profiles policy written as
  `exists (select 1 from profiles where ...)` stops with `infinite recursion
  detected in policy` (42P17), taking down every table whose policy reads
  profiles. The role lookups live in `SECURITY DEFINER` helpers instead. Test 09
  and mutation m09 guard this.
- **`SECURITY DEFINER` without a pinned `search_path`.** Such a function runs
  with its owner's rights but resolves names through the caller's search path.
  Every definer function here sets `search_path = ''` and qualifies every name.
  Test 08 checks all of them, so a new one cannot be added without it.
- **Functions are executable by everyone by default.** Postgres grants EXECUTE
  on new functions to PUBLIC. Each function here revokes it explicitly.
- **Tables are no longer exposed by default.** Supabase projects created after
  30 May 2026 no longer grant new public tables to `anon` and `authenticated`
  automatically, and existing projects follow on 30 October 2026
  ([changelog](https://supabase.com/changelog/45329-breaking-change-tables-not-exposed-to-data-and-graphql-api-automatically)).
  This starter grants each table explicitly and test 10 pins those grants, so
  the schema behaves the same on old and new projects.
- **The actor comes from the token, not the payload.** A trigger overwrites
  `created_by` with `auth.uid()` on insert and freezes it on update. Test 06
  sends a forged author and checks it is ignored, both in the row and in the
  audit log.

## Design notes

- **Why triggers for the audit log, not application code?** Anyone with a
  session can call the Data API directly and skip your app. A trigger fires on
  every path. Writes made with the `service_role` key are audited too, with an
  empty actor, which is itself a useful signal.
- **Why does nobody, not even an admin, get to delete audit rows?** A log the
  most powerful user can edit does not settle a dispute about what that user
  did. The database owner can still change anything; if you need protection
  from that, ship the log somewhere the owner cannot write.
- **Why not `supa_audit` or pgTAP?** Both are good, and in a real project they
  are reasonable choices: [`supa_audit`](https://github.com/supabase/supa_audit)
  for table history and [pgTAP](https://pgtap.org/) (or
  [Basejump's test helpers](https://database.dev/basejump/supabase_test_helpers))
  for database tests. This starter uses plain SQL so every moving part is
  visible and it runs on any Postgres with nothing to install.
- **Performance.** Supabase recommends wrapping function calls in policies as
  `(select fn())` so Postgres evaluates them once per statement instead of per
  row. The policies here call the helpers directly to stay easy to read. If you
  add the wrapper, run the suite: test 09 will tell you if a profiles policy
  starts recursing.

## Scope

In: one organisation, teams, three roles, tasks, an audit trail for tasks and
profiles, tests.

Out, on purpose: a UI, sign-up and invitations (profiles are created by an
admin), multiple organisations, auditing of `teams`, and log retention. Each is
a reasonable next step and none changes the patterns above.

## License

MIT
