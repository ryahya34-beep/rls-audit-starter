-- Nobody using the API can write, change or erase the audit log. Not even an
-- admin. The row count before and after is the evidence, not the error alone.
begin;
\ir fixture.sql

create temporary table snap as select count(*) as n from public.audit_log;
-- Readable while acting as a user, so the admin check below can compare.
grant select on snap to authenticated;
select tests.ok((select n from snap) > 0, 'control: the fixture produced audit rows');

select tests.login(tests.id('member_a'));
select tests.throws(
  $$insert into public.audit_log (table_name, action, actor) values ('tasks', 'INSERT', tests.id('member_b'))$$,
  '42501', 'member_a cannot insert a forged audit row');
select tests.ok((select count(*) from public.audit_log) = 0, 'member_a cannot read the audit log');

select tests.login(tests.id('admin_a'));
select tests.ok((select count(*) from public.audit_log) = (select n from snap), 'admin_a can read the whole audit log');
select tests.throws(
  $$insert into public.audit_log (table_name, action, actor) values ('tasks', 'INSERT', tests.id('member_b'))$$,
  '42501', 'admin_a cannot insert a forged audit row');
select tests.throws(
  $$update public.audit_log set actor = tests.id('member_b')$$,
  '42501', 'admin_a cannot rewrite audit rows');
select tests.throws(
  $$delete from public.audit_log$$,
  '42501', 'admin_a cannot delete audit rows');
select tests.throws(
  $$truncate public.audit_log$$,
  '42501', 'admin_a cannot truncate the audit log');

select tests.logout();
select tests.ok((select count(*) from public.audit_log) = (select n from snap), 'the audit log has the same number of rows as before');
select tests.ok(
  not exists (select 1 from public.audit_log where actor = tests.id('member_b')),
  'no audit row names member_b');

rollback;
