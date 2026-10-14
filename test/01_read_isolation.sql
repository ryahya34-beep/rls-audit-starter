-- Each person sees only their own team's data; admins see everything.
begin;
\ir fixture.sql

select tests.login(tests.id('member_a'));
select tests.ok((select count(*) from public.tasks) = 2, 'member_a sees the 2 tasks of team A');
select tests.ok((select count(*) from public.tasks where team_id = tests.id('team_b')) = 0, 'member_a sees 0 tasks of team B');
select tests.ok((select count(*) from public.teams) = 1, 'member_a sees only their own team');
select tests.ok((select count(*) from public.profiles) = 3, 'member_a sees the 3 profiles of team A');
select tests.ok(not exists (select 1 from public.profiles where id = tests.id('member_b')), 'member_a cannot see member_b''s profile');

select tests.login(tests.id('viewer_a'));
select tests.ok((select count(*) from public.tasks) = 2, 'viewer_a sees the 2 tasks of team A');

select tests.login(tests.id('member_b'));
select tests.ok((select count(*) from public.tasks) = 1, 'member_b sees the 1 task of team B');
select tests.ok((select count(*) from public.tasks where team_id = tests.id('team_a')) = 0, 'member_b sees 0 tasks of team A');

-- Positive control: the rows exist, so the zeros above mean "hidden", not "missing".
select tests.login(tests.id('admin_a'));
select tests.ok((select count(*) from public.tasks) = 3, 'admin_a sees all 3 tasks');
select tests.ok((select count(*) from public.profiles) = 4, 'admin_a sees all 4 profiles');

rollback;
