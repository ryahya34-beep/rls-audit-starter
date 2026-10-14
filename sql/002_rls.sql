-- Who may do what, enforced by Postgres itself.
--
-- Two layers, both required on Supabase:
--   1. GRANTs decide which roles can reach a table through the Data API at all.
--   2. Row Level Security decides which rows those roles can see or change.
-- A grant without RLS exposes every row. RLS without a grant returns 42501.

-------------------------------------------------------------------------------
-- Helper functions
-------------------------------------------------------------------------------

-- Kept out of `public` so the Data API does not expose them as RPC endpoints.
create schema private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

-- SECURITY DEFINER so they read profiles as the table owner, bypassing RLS.
-- This is what keeps the profiles policies from recursing: a policy on
-- profiles that queried profiles directly would re-enter its own policy and
-- Postgres would stop with "infinite recursion detected in policy".
-- test/09_policy_recursion.sql and mutation m09 guard this.
--
-- search_path is pinned to '' so a caller cannot shadow `profiles` or any
-- operator with an object of their own; every name below is schema-qualified.
create function private.my_role() returns text
language sql stable security definer
set search_path = ''
as $$
  select role from public.profiles where id = auth.uid()
$$;

create function private.my_team() returns uuid
language sql stable security definer
set search_path = ''
as $$
  select team_id from public.profiles where id = auth.uid()
$$;

-- Postgres grants EXECUTE on new functions to PUBLIC, so revoke it explicitly.
revoke execute on function private.my_role(), private.my_team() from public, anon;
grant execute on function private.my_role(), private.my_team() to authenticated;

-------------------------------------------------------------------------------
-- Grants
-------------------------------------------------------------------------------

-- anon gets nothing: this app has no public data.
grant select, insert, update, delete on public.teams, public.profiles, public.tasks
  to authenticated, service_role;

-- The audit log is read-only for everyone who talks to the API, service_role
-- included. Only the audit trigger (running as the owner) writes to it.
grant select on public.audit_log to authenticated, service_role;

-------------------------------------------------------------------------------
-- Row Level Security
-------------------------------------------------------------------------------

alter table public.teams     enable row level security;
alter table public.profiles  enable row level security;
alter table public.tasks     enable row level security;
alter table public.audit_log enable row level security;

-- teams: everyone sees their own team, admins see all, only admins change them.
create policy teams_select on public.teams
  for select to authenticated
  using (private.my_role() = 'admin' or id = private.my_team());

create policy teams_insert on public.teams
  for insert to authenticated
  with check (private.my_role() = 'admin');

create policy teams_update on public.teams
  for update to authenticated
  using (private.my_role() = 'admin')
  with check (private.my_role() = 'admin');

create policy teams_delete on public.teams
  for delete to authenticated
  using (private.my_role() = 'admin');

-- profiles: you see yourself and your teammates, admins see everyone.
-- Only admins create profiles or change roles, so nobody can promote
-- themselves. Every change is written to the audit log.
create policy profiles_select on public.profiles
  for select to authenticated
  using (
    id = auth.uid()
    or team_id = private.my_team()
    or private.my_role() = 'admin'
  );

create policy profiles_insert on public.profiles
  for insert to authenticated
  with check (private.my_role() = 'admin');

create policy profiles_update on public.profiles
  for update to authenticated
  using (private.my_role() = 'admin')
  with check (private.my_role() = 'admin');

create policy profiles_delete on public.profiles
  for delete to authenticated
  using (private.my_role() = 'admin');

-- tasks: members and viewers read their own team; members write their own
-- team; admins do anything. Only admins delete.
create policy tasks_select on public.tasks
  for select to authenticated
  using (private.my_role() = 'admin' or team_id = private.my_team());

create policy tasks_insert on public.tasks
  for insert to authenticated
  with check (
    private.my_role() = 'admin'
    or (private.my_role() = 'member' and team_id = private.my_team())
  );

-- USING picks the rows a member may touch; WITH CHECK validates the row after
-- the change, which is what stops a member moving a task into another team.
-- Do not rely on the SELECT policy for this: Postgres applies it to the new
-- row only when the UPDATE reads a column (e.g. has a WHERE). A bare
-- `update tasks set team_id = ...` is stopped by WITH CHECK alone.
-- test/03_no_cross_team_writes.sql and mutation m03 cover both shapes.
create policy tasks_update on public.tasks
  for update to authenticated
  using (
    private.my_role() = 'admin'
    or (private.my_role() = 'member' and team_id = private.my_team())
  )
  with check (
    private.my_role() = 'admin'
    or (private.my_role() = 'member' and team_id = private.my_team())
  );

create policy tasks_delete on public.tasks
  for delete to authenticated
  using (private.my_role() = 'admin');

-- audit_log: admins read it. There are deliberately no insert, update or
-- delete policies, and no grants for those commands either.
create policy audit_log_select on public.audit_log
  for select to authenticated
  using (private.my_role() = 'admin');
