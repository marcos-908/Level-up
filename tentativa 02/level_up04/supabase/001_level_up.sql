-- LEVEL UP schema v1 — aditivo: não remove nem altera tabelas preexistentes.
create extension if not exists pgcrypto;

create table if not exists public.lu_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  player_name text not null default 'Jogador' check (char_length(player_name) between 1 and 32),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.lu_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 140),
  description text not null default '',
  category text not null default 'general',
  priority text not null default 'medium' check (priority in ('low','medium','high')),
  due_at timestamptz,
  estimated_minutes integer check (estimated_minutes is null or estimated_minutes between 1 and 1440),
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists lu_tasks_user_due_idx on public.lu_tasks(user_id,due_at);
create table if not exists public.lu_xp_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  source_type text not null,
  source_id uuid not null,
  amount integer not null check (amount between 1 and 500),
  reason text not null,
  created_at timestamptz not null default now(),
  unique(user_id,source_type,source_id)
);
create table if not exists public.lu_activity_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_type text not null,
  title text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create table if not exists public.lu_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  category text not null default 'general',
  starts_at timestamptz not null,
  ends_at timestamptz,
  notes text not null default '',
  completed_at timestamptz,
  created_at timestamptz not null default now()
);
create table if not exists public.lu_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  settings jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
create table if not exists public.lu_habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  frequency text not null default 'daily' check (frequency in ('daily','weekly','custom')),
  days integer[] not null default '{0,1,2,3,4,5,6}',
  archived boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.lu_habit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  habit_id uuid not null references public.lu_habits(id) on delete cascade,
  log_date date not null default current_date,
  created_at timestamptz not null default now(),
  unique(user_id,habit_id,log_date)
);
create table if not exists public.lu_workouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  modality text not null,
  duration_minutes integer not null check (duration_minutes between 1 and 600),
  notes text not null default '',
  activity_date date not null default current_date,
  created_at timestamptz not null default now()
);
create table if not exists public.lu_study_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject text not null,
  duration_minutes integer not null check (duration_minutes between 1 and 1440),
  learned text not null default '',
  difficulty text not null default '',
  created_at timestamptz not null default now()
);
create table if not exists public.lu_english_results (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  lesson_key text not null,
  correct boolean not null,
  answer text not null,
  created_at timestamptz not null default now()
);
create table if not exists public.lu_vocabulary (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  word text not null,
  meaning text not null,
  next_review date,
  created_at timestamptz not null default now(),
  unique(user_id,word)
);
create table if not exists public.lu_achievements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_key text not null,
  title text not null,
  unlocked_at timestamptz not null default now(),
  unique(user_id,achievement_key)
);

-- RLS em todas as tabelas do aplicativo
do $$ declare t text; begin
  foreach t in array array['lu_profiles','lu_tasks','lu_xp_events','lu_activity_logs','lu_events','lu_settings','lu_habits','lu_habit_logs','lu_workouts','lu_study_sessions','lu_english_results','lu_vocabulary','lu_achievements'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('drop policy if exists %I on public.%I',t||'_own_select',t);
    execute format('create policy %I on public.%I for select to authenticated using (user_id = (select auth.uid()))',t||'_own_select',t);
  end loop;
end $$;

drop policy if exists lu_profiles_own_insert on public.lu_profiles;
create policy lu_profiles_own_insert on public.lu_profiles for insert to authenticated with check(user_id=(select auth.uid()));
drop policy if exists lu_profiles_own_update on public.lu_profiles;
create policy lu_profiles_own_update on public.lu_profiles for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
drop policy if exists lu_tasks_own_insert on public.lu_tasks;
create policy lu_tasks_own_insert on public.lu_tasks for insert to authenticated with check(user_id=(select auth.uid()));
drop policy if exists lu_tasks_own_update on public.lu_tasks;
create policy lu_tasks_own_update on public.lu_tasks for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
drop policy if exists lu_tasks_own_delete on public.lu_tasks;
create policy lu_tasks_own_delete on public.lu_tasks for delete to authenticated using(user_id=(select auth.uid()));
drop policy if exists lu_events_own_write on public.lu_events;
create policy lu_events_own_write on public.lu_events for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
drop policy if exists lu_settings_own_write on public.lu_settings;
create policy lu_settings_own_write on public.lu_settings for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
drop policy if exists lu_habits_own_write on public.lu_habits;
create policy lu_habits_own_write on public.lu_habits for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
drop policy if exists lu_habit_logs_own_insert on public.lu_habit_logs;
create policy lu_habit_logs_own_insert on public.lu_habit_logs for insert to authenticated with check(user_id=(select auth.uid()));
drop policy if exists lu_workouts_own_insert on public.lu_workouts;
create policy lu_workouts_own_insert on public.lu_workouts for insert to authenticated with check(user_id=(select auth.uid()));
drop policy if exists lu_study_sessions_own_insert on public.lu_study_sessions;
create policy lu_study_sessions_own_insert on public.lu_study_sessions for insert to authenticated with check(user_id=(select auth.uid()));
drop policy if exists lu_english_results_own_insert on public.lu_english_results;
create policy lu_english_results_own_insert on public.lu_english_results for insert to authenticated with check(user_id=(select auth.uid()));
drop policy if exists lu_vocabulary_own_write on public.lu_vocabulary;
create policy lu_vocabulary_own_write on public.lu_vocabulary for all to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));

-- XP não pode ser inserido/editado pelo cliente. Somente funções SECURITY DEFINER abaixo.
drop policy if exists lu_xp_events_own_insert on public.lu_xp_events;
drop policy if exists lu_xp_events_own_update on public.lu_xp_events;
drop policy if exists lu_xp_events_own_delete on public.lu_xp_events;
drop policy if exists lu_activity_logs_own_insert on public.lu_activity_logs;
create policy lu_activity_logs_own_insert on public.lu_activity_logs for insert to authenticated with check(user_id=(select auth.uid()));
drop policy if exists lu_achievements_own_insert on public.lu_achievements;
-- achievements são concedidas apenas pela função segura

create or replace function public.lu_complete_task(p_task_id uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_user uuid := auth.uid(); v_task public.lu_tasks%rowtype; v_awarded integer := 0; v_total integer;
begin
 if v_user is null then raise exception 'É necessário entrar na conta.'; end if;
 select * into v_task from public.lu_tasks where id=p_task_id and user_id=v_user for update;
 if not found then raise exception 'Tarefa não encontrada.'; end if;
 if v_task.completed_at is not null then
   select coalesce(sum(amount),0) into v_total from public.lu_xp_events where user_id=v_user;
   return jsonb_build_object('already_completed',true,'awarded',0,'total_xp',v_total);
 end if;
 update public.lu_tasks set completed_at=now(),updated_at=now() where id=p_task_id and user_id=v_user;
 insert into public.lu_xp_events(user_id,source_type,source_id,amount,reason)
 values(v_user,'task',p_task_id,20,'Tarefa concluída') on conflict(user_id,source_type,source_id) do nothing;
 get diagnostics v_awarded = row_count;
 if v_awarded > 0 then
   insert into public.lu_activity_logs(user_id,activity_type,title,details) values(v_user,'task_completed',v_task.title,jsonb_build_object('task_id',p_task_id,'xp',20));
 end if;
 select coalesce(sum(amount),0) into v_total from public.lu_xp_events where user_id=v_user;
 return jsonb_build_object('already_completed',false,'awarded',case when v_awarded=1 then 20 else 0 end,'total_xp',v_total);
end $$;
revoke all on function public.lu_complete_task(uuid) from public,anon;
grant execute on function public.lu_complete_task(uuid) to authenticated;

create or replace function public.lu_award_activity_xp(p_source_type text,p_source_id uuid,p_reason text,p_amount integer default 10)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_user uuid := auth.uid(); v_count integer := 0; v_total integer;
begin
 if v_user is null then raise exception 'É necessário entrar na conta.'; end if;
 if p_source_type not in ('study','workout','habit','mission') then raise exception 'Tipo de recompensa inválido.'; end if;
 if p_amount < 1 or p_amount > 50 then raise exception 'XP fora do limite permitido.'; end if;
 insert into public.lu_xp_events(user_id,source_type,source_id,amount,reason)
 values(v_user,p_source_type,p_source_id,p_amount,left(p_reason,120)) on conflict(user_id,source_type,source_id) do nothing;
 get diagnostics v_count = row_count;
 if v_count=1 then insert into public.lu_activity_logs(user_id,activity_type,title,details) values(v_user,p_source_type,left(p_reason,120),jsonb_build_object('xp',p_amount)); end if;
 select coalesce(sum(amount),0) into v_total from public.lu_xp_events where user_id=v_user;
 return jsonb_build_object('awarded',case when v_count=1 then p_amount else 0 end,'total_xp',v_total);
end $$;
revoke all on function public.lu_award_activity_xp(text,uuid,text,integer) from public,anon;
grant execute on function public.lu_award_activity_xp(text,uuid,text,integer) to authenticated;

create or replace function public.lu_bootstrap_profile(p_player_name text default 'Jogador')
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if auth.uid() is null then raise exception 'Não autenticado'; end if;
 insert into public.lu_profiles(user_id,player_name) values(auth.uid(),left(coalesce(nullif(trim(p_player_name),''),'Jogador'),32)) on conflict(user_id) do nothing;
end $$;
revoke all on function public.lu_bootstrap_profile(text) from public,anon;
grant execute on function public.lu_bootstrap_profile(text) to authenticated;


-- Migração aditiva para produtividade geral: mantém registros antigos e tabelas legadas.
alter table public.lu_tasks add column if not exists spent_minutes integer;
alter table public.lu_tasks drop constraint if exists lu_tasks_category_check;
-- Compatibilidade com bancos criados por versões anteriores que restringiam as categorias.
