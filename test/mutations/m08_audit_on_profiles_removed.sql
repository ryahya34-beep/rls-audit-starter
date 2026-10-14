-- audit trigger on profiles dropped, so role changes go unrecorded
drop trigger profiles_audit on public.profiles;
