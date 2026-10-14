-- Every write leaves an audit row, and the actor is whoever the JWT says,
-- not whoever the request body claims.
begin;
\ir fixture.sql

create temporary table snap as select coalesce(max(id), 0) as last_id from public.audit_log;

-- member_a creates a task and tries to credit it to member_b.
select tests.login(tests.id('member_a'));
insert into public.tasks (id, team_id, title, created_by)
values ('30000000-0000-0000-0000-000000000001', tests.id('team_a'), 'forged author', tests.id('member_b'));

-- ...and later tries to rewrite the author on an existing task.
update public.tasks set status = 'doing', created_by = tests.id('member_b')
where id = '30000000-0000-0000-0000-000000000001';

select tests.logout();
select tests.ok(
  (select created_by from public.tasks where id = '30000000-0000-0000-0000-000000000001') = tests.id('member_a'),
  'created_by is member_a even though the client sent member_b, on insert and on update');

select tests.ok(
  (select actor from public.audit_log
   where id > (select last_id from snap) and action = 'INSERT'
     and record_id = '30000000-0000-0000-0000-000000000001') = tests.id('member_a'),
  'the INSERT audit row names member_a as actor');

select tests.ok(
  (select old_data ->> 'status' = 'todo' and new_data ->> 'status' = 'doing' and actor = tests.id('member_a')
   from public.audit_log
   where id > (select last_id from snap) and action = 'UPDATE'
     and record_id = '30000000-0000-0000-0000-000000000001'),
  'the UPDATE audit row keeps the before and after values and the actor');

-- An admin deletes a task.
select tests.login(tests.id('admin_a'));
delete from public.tasks where id = tests.id('task_a2');
select tests.logout();
select tests.ok(
  (select actor = tests.id('admin_a') and old_data ->> 'title' = 'Review the Q3 budget'
   from public.audit_log
   where id > (select last_id from snap) and action = 'DELETE' and record_id = tests.id('task_a2')),
  'the DELETE audit row names admin_a and keeps the deleted data');

-- An admin promotes a viewer: role changes are audited too.
select tests.login(tests.id('admin_a'));
update public.profiles set role = 'member' where id = tests.id('viewer_a');
select tests.logout();
select tests.ok(
  (select old_data ->> 'role' = 'viewer' and new_data ->> 'role' = 'member' and actor = tests.id('admin_a')
   from public.audit_log
   where id > (select last_id from snap) and table_name = 'profiles' and record_id = tests.id('viewer_a')),
  'the role change is audited with the admin as actor');

-- A write that RLS blocked leaves no audit row: nothing happened.
create temporary table mid as select max(id) as last_id from public.audit_log;
select tests.login(tests.id('viewer_a'));  -- now a member of team A, still not admin
select tests.ok(
  tests.affected($$update public.tasks set title = 'x' where id = tests.id('task_b1')$$) = 0,
  'an update outside the team changes 0 rows');
select tests.logout();
select tests.ok(
  (select count(*) from public.audit_log where id > (select last_id from mid)) = 0,
  'a blocked write adds no audit row');

rollback;
