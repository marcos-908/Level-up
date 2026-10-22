-- LEVEL UP Progress Hub: migração aditiva/idempotente. Não remove tabelas nem dados existentes.
-- Execute depois das migrações anteriores no SQL Editor do projeto correto.
create table if not exists public.lu_projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 100),
  description text not null default '',
  technologies text[] not null default '{}',
  status text not null default 'active' check (status in ('active','paused','completed','archived')),
  progress_manual integer not null default 0 check (progress_manual between 0 and 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(user_id,id)
);
create table if not exists public.lu_activity_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  area text not null check (area in ('english','coding','other')),
  duration_minutes integer not null check (duration_minutes between 1 and 1440),
  studied_on date not null default current_date,
  content text not null default '',
  category text not null default '',
  vocabulary_count integer not null default 0 check (vocabulary_count between 0 and 10000),
  lessons_count integer not null default 0 check (lessons_count between 0 and 10000),
  project_id uuid,
  created_at timestamptz not null default now(),
  constraint lu_activity_project_owner_fk foreign key(user_id,project_id) references public.lu_projects(user_id,id) on delete set null (project_id)
);
create table if not exists public.lu_exercises (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 100),
  category text not null default 'Outro',
  description text not null default '',
  weekly_target integer not null default 3 check (weekly_target between 1 and 14),
  unit text not null default 'minutes' check (unit in ('minutes','reps','sets','sessions')),
  created_at timestamptz not null default now(),
  unique(user_id,id)
);
create table if not exists public.lu_exercise_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  exercise_id uuid not null,
  performed_on date not null default current_date,
  duration_minutes integer not null default 0 check (duration_minutes between 0 and 1440),
  sets integer not null default 0 check (sets between 0 and 10000),
  repetitions integer not null default 0 check (repetitions between 0 and 100000),
  notes text not null default '',
  created_at timestamptz not null default now(),
  constraint lu_exercise_log_owner_fk foreign key(user_id,exercise_id) references public.lu_exercises(user_id,id) on delete cascade
);
create table if not exists public.lu_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 160),
  area text not null check (area in ('english','coding','exercise','tasks','personal')),
  target_value integer not null check (target_value between 1 and 100000000),
  current_value integer not null default 0 check (current_value between 0 and 100000000),
  unit text not null default 'unidades',
  due_date date,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists lu_projects_user_created_idx on public.lu_projects(user_id,created_at desc);
create index if not exists lu_sessions_user_date_idx on public.lu_activity_sessions(user_id,studied_on desc);
create index if not exists lu_sessions_user_area_date_idx on public.lu_activity_sessions(user_id,area,studied_on desc);
create index if not exists lu_exercises_user_created_idx on public.lu_exercises(user_id,created_at desc);
create index if not exists lu_exercise_logs_user_date_idx on public.lu_exercise_logs(user_id,performed_on desc);
create index if not exists lu_goals_user_created_idx on public.lu_goals(user_id,created_at desc);

alter table public.lu_projects enable row level security;
alter table public.lu_activity_sessions enable row level security;
alter table public.lu_exercises enable row level security;
alter table public.lu_exercise_logs enable row level security;
alter table public.lu_goals enable row level security;

do $$ declare t text; begin
  foreach t in array array['lu_projects','lu_activity_sessions','lu_exercises','lu_exercise_logs','lu_goals'] loop
    execute format('drop policy if exists %I on public.%I',t||'_own_select',t);
    execute format('create policy %I on public.%I for select to authenticated using (auth.uid() = user_id)',t||'_own_select',t);
    execute format('drop policy if exists %I on public.%I',t||'_own_insert',t);
    execute format('create policy %I on public.%I for insert to authenticated with check (auth.uid() = user_id)',t||'_own_insert',t);
    execute format('drop policy if exists %I on public.%I',t||'_own_update',t);
    execute format('create policy %I on public.%I for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id)',t||'_own_update',t);
    execute format('drop policy if exists %I on public.%I',t||'_own_delete',t);
    execute format('create policy %I on public.%I for delete to authenticated using (auth.uid() = user_id)',t||'_own_delete',t);
  end loop;
end $$;

grant select,insert,update,delete on public.lu_projects to authenticated;
grant select,insert,update,delete on public.lu_activity_sessions to authenticated;
grant select,insert,update,delete on public.lu_exercises to authenticated;
grant select,insert,update,delete on public.lu_exercise_logs to authenticated;
grant select,insert,update,delete on public.lu_goals to authenticated;

-- Mantém as configurações no JSON preferences já existente em lu_profiles; sem coluna nova.

-- Hábitos/rotina e check-ins diários idempotentes por hábito.
create table if not exists public.lu_habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 100),
  target_per_week integer not null default 3 check (target_per_week between 1 and 7),
  frequency_days smallint[] not null default array[1,2,3,4,5]::smallint[],
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(user_id,id),
  check (cardinality(frequency_days) between 1 and 7),
  check (frequency_days <@ array[0,1,2,3,4,5,6]::smallint[])
);
create table if not exists public.lu_habit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  habit_id uuid not null,
  completed_on date not null default current_date,
  notes text not null default '',
  created_at timestamptz not null default now(),
  unique(habit_id,completed_on),
  constraint lu_habit_log_owner_fk foreign key(user_id,habit_id) references public.lu_habits(user_id,id) on delete cascade
);
create index if not exists lu_habits_user_created_idx on public.lu_habits(user_id,created_at desc);
create index if not exists lu_habit_logs_user_date_idx on public.lu_habit_logs(user_id,completed_on desc);
alter table public.lu_habits enable row level security;
alter table public.lu_habit_logs enable row level security;
drop policy if exists lu_habits_own_select on public.lu_habits;
create policy lu_habits_own_select on public.lu_habits for select to authenticated using (auth.uid()=user_id);
drop policy if exists lu_habits_own_insert on public.lu_habits;
create policy lu_habits_own_insert on public.lu_habits for insert to authenticated with check (auth.uid()=user_id);
drop policy if exists lu_habits_own_update on public.lu_habits;
create policy lu_habits_own_update on public.lu_habits for update to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id);
drop policy if exists lu_habits_own_delete on public.lu_habits;
create policy lu_habits_own_delete on public.lu_habits for delete to authenticated using (auth.uid()=user_id);
drop policy if exists lu_habit_logs_own_select on public.lu_habit_logs;
create policy lu_habit_logs_own_select on public.lu_habit_logs for select to authenticated using (auth.uid()=user_id);
drop policy if exists lu_habit_logs_own_insert on public.lu_habit_logs;
create policy lu_habit_logs_own_insert on public.lu_habit_logs for insert to authenticated with check (auth.uid()=user_id);
drop policy if exists lu_habit_logs_own_update on public.lu_habit_logs;
create policy lu_habit_logs_own_update on public.lu_habit_logs for update to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id);
drop policy if exists lu_habit_logs_own_delete on public.lu_habit_logs;
create policy lu_habit_logs_own_delete on public.lu_habit_logs for delete to authenticated using (auth.uid()=user_id);
grant select,insert,update,delete on public.lu_habits to authenticated;
grant select,insert,update,delete on public.lu_habit_logs to authenticated;
