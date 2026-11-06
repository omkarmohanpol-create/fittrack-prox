-- Behaviour tests for supabase/schema.sql on plain PostgreSQL.
-- Run with supabase/tests/run.sh. Every check raises an exception on failure.

\set ON_ERROR_STOP 1
set client_min_messages = warning;

-- Two users. The signup trigger must create their profile rows.
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-4111-8111-111111111111', 'a@example.com', '{"full_name":"Alice"}'),
  ('22222222-2222-4222-8222-222222222222', 'b@example.com', '{}');

do $$ begin
  assert (select full_name from public.users where email = 'a@example.com') = 'Alice',
    'signup trigger did not copy full_name';
  assert (select count(*) from public.users) = 2, 'signup trigger did not create profiles';
end $$;

-- ----------------------------------------------------------- as user A
set role authenticated;
set request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';

select public.save_workout(
  '{"id":"aaaaaaaa-0000-4000-8000-000000000001","type":"strength","name":"Push day",
    "date":"2026-11-05","duration_minutes":45,"calories_burned":300,"notes":null}',
  '[{"exercise_name":"Bench press","muscle_group":"Chest","sets":3,"reps":5,"weight_kg":80,"duration_seconds":0,"order_index":0},
    {"exercise_name":"Dip","muscle_group":"Chest","sets":3,"reps":10,"weight_kg":0,"duration_seconds":0,"order_index":1}]'
);

do $$ begin
  assert (select count(*) from public.workout_exercises) = 2, 'insert: expected 2 exercises';
  assert (select user_id from public.workouts) = '11111111-1111-4111-8111-111111111111',
    'insert: user_id must come from auth.uid()';
end $$;

-- Retrying the same save (lost connection) must not duplicate anything.
select public.save_workout(
  '{"id":"aaaaaaaa-0000-4000-8000-000000000001","type":"strength","name":"Push day",
    "date":"2026-11-05","duration_minutes":45,"calories_burned":300,"notes":null}',
  '[{"exercise_name":"Bench press","muscle_group":"Chest","sets":3,"reps":5,"weight_kg":80,"duration_seconds":0,"order_index":0},
    {"exercise_name":"Dip","muscle_group":"Chest","sets":3,"reps":10,"weight_kg":0,"duration_seconds":0,"order_index":1}]'
);
do $$ begin
  assert (select count(*) from public.workouts) = 1, 'retry created a second workout';
  assert (select count(*) from public.workout_exercises) = 2, 'retry duplicated exercises';
end $$;

-- Editing: new name and date, exercises replaced, null minutes allowed.
select public.save_workout(
  '{"id":"aaaaaaaa-0000-4000-8000-000000000001","type":"strength","name":"Chest day",
    "date":"2026-11-03","duration_minutes":null,"calories_burned":0,"notes":"felt strong"}',
  '[{"exercise_name":"Incline bench press","muscle_group":"Chest","sets":4,"reps":8,"weight_kg":60.5,"duration_seconds":0,"order_index":0}]'
);
do $$ begin
  assert (select name from public.workouts) = 'Chest day', 'edit: name not updated';
  assert (select date from public.workouts) = '2026-11-03', 'edit: date not updated';
  assert (select duration_minutes from public.workouts) is null, 'edit: null minutes';
  assert (select count(*) from public.workout_exercises) = 1, 'edit: exercises not replaced';
  assert (select weight_kg from public.workout_exercises) = 60.5, 'edit: decimal weight';
end $$;

-- Custom exercise names are unique per user, ignoring case.
insert into public.custom_exercises (user_id, name, muscle_group)
  values (auth.uid(), 'Landmine press', 'Shoulders');
do $$ begin
  begin
    insert into public.custom_exercises (user_id, name, muscle_group)
      values (auth.uid(), 'LANDMINE PRESS', 'Shoulders');
    raise exception 'duplicate custom exercise was accepted';
  exception when unique_violation then null;
  end;
end $$;

-- Steps upsert on (user_id, date).
insert into public.daily_steps (user_id, date, steps) values (auth.uid(), '2026-11-05', 4000)
  on conflict (user_id, date) do update set steps = excluded.steps;
insert into public.daily_steps (user_id, date, steps) values (auth.uid(), '2026-11-05', 6500)
  on conflict (user_id, date) do update set steps = excluded.steps;
do $$ begin
  assert (select steps from public.daily_steps) = 6500, 'steps upsert';
end $$;

-- Measurements: range checks.
insert into public.body_measurements (user_id, date, weight_kg, body_fat_pct)
  values (auth.uid(), '2026-11-05', 80.4, 18);
do $$ begin
  begin
    insert into public.body_measurements (user_id, date, body_fat_pct)
      values (auth.uid(), '2026-11-05', 140);
    raise exception 'body fat over 100%% was accepted';
  exception when check_violation then null;
  end;
end $$;

-- Water: a retried insert with the same id is ignored.
insert into public.water_logs (id, user_id, amount_ml, date)
  values ('cccccccc-0000-4000-8000-000000000001', auth.uid(), 250, '2026-11-05')
  on conflict (id) do nothing;
insert into public.water_logs (id, user_id, amount_ml, date)
  values ('cccccccc-0000-4000-8000-000000000001', auth.uid(), 250, '2026-11-05')
  on conflict (id) do nothing;
do $$ begin
  assert (select count(*) from public.water_logs) = 1, 'water retry duplicated';
end $$;

-- Avatar storage: own folder only.
insert into storage.objects (bucket_id, name)
  values ('avatars', '11111111-1111-4111-8111-111111111111/avatar.jpg');
do $$ begin
  begin
    insert into storage.objects (bucket_id, name)
      values ('avatars', '22222222-2222-4222-8222-222222222222/avatar.jpg');
    raise exception 'user A wrote into user B''s avatar folder';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ----------------------------------------------------------- as user B
set request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';

do $$ begin
  assert (select count(*) from public.workouts) = 0, 'B can see A''s workouts';
  assert (select count(*) from public.workout_exercises) = 0, 'B can see A''s exercises';
  assert (select count(*) from public.daily_steps) = 0, 'B can see A''s steps';
  assert (select count(*) from public.body_measurements) = 0, 'B can see A''s measurements';
  assert (select count(*) from public.users) = 1, 'B can see other profiles';
  assert (select count(*) from storage.objects) = 0, 'B can list A''s avatar files';
end $$;

-- B must not be able to overwrite A's workout through save_workout.
do $$ begin
  begin
    perform public.save_workout(
      '{"id":"aaaaaaaa-0000-4000-8000-000000000001","type":"cardio","name":"Hijack",
        "date":"2026-11-05","duration_minutes":1,"calories_burned":1,"notes":null}', '[]');
    raise exception 'B overwrote A''s workout';
  exception when insufficient_privilege then null;
  end;
end $$;

-- B cannot delete A's rows either (RLS hides them, so nothing is deleted).
delete from public.workouts;

-- ---------------------------------------------------- not signed in (anon)
reset role;
set role anon;
reset request.jwt.claim.sub;
do $$ begin
  begin
    perform public.save_workout('{"id":"aaaaaaaa-0000-4000-8000-000000000002"}', '[]');
    raise exception 'anon could call save_workout';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ------------------------------------------------------------- as admin
reset role;
do $$ begin
  assert (select name from public.workouts) = 'Chest day', 'A''s workout was changed by B';
end $$;

-- Deleting the auth user (what the delete-account function does) removes
-- every row the user owned.
delete from auth.users where id = '11111111-1111-4111-8111-111111111111';
do $$ begin
  assert (select count(*) from public.users where email = 'a@example.com') = 0, 'profile left';
  assert (select count(*) from public.workouts) = 0, 'workouts left';
  assert (select count(*) from public.workout_exercises) = 0, 'exercises left';
  assert (select count(*) from public.water_logs) = 0, 'water left';
  assert (select count(*) from public.daily_steps) = 0, 'steps left';
  assert (select count(*) from public.body_measurements) = 0, 'measurements left';
  assert (select count(*) from public.custom_exercises) = 0, 'custom exercises left';
end $$;

\echo 'schema_test: all checks passed'
