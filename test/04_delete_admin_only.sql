-- Only admins delete tasks.
begin;
\ir fixture.sql

select tests.login(tests.id('member_a'));
select tests.ok(
  tests.affected($$delete from public.tasks where id = tests.id('task_a1')$$) = 0,
  'member_a''s delete of their own team''s task removes 0 rows');

select tests.logout();
select tests.ok(exists (select 1 from public.tasks where id = tests.id('task_a1')), 'task_a1 still exists');

select tests.login(tests.id('admin_a'));
select tests.ok(
  tests.affected($$delete from public.tasks where id = tests.id('task_a1')$$) = 1,
  'admin_a''s delete removes 1 row');

select tests.logout();
select tests.ok(not exists (select 1 from public.tasks where id = tests.id('task_a1')), 'task_a1 is gone');

rollback;
