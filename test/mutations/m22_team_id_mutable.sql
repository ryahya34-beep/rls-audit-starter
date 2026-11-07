-- teams id no longer frozen, so an admin can split a team's audit history
drop trigger teams_freeze_id on public.teams;
