-- Viewers can read but not write. A blocked UPDATE or DELETE does not raise
-- an error; it changes 0 rows. So the test counts rows, not errors.
begin;
\ir fixture.sql

select tests.login(tests.id('viewer_a'));
select tests.throws(
  $$insert into public.tasks (team_id, title) values (tests.id('team_a'), 'sneaky')$$,
  '42501', 'viewer_a cannot insert a task');
select tests.ok(
  tests.affected($$update public.tasks set title = 'changed' where id = tests.id('task_a1')$$) = 0,
  'viewer_a''s update changes 0 rows');
select tests.ok(
  tests.affected($$delete from public.tasks where id = tests.id('task_a1')$$) = 0,
  'viewer_a''s delete removes 0 rows');

select tests.logout();
select tests.ok(
  (select title from public.tasks where id = tests.id('task_a1')) = 'Write the onboarding guide',
  'task_a1 is unchanged after viewer_a''s attempts');

-- Positive control: the same statements do work for a member of the team.
select tests.login(tests.id('member_a'));
select tests.ok(
  tests.affected($$update public.tasks set title = 'changed' where id = tests.id('task_a1')$$) = 1,
  'member_a''s identical update changes 1 row');
select tests.ok(
  tests.affected($$insert into public.tasks (team_id, title) values (tests.id('team_a'), 'new task')$$) = 1,
  'member_a can insert a task into team A');

rollback;
