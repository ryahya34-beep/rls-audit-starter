-- audit_log SELECT policy opened to every signed-in user
drop policy audit_log_select on public.audit_log;
create policy audit_log_select on public.audit_log for select to authenticated using (true);
