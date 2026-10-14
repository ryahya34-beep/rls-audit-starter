-- tasks UPDATE policy without a real WITH CHECK, so tasks can change team
drop policy tasks_update on public.tasks;
create policy tasks_update on public.tasks for update to authenticated
  using (private.my_role() = 'admin' or (private.my_role() = 'member' and team_id = private.my_team()))
  with check (true);
