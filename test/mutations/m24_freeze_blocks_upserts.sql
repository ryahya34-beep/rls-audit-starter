-- id freeze rejects any UPDATE naming id, even to the same value (breaks upserts)
create or replace function private.freeze_id() returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'the id of a % row cannot be changed', tg_table_name using errcode = '42501';
end
$$;
