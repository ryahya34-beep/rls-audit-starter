-- Static checks on the functions that run with elevated rights.
begin;

-- Every SECURITY DEFINER function must pin search_path, otherwise a caller
-- may be able to put their own objects ahead of the intended ones.
create temporary table definers as
  select p.oid::regprocedure::text as fn,
         coalesce(array_to_string(p.proconfig, ','), '') like '%search_path=%' as pinned
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where p.prosecdef and n.nspname in ('public', 'private');

select tests.ok((select count(*) from definers) >= 3, 'control: the definer functions are found (audit_row, my_role, my_team)');
select tests.ok(
  (select count(*) from definers where not pinned) = 0,
  'every SECURITY DEFINER function pins search_path: ' ||
  coalesce((select string_agg(fn, ', ') from definers where not pinned), 'none missing'));

-- The audit writer and the author stamp are not callable by API roles.
select tests.ok(not has_function_privilege('authenticated', 'private.audit_row()', 'execute'), 'authenticated cannot execute audit_row()');
select tests.ok(not has_function_privilege('anon', 'private.audit_row()', 'execute'), 'anon cannot execute audit_row()');
select tests.ok(not has_function_privilege('authenticated', 'private.stamp_task()', 'execute'), 'authenticated cannot execute stamp_task()');

-- The role helpers are for policies; anon has no business calling them.
select tests.ok(not has_function_privilege('anon', 'private.my_role()', 'execute'), 'anon cannot execute my_role()');

-- Positive control: the check does detect a granted privilege.
select tests.ok(has_function_privilege('authenticated', 'private.my_role()', 'execute'), 'control: authenticated can execute my_role()');

rollback;
