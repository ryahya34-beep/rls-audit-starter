-- Changes to teams are audited like tasks and profiles: creating, renaming
-- and deleting a team each leave a row naming the admin who did it.
begin;
\ir fixture.sql

create temporary table snap as select coalesce(max(id), 0) as last_id from public.audit_log;

select tests.login(tests.id('admin_a'));
insert into public.teams (id, name) values ('00000000-0000-0000-0000-0000000000fc', 'Team C');
update public.teams set name = 'Team C (renamed)' where id = '00000000-0000-0000-0000-0000000000fc';
delete from public.teams where id = '00000000-0000-0000-0000-0000000000fc';
select tests.logout();

select tests.ok(
  (select actor = tests.id('admin_a') and new_data ->> 'name' = 'Team C'
   from public.audit_log
   where id > (select last_id from snap) and table_name = 'teams' and action = 'INSERT'
     and record_id = '00000000-0000-0000-0000-0000000000fc'),
  'creating a team is audited with admin_a as actor');
select tests.ok(
  (select actor = tests.id('admin_a') and old_data ->> 'name' = 'Team C' and new_data ->> 'name' = 'Team C (renamed)'
   from public.audit_log
   where id > (select last_id from snap) and table_name = 'teams' and action = 'UPDATE'
     and record_id = '00000000-0000-0000-0000-0000000000fc'),
  'renaming a team is audited with the before and after names');
select tests.ok(
  (select actor = tests.id('admin_a') and old_data ->> 'name' = 'Team C (renamed)'
   from public.audit_log
   where id > (select last_id from snap) and table_name = 'teams' and action = 'DELETE'
     and record_id = '00000000-0000-0000-0000-0000000000fc'),
  'deleting a team is audited and keeps the deleted data');

-- A rename RLS blocked leaves no row: nothing happened.
create temporary table mid as select max(id) as last_id from public.audit_log;
select tests.login(tests.id('member_a'));
select tests.ok(
  tests.affected($$update public.teams set name = 'hijacked' where id = tests.id('team_a')$$) = 0,
  'member_a''s rename of their own team changes 0 rows');
select tests.logout();
select tests.ok(
  (select count(*) from public.audit_log where id > (select last_id from mid)) = 0,
  'a blocked team rename adds no audit row');

-- Structural check: every table in public except the log itself is audited.
-- A new table added without the trigger would have no history at all.
create temporary table unaudited as
  select c.relname::text as tbl from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and c.relname <> 'audit_log'
    and not exists (select 1 from pg_trigger t
                    where t.tgrelid = c.oid and t.tgfoid = 'private.audit_row()'::regprocedure);

select tests.ok(
  (select count(*) from pg_trigger where tgfoid = 'private.audit_row()'::regprocedure) >= 3,
  'control: the audit triggers are found');
select tests.ok(
  not exists (select 1 from unaudited),
  'every public table except audit_log has the audit trigger: ' ||
  coalesce((select string_agg(tbl, ', ') from unaudited), 'none missing'));

rollback;
