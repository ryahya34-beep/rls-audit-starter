-- tasks id no longer frozen, so a member can split a task's audit history
drop trigger tasks_freeze_id on public.tasks;
