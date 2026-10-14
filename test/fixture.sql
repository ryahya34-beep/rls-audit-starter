-- Shared test data. Included at the start of every test, inside its
-- transaction, so each test starts from the same state and leaves nothing.
--
--   team A: admin_a (admin), member_a (member), viewer_a (viewer)
--           tasks task_a1, task_a2
--   team B: member_b (member)
--           task task_b1

insert into auth.users (id, email) values
  (tests.id('admin_a'),  'admin_a@example.test'),
  (tests.id('member_a'), 'member_a@example.test'),
  (tests.id('viewer_a'), 'viewer_a@example.test'),
  (tests.id('member_b'), 'member_b@example.test');

insert into public.teams (id, name) values
  (tests.id('team_a'), 'Team A'),
  (tests.id('team_b'), 'Team B');

insert into public.profiles (id, team_id, role, display_name) values
  (tests.id('admin_a'),  tests.id('team_a'), 'admin',  'Admin A'),
  (tests.id('member_a'), tests.id('team_a'), 'member', 'Member A'),
  (tests.id('viewer_a'), tests.id('team_a'), 'viewer', 'Viewer A'),
  (tests.id('member_b'), tests.id('team_b'), 'member', 'Member B');

insert into public.tasks (id, team_id, title) values
  (tests.id('task_a1'), tests.id('team_a'), 'Write the onboarding guide'),
  (tests.id('task_a2'), tests.id('team_a'), 'Review the Q3 budget'),
  (tests.id('task_b1'), tests.id('team_b'), 'Plan the offsite');
