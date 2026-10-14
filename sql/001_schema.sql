-- Tables for a small team task tracker.
--
-- One organisation, several teams. Every person belongs to exactly one team
-- and has one role: admin (whole organisation), member (read and write their
-- own team's tasks) or viewer (read their own team's tasks).

create table public.teams (
  id   uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0)
);

create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  team_id      uuid not null references public.teams (id),
  role         text not null check (role in ('admin', 'member', 'viewer')),
  display_name text not null check (length(trim(display_name)) > 0)
);

create index profiles_team_id_idx on public.profiles (team_id);

create table public.tasks (
  id         uuid primary key default gen_random_uuid(),
  team_id    uuid not null references public.teams (id),
  title      text not null check (length(trim(title)) between 1 and 200),
  status     text not null default 'todo' check (status in ('todo', 'doing', 'done')),
  -- Set by the tasks_stamp trigger from the caller's JWT. Whatever the client
  -- sends for this column is overwritten.
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index tasks_team_id_idx on public.tasks (team_id);

-- Append-only history of every write to tasks and profiles. Rows are written
-- by a trigger (sql/003_audit.sql), never by clients.
create table public.audit_log (
  id         bigint generated always as identity primary key,
  table_name text not null,
  record_id  uuid,
  action     text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  actor      uuid,
  old_data   jsonb,
  new_data   jsonb,
  at         timestamptz not null default now()
);

create index audit_log_record_idx on public.audit_log (table_name, record_id);
