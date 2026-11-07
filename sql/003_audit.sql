-- Who did what, recorded so that it cannot be skipped or forged from a client.
--
-- The record is written by triggers, not by application code. A client that
-- talks to the Data API directly, bypassing the app, still fires the trigger.
-- The actor comes from auth.uid() (the verified JWT), never from the request
-- body.

-------------------------------------------------------------------------------
-- Stamp tasks with their author
-------------------------------------------------------------------------------

-- Overwrites created_by/created_at on insert and freezes them on update, so a
-- client cannot claim a task was written by someone else.
create function private.stamp_task() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.created_by := auth.uid();
    new.created_at := now();
  else
    new.created_by := old.created_by;
    new.created_at := old.created_at;
  end if;
  new.updated_at := now();
  return new;
end
$$;

revoke execute on function private.stamp_task() from public, anon, authenticated;

create trigger tasks_stamp
  before insert or update on public.tasks
  for each row execute function private.stamp_task();

-------------------------------------------------------------------------------
-- Audit trail
-------------------------------------------------------------------------------

-- SECURITY DEFINER because the callers (members, admins) have no INSERT
-- privilege on audit_log; the function inserts as the table owner.
-- search_path is pinned for the same reason as in 002_rls.sql.
create function private.audit_row() returns trigger
language plpgsql security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.audit_log (table_name, record_id, action, actor, new_data)
    values (tg_table_name, new.id, tg_op, auth.uid(), to_jsonb(new));
  elsif tg_op = 'UPDATE' then
    insert into public.audit_log (table_name, record_id, action, actor, old_data, new_data)
    values (tg_table_name, new.id, tg_op, auth.uid(), to_jsonb(old), to_jsonb(new));
  else
    insert into public.audit_log (table_name, record_id, action, actor, old_data)
    values (tg_table_name, old.id, tg_op, auth.uid(), to_jsonb(old));
  end if;
  return null;
end
$$;

-- A trigger function cannot be called directly today. Revoking anyway means a
-- future refactor into a regular function does not quietly hand every user a
-- way to write arbitrary audit rows.
revoke execute on function private.audit_row() from public, anon, authenticated;

create trigger tasks_audit
  after insert or update or delete on public.tasks
  for each row execute function private.audit_row();

create trigger profiles_audit
  after insert or update or delete on public.profiles
  for each row execute function private.audit_row();

-- audit_row() is generic: it needs only a uuid `id` column, which teams has.
create trigger teams_audit
  after insert or update or delete on public.teams
  for each row execute function private.audit_row();

-------------------------------------------------------------------------------
-- Ids never change
-------------------------------------------------------------------------------

-- The audit log files each row's history under record_id = id. An UPDATE that
-- changes id would split that history: the old entries point at an id that no
-- longer exists and the row carries on under a new one with no past. RLS
-- cannot stop it (a member may update their own team's tasks, every column
-- included), so this trigger refuses it for everyone, admins included.
--
-- A trigger rather than column-level grants: PostgREST upserts send
-- `set id = excluded.id`, which a column grant would reject even though the id
-- does not change. Here only a different value is refused.
-- test/12_record_ids_frozen.sql and mutations m20 to m23 guard this.
create function private.freeze_id() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id is distinct from old.id then
    raise exception 'the id of a % row cannot be changed', tg_table_name
      using errcode = '42501',
            hint = 'The audit log files history under the id. Insert a new row instead.';
  end if;
  return new;
end
$$;

revoke execute on function private.freeze_id() from public, anon, authenticated;

create trigger tasks_freeze_id
  before update of id on public.tasks
  for each row execute function private.freeze_id();

create trigger profiles_freeze_id
  before update of id on public.profiles
  for each row execute function private.freeze_id();

create trigger teams_freeze_id
  before update of id on public.teams
  for each row execute function private.freeze_id();
