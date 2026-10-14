-- Minimal stand-in for the parts of Supabase this starter relies on.
--
-- Load this ONLY on plain Postgres (local runs and CI). A Supabase project
-- already has these roles, the auth schema and auth.uid(); running this file
-- there is unnecessary.
--
-- Deliberately NOT emulated: the old Supabase default privileges that granted
-- every new public table to anon/authenticated. Projects created after
-- 30 May 2026 start without them (existing projects follow on 30 Oct 2026),
-- so sql/ grants every table explicitly instead of relying on defaults.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
end
$$;

create schema if not exists auth;
grant usage on schema auth to anon, authenticated, service_role;
grant usage on schema public to anon, authenticated, service_role;

create table if not exists auth.users (
  id uuid primary key,
  email text
);

-- Supabase reads the caller's id from the verified JWT that PostgREST puts in
-- the request.jwt.claims setting. Tests set that setting directly.
create or replace function auth.uid() returns uuid
language sql stable
as $$
  select nullif(
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub',
    ''
  )::uuid
$$;
