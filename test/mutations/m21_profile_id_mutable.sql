-- profiles id no longer frozen, so an admin can split a profile's audit history
drop trigger profiles_freeze_id on public.profiles;
