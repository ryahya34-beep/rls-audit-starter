-- tasks INSERT/UPDATE check team only, forgetting the role
drop policy tasks_insert on public.tasks;
drop policy tasks_update on public.tasks;
create policy tasks_insert on public.tasks for insert to authenticated
  with check (private.my_role() = 'admin' or team_id = private.my_team());
create policy tasks_update on public.tasks for update to authenticated
  using (private.my_role() = 'admin' or team_id = private.my_team())
  with check (private.my_role() = 'admin' or team_id = private.my_team());
