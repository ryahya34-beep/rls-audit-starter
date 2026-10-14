-- The grant layer, checked on its own. RLS is the second wall; this is the first.
begin;

select tests.ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where grantee = 'anon' and table_schema = 'public'),
  'anon holds no privileges on any public table');

select tests.ok(
  not exists (
    select 1 from information_schema.role_table_grants
    where grantee in ('authenticated', 'service_role') and table_schema = 'public'
      and table_name = 'audit_log' and privilege_type <> 'SELECT'),
  'API roles hold only SELECT on audit_log');

-- RLS must be on for every table in public. A new table without it is
-- exposed in full to any role that is granted access.
select tests.ok(
  not exists (
    select 1 from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  'row level security is enabled on every public table: ' ||
  coalesce((select string_agg(c.relname, ', ') from pg_class c join pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity), 'none missing'));

-- Positive control: the query does see grants that exist.
select tests.ok(
  exists (
    select 1 from information_schema.role_table_grants
    where grantee = 'authenticated' and table_schema = 'public' and table_name = 'tasks'),
  'control: authenticated holds privileges on tasks');

rollback;
