-- FitTrack Pro: Supabase schema (matches docs/TRD.md and docs/SECURITY-AND-ACCESS.md)
-- Run in the Supabase SQL editor. Safe to run again: tables use IF NOT EXISTS
-- and policies are dropped before they are created.

create extension if not exists "pgcrypto";

-- ------------------------------------------------------------------ tables

create table if not exists public.users (
  id            uuid primary key references auth.users (id) on delete cascade,
  email         text not null unique,
  full_name     text,
  avatar_url    text,
  fitness_level text check (fitness_level in ('beginner', 'intermediate', 'advanced')),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table if not exists public.workouts (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.users (id) on delete cascade,
  type             text not null check (type in ('strength', 'cardio')),
  name             text not null,
  date             date not null,
  duration_minutes integer,
  calories_burned  integer,
  notes            text,
  created_at       timestamptz not null default now()
);
create index if not exists workouts_user_date_idx on public.workouts (user_id, date desc);

create table if not exists public.workout_exercises (
  id               uuid primary key default gen_random_uuid(),
  workout_id       uuid not null references public.workouts (id) on delete cascade,
  exercise_name    text not null,
  muscle_group     text,
  sets             integer,
  reps             integer,
  weight_kg        numeric,
  duration_seconds integer,
  order_index      integer
);
create index if not exists workout_exercises_workout_idx on public.workout_exercises (workout_id);

create table if not exists public.water_logs (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users (id) on delete cascade,
  amount_ml  integer not null check (amount_ml > 0),
  date       date not null,
  created_at timestamptz not null default now()
);
create index if not exists water_logs_user_date_idx on public.water_logs (user_id, date desc);

create table if not exists public.goals (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.users (id) on delete cascade,
  goal_type    text not null check (goal_type in ('workouts_per_week', 'water_daily', 'steps_daily')),
  target_value integer not null check (target_value > 0),
  period       text not null check (period in ('daily', 'weekly')),
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  unique (user_id, goal_type) -- lets the app upsert on (user_id, goal_type)
);

create table if not exists public.reminders (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.users (id) on delete cascade,
  reminder_type text not null check (reminder_type in ('workout', 'water', 'steps')),
  time          time not null,
  days_of_week  integer[] not null default '{0,1,2,3,4,5,6}',
  is_active     boolean not null default true,
  message       text
);

-- ------------------------------------------------- profile row on sign-up

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email, full_name, fitness_level)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    'beginner'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Only the trigger below runs this; nobody should call it through the API.
revoke execute on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ------------------------------------------------ row level security (RLS)

alter table public.users             enable row level security;
alter table public.workouts          enable row level security;
alter table public.workout_exercises enable row level security;
alter table public.water_logs        enable row level security;
alter table public.goals             enable row level security;
alter table public.reminders         enable row level security;

drop policy if exists "Users can view own profile" on public.users;
create policy "Users can view own profile"
  on public.users for select using (auth.uid() = id);
drop policy if exists "Users can update own profile" on public.users;
create policy "Users can update own profile"
  on public.users for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "Users can manage own workouts" on public.workouts;
create policy "Users can manage own workouts"
  on public.workouts for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can manage own workout exercises" on public.workout_exercises;
create policy "Users can manage own workout exercises"
  on public.workout_exercises for all
  using (exists (
    select 1 from public.workouts w
    where w.id = workout_exercises.workout_id and w.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.workouts w
    where w.id = workout_exercises.workout_id and w.user_id = auth.uid()
  ));

drop policy if exists "Users can manage own water logs" on public.water_logs;
create policy "Users can manage own water logs"
  on public.water_logs for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can manage own goals" on public.goals;
create policy "Users can manage own goals"
  on public.goals for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can manage own reminders" on public.reminders;
create policy "Users can manage own reminders"
  on public.reminders for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- =================================================================== v2
-- Added in session 3: exercise library, body measurements, steps, atomic
-- workout saves, avatar storage. Still safe to run again.

-- ------------------------------------------------------------- new tables

create table if not exists public.custom_exercises (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.users (id) on delete cascade,
  name         text not null check (char_length(name) between 1 and 80),
  muscle_group text not null default 'Full body',
  created_at   timestamptz not null default now()
);
create unique index if not exists custom_exercises_user_name_idx
  on public.custom_exercises (user_id, lower(name));

create table if not exists public.body_measurements (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.users (id) on delete cascade,
  date         date not null,
  weight_kg    numeric check (weight_kg > 0 and weight_kg < 700),
  body_fat_pct numeric check (body_fat_pct >= 0 and body_fat_pct <= 100),
  waist_cm     numeric check (waist_cm > 0 and waist_cm < 400),
  chest_cm     numeric check (chest_cm > 0 and chest_cm < 400),
  arm_cm       numeric check (arm_cm > 0 and arm_cm < 200),
  hips_cm      numeric check (hips_cm > 0 and hips_cm < 400),
  notes        text,
  created_at   timestamptz not null default now()
);
create index if not exists body_measurements_user_date_idx
  on public.body_measurements (user_id, date desc);

create table if not exists public.daily_steps (
  user_id    uuid not null references public.users (id) on delete cascade,
  date       date not null,
  steps      integer not null check (steps >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, date)
);

alter table public.custom_exercises  enable row level security;
alter table public.body_measurements enable row level security;
alter table public.daily_steps       enable row level security;

drop policy if exists "Users can manage own custom exercises" on public.custom_exercises;
create policy "Users can manage own custom exercises"
  on public.custom_exercises for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can manage own body measurements" on public.body_measurements;
create policy "Users can manage own body measurements"
  on public.body_measurements for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can manage own daily steps" on public.daily_steps;
create policy "Users can manage own daily steps"
  on public.daily_steps for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ------------------------------------------------------ atomic workout save
-- Inserts a workout (or updates it if the id exists) and replaces all of its
-- exercises in one transaction. The app generates the id, so a save retried
-- after a lost connection cannot create a duplicate. Runs with the caller's
-- rights, so the RLS policies above still apply.

create or replace function public.save_workout(p_workout jsonb, p_exercises jsonb)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id  uuid := (p_workout ->> 'id')::uuid;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;

  insert into public.workouts
    (id, user_id, type, name, date, duration_minutes, calories_burned, notes)
  values (
    v_id,
    v_uid,
    p_workout ->> 'type',
    p_workout ->> 'name',
    (p_workout ->> 'date')::date,
    (p_workout ->> 'duration_minutes')::integer,
    (p_workout ->> 'calories_burned')::integer,
    p_workout ->> 'notes'
  )
  on conflict (id) do update set
    type             = excluded.type,
    name             = excluded.name,
    date             = excluded.date,
    duration_minutes = excluded.duration_minutes,
    calories_burned  = excluded.calories_burned,
    notes            = excluded.notes
  where public.workouts.user_id = v_uid;

  if not found then
    raise exception 'Workout not found' using errcode = '42501';
  end if;

  delete from public.workout_exercises where workout_id = v_id;

  insert into public.workout_exercises
    (workout_id, exercise_name, muscle_group, sets, reps, weight_kg,
     duration_seconds, order_index)
  select v_id, e.exercise_name, e.muscle_group, e.sets, e.reps, e.weight_kg,
         e.duration_seconds, e.order_index
  from jsonb_to_recordset(coalesce(p_exercises, '[]'::jsonb)) as e (
    exercise_name text,
    muscle_group text,
    sets integer,
    reps integer,
    weight_kg numeric,
    duration_seconds integer,
    order_index integer
  );

  return v_id;
end;
$$;

revoke execute on function public.save_workout(jsonb, jsonb) from public, anon;
grant execute on function public.save_workout(jsonb, jsonb) to authenticated;

-- ------------------------------------------------------------ avatar files
-- Public bucket: anyone with the link can view an avatar, only the owner can
-- write. Files live at avatars/<user id>/avatar.jpg (or .png), max 5 MB.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 5242880, array['image/jpeg', 'image/png'])
on conflict (id) do update set
  public             = excluded.public,
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Avatar owners can read" on storage.objects;
create policy "Avatar owners can read"
  on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Avatar owners can upload" on storage.objects;
create policy "Avatar owners can upload"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Avatar owners can replace" on storage.objects;
create policy "Avatar owners can replace"
  on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Avatar owners can delete" on storage.objects;
create policy "Avatar owners can delete"
  on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
