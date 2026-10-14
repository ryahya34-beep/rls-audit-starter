-- admins granted DELETE on audit_log ("just for cleanup")
grant delete on public.audit_log to authenticated;
create policy audit_log_delete on public.audit_log for delete to authenticated
  using (private.my_role() = 'admin');
