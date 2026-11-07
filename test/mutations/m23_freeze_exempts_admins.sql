-- id freeze applies to members only, admins may still change ids
create or replace function private.freeze_id() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id is distinct from old.id and private.my_role() is distinct from 'admin' then
    raise exception 'the id of a % row cannot be changed', tg_table_name using errcode = '42501';
  end if;
  return new;
end
$$;
