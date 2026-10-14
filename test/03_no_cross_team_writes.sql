-- Members cannot write into another team, or move a task into one.
begin;
\ir fixture.sql

select tests.login(tests.id('member_a'));
select tests.throws(
  $$update public.tasks set team_id = tests.id('team_b') where id = tests.id('task_a1')$$,
  '42501', 'member_a cannot move task_a1 to team B');
-- Same move without a WHERE clause. This matters: when an UPDATE reads
-- columns (any WHERE on a column), Postgres also checks the new row against
-- the SELECT policy, which would block the move on its own. Without a WHERE,
-- only WITH CHECK stands in the way. Mutation m03 proved the version above
-- alone could not tell a missing WITH CHECK apart.
select tests.throws(
  $$update public.tasks set team_id = tests.id('team_b')$$,
  '42501', 'member_a cannot move all their tasks to team B with an UPDATE that has no WHERE');
select tests.throws(
  $$insert into public.tasks (team_id, title) values (tests.id('team_b'), 'planted')$$,
  '42501', 'member_a cannot insert a task into team B');
select tests.ok(
  tests.affected($$update public.tasks set title = 'hijacked' where id = tests.id('task_b1')$$) = 0,
  'member_a''s update of a team B task changes 0 rows');

select tests.logout();
select tests.ok(
  (select team_id from public.tasks where id = tests.id('task_a1')) = tests.id('team_a'),
  'task_a1 is still in team A');
select tests.ok(
  (select title from public.tasks where id = tests.id('task_b1')) = 'Plan the offsite',
  'task_b1 is unchanged');

-- Positive control: an admin may move tasks between teams.
select tests.login(tests.id('admin_a'));
select tests.ok(
  tests.affected($$update public.tasks set team_id = tests.id('team_b') where id = tests.id('task_a1')$$) = 1,
  'admin_a can move task_a1 to team B');

rollback;
