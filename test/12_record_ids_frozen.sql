-- A row's id never changes once written. The audit log files every row's
-- history under record_id = id, so a changed id splits that history in two:
-- the old entries point at an id that no longer exists, and the row carries on
-- under a new one as if it had no past. Nobody may do it, admins included.
begin;
\ir fixture.sql

create temporary table snap as select coalesce(max(id), 0) as last_id from public.audit_log;

-- member_a may edit task_a1 (own team), but not its id.
select tests.login(tests.id('member_a'));
select tests.throws(
  $$update public.tasks set id = '30000000-0000-0000-0000-0000000000f1' where id = tests.id('task_a1')$$,
  '42501', 'member_a cannot change the id of a task in their own team');
select tests.throws(
  $$update public.tasks set id = gen_random_uuid()$$,
  '42501', 'member_a cannot change task ids with an UPDATE that has no WHERE');

-- Positive control: the guard rejects a new id, not every write that names
-- the column. PostgREST upserts send `set id = excluded.id`, i.e. the same id.
select tests.ok(
  tests.affected($$update public.tasks set id = id, title = 'Write the onboarding guide v2' where id = tests.id('task_a1')$$) = 1,
  'control: member_a can still edit task_a1, even when the statement sets id to its own value');

select tests.login(tests.id('admin_a'));
select tests.throws(
  $$update public.tasks set id = '30000000-0000-0000-0000-0000000000f2' where id = tests.id('task_b1')$$,
  '42501', 'admin_a cannot change the id of a task either');

-- Teams and profiles are audited the same way, so the same rule holds. A
-- fresh team and a fresh auth user keep foreign keys out of the way: without
-- the guard, both statements below would succeed.
insert into public.teams (id, name) values ('00000000-0000-0000-0000-0000000000fc', 'Team C');
select tests.throws(
  $$update public.teams set id = '00000000-0000-0000-0000-0000000000fd' where id = '00000000-0000-0000-0000-0000000000fc'$$,
  '42501', 'admin_a cannot change the id of a team');

select tests.logout();
insert into auth.users (id, email) values ('10000000-0000-0000-0000-0000000000f9', 'spare@example.test');
select tests.login(tests.id('admin_a'));
select tests.throws(
  $$update public.profiles set id = '10000000-0000-0000-0000-0000000000f9' where id = tests.id('viewer_a')$$,
  '42501', 'admin_a cannot move a profile to another id');

select tests.logout();
select tests.ok(
  (select count(*) from public.tasks where id in (tests.id('task_a1'), tests.id('task_b1'))) = 2
  and not exists (select 1 from public.tasks where id::text like '30000000-0000-0000-0000-0000000000f%'),
  'task_a1 and task_b1 still exist under their original ids');
select tests.ok(
  not exists (select 1 from public.audit_log
              where id > (select last_id from snap)
                and record_id in ('30000000-0000-0000-0000-0000000000f1', '30000000-0000-0000-0000-0000000000f2',
                                  '00000000-0000-0000-0000-0000000000fd', '10000000-0000-0000-0000-0000000000f9')),
  'no audit row was filed under a new id');
select tests.ok(
  (select count(*) from public.audit_log
   where id > (select last_id from snap) and record_id = tests.id('task_a1') and action = 'UPDATE') = 1,
  'the allowed edit of task_a1 is filed under task_a1');

-- Structural check: every table the audit trigger writes about has the guard.
-- A table audited without it is the gap this test exists for.
create temporary table audited as
  select distinct tgrelid::regclass::text as tbl from pg_trigger
  where tgfoid = 'private.audit_row()'::regprocedure and not tgisinternal;
create temporary table frozen as
  select distinct tgrelid::regclass::text as tbl from pg_trigger
  where tgfoid = 'private.freeze_id()'::regprocedure and not tgisinternal;

select tests.ok((select count(*) from audited) >= 3, 'control: the audited tables are found (tasks, profiles, teams)');
select tests.ok(
  not exists (select tbl from audited except select tbl from frozen),
  'every audited table freezes its id: ' ||
  coalesce((select string_agg(tbl, ', ') from (select tbl from audited except select tbl from frozen) m), 'none missing'));

rollback;
