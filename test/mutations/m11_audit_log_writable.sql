-- clients granted INSERT on audit_log with a permissive policy
grant insert on public.audit_log to authenticated;
create policy audit_log_insert on public.audit_log for insert to authenticated with check (true);
