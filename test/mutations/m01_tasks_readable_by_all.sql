-- tasks SELECT policy loosened to using (true)
drop policy tasks_select on public.tasks;
create policy tasks_select on public.tasks for select to authenticated using (true);
