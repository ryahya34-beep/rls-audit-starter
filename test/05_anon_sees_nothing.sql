-- A visitor without a session reaches no rows and writes nothing.
-- anon has no grants, so every statement fails with 42501. If someone adds a
-- grant later, RLS (no policies for anon) still returns 0 rows; this test
-- accepts either outcome and 10_grants.sql pins the grant layer itself.
begin;
\ir fixture.sql

create function pg_temp.anon_rows(tbl text) returns bigint
language plpgsql as $$
declare n bigint;
begin
  execute format('select count(*) from public.%I', tbl) into n;
  return n;
exception when insufficient_privilege then
  return 0;
end $$;

select tests.ok((select count(*) from public.tasks) = 3, 'control: 3 tasks exist');

select tests.login_anon();
select tests.ok(pg_temp.anon_rows('tasks') = 0, 'anon reaches 0 tasks');
select tests.ok(pg_temp.anon_rows('teams') = 0, 'anon reaches 0 teams');
select tests.ok(pg_temp.anon_rows('profiles') = 0, 'anon reaches 0 profiles');
select tests.ok(pg_temp.anon_rows('audit_log') = 0, 'anon reaches 0 audit rows');
select tests.throws(
  $$insert into public.tasks (team_id, title) values (tests.id('team_a'), 'spam')$$,
  '42501', 'anon cannot insert a task');

rollback;
