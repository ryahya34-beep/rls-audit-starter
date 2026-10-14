-- Small assertion helpers for the SQL tests. Plain PL/pgSQL, no extensions.

create schema tests;
grant usage on schema tests to anon, authenticated;

-- Fixed ids for the people in test/fixture.sql, so tests read as names.
create function tests.id(name text) returns uuid
language sql immutable
as $$
  select case name
    when 'admin_a'  then '10000000-0000-0000-0000-000000000001'
    when 'member_a' then '10000000-0000-0000-0000-000000000002'
    when 'viewer_a' then '10000000-0000-0000-0000-000000000003'
    when 'member_b' then '10000000-0000-0000-0000-000000000004'
    when 'team_a'   then '00000000-0000-0000-0000-00000000000a'
    when 'team_b'   then '00000000-0000-0000-0000-00000000000b'
    when 'task_a1'  then '20000000-0000-0000-0000-000000000001'
    when 'task_a2'  then '20000000-0000-0000-0000-000000000002'
    when 'task_b1'  then '20000000-0000-0000-0000-000000000003'
  end::uuid
$$;

-- Act as a signed-in user, the way PostgREST does for a request with a JWT.
-- SET LOCAL keeps the switch inside the test's transaction.
create function tests.login(uid uuid) returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end
$$;

-- Act as a visitor with no session.
create function tests.login_anon() returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '', true);
  execute 'set local role anon';
end
$$;

-- Back to the superuser that owns the fixture, to inspect the real state.
create function tests.logout() returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '', true);
  execute 'reset role';
end
$$;

create function tests.ok(passed boolean, description text) returns void
language plpgsql
as $$
begin
  if passed is distinct from true then
    raise exception 'FAIL: %', description;
  end if;
  raise notice 'ok - %', description;
end
$$;

-- Number of rows a statement actually changed. An UPDATE or DELETE that RLS
-- filters down to nothing finishes without an error, so "no error" proves
-- nothing; the row count does.
create function tests.affected(stmt text) returns bigint
language plpgsql
as $$
declare
  n bigint;
begin
  execute stmt;
  get diagnostics n = row_count;
  return n;
end
$$;

-- Passes only if the statement fails with the expected SQLSTATE.
create function tests.throws(stmt text, expected_state text, description text) returns void
language plpgsql
as $$
begin
  begin
    execute stmt;
  exception when others then
    if sqlstate = expected_state then
      raise notice 'ok - % (% %)', description, sqlstate, sqlerrm;
      return;
    end if;
    raise exception 'FAIL: % (expected %, got % %)', description, expected_state, sqlstate, sqlerrm;
  end;
  raise exception 'FAIL: % (expected %, statement succeeded)', description, expected_state;
end
$$;

grant execute on all functions in schema tests to anon, authenticated;
