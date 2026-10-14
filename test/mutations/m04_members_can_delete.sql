-- members allowed to delete tasks
drop policy tasks_delete on public.tasks;
create policy tasks_delete on public.tasks for delete to authenticated
  using (private.my_role() in ('admin', 'member') and team_id = private.my_team());
