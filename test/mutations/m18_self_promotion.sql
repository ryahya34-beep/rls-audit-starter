-- profiles UPDATE lets users edit their own row, including role
drop policy profiles_update on public.profiles;
create policy profiles_update on public.profiles for update to authenticated
  using (private.my_role() = 'admin' or id = auth.uid())
  with check (private.my_role() = 'admin' or id = auth.uid());
