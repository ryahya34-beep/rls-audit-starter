-- Nobody can raise their own role. Only admins change roles.
begin;
\ir fixture.sql

select tests.login(tests.id('member_a'));
select tests.ok(
  tests.affected($$update public.profiles set role = 'admin' where id = auth.uid()$$) = 0,
  'member_a''s attempt to make themselves admin changes 0 rows');
select tests.ok(
  tests.affected($$update public.profiles set display_name = 'Boss' where id = auth.uid()$$) = 0,
  'member_a cannot edit their own profile either (admin-managed in this starter)');
select tests.throws(
  $$insert into public.profiles (id, team_id, role, display_name) values (tests.id('member_b'), tests.id('team_a'), 'admin', 'Second me')$$,
  '42501', 'member_a cannot create an admin profile');

select tests.logout();
select tests.ok(
  (select role from public.profiles where id = tests.id('member_a')) = 'member',
  'member_a is still a member');

-- Positive control: an admin can change a role.
select tests.login(tests.id('admin_a'));
select tests.ok(
  tests.affected($$update public.profiles set role = 'viewer' where id = tests.id('member_a')$$) = 1,
  'admin_a can change member_a''s role');

rollback;
