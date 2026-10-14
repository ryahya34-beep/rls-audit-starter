-- Regression test for a real trap: a profiles policy that queries profiles
-- inline makes Postgres stop with "infinite recursion detected in policy"
-- (SQLSTATE 42P17), and every table whose policy reads profiles breaks with
-- it. The SECURITY DEFINER helpers in 002_rls.sql avoid that.
begin;
\ir fixture.sql

select tests.login(tests.id('member_a'));
select tests.ok((select count(*) from public.profiles) = 3, 'member_a can read profiles without recursion');
select tests.ok((select count(*) from public.tasks) = 2, 'member_a can read tasks, whose policy reads profiles');

select tests.login(tests.id('admin_a'));
select tests.ok(
  tests.affected($$update public.profiles set display_name = 'Viewer A.' where id = tests.id('viewer_a')$$) = 1,
  'admin_a can update a profile, which runs the update and select policies on profiles');

rollback;
