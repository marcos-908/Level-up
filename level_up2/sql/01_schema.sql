-- LEVEL UP / esquema aditivo e idempotente para Supabase existente.
-- Execute no SQL Editor do SEU projeto. Não apaga nem recria tabelas antigas.
create table if not exists public.lu_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  player_name text not null default 'Jogador' check (char_length(player_name) between 1 and 30),
  total_xp integer not null default 0 check (total_xp >= 0),
  preferences jsonb not null default '{"sound_enabled":true,"sound_volume":35}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.lu_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 100),
  description text check (description is null or char_length(description) <= 500),
  category text not null default 'Estudos' check (category in ('Estudos','Programação','Inglês','Rotina','Pessoal')),
  priority text not null default 'normal' check (priority in ('low','normal','high')),
  due_date date,
  xp_awarded integer not null default 0 check (xp_awarded >= 0),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  updated_at timestamptz not null default now()
);
create index if not exists lu_tasks_user_created_idx on public.lu_tasks(user_id, created_at desc);
create index if not exists lu_tasks_user_completed_idx on public.lu_tasks(user_id, completed_at);
create table if not exists public.lu_reward_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  task_id uuid not null unique references public.lu_tasks(id) on delete cascade,
  xp_amount integer not null check (xp_amount > 0),
  created_at timestamptz not null default now()
);
create index if not exists lu_reward_events_user_idx on public.lu_reward_events(user_id, created_at desc);

alter table public.lu_profiles enable row level security;
alter table public.lu_tasks enable row level security;
alter table public.lu_reward_events enable row level security;

drop policy if exists "lu_profiles_select_own" on public.lu_profiles;
create policy "lu_profiles_select_own" on public.lu_profiles for select to authenticated using (auth.uid() = user_id);
drop policy if exists "lu_profiles_insert_own" on public.lu_profiles;
create policy "lu_profiles_insert_own" on public.lu_profiles for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "lu_profiles_update_own" on public.lu_profiles;
create policy "lu_profiles_update_own" on public.lu_profiles for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "lu_tasks_select_own" on public.lu_tasks;
create policy "lu_tasks_select_own" on public.lu_tasks for select to authenticated using (auth.uid() = user_id);
drop policy if exists "lu_tasks_insert_own" on public.lu_tasks;
create policy "lu_tasks_insert_own" on public.lu_tasks for insert to authenticated with check (auth.uid() = user_id and completed_at is null and xp_awarded = 0);
drop policy if exists "lu_tasks_update_own_pending" on public.lu_tasks;
create policy "lu_tasks_update_own_pending" on public.lu_tasks for update to authenticated using (auth.uid() = user_id and completed_at is null) with check (auth.uid() = user_id and completed_at is null and xp_awarded = 0);
drop policy if exists "lu_tasks_delete_own_pending" on public.lu_tasks;
create policy "lu_tasks_delete_own_pending" on public.lu_tasks for delete to authenticated using (auth.uid() = user_id and completed_at is null);
-- reward_events: sem policies de escrita/leitura para clientes; só função SECURITY DEFINER grava.
revoke all on public.lu_reward_events from anon, authenticated;
revoke insert, update on public.lu_profiles from authenticated;
grant select on public.lu_profiles to authenticated;
grant insert (user_id, player_name, preferences) on public.lu_profiles to authenticated;
grant update (player_name, preferences) on public.lu_profiles to authenticated;
grant select, insert, update, delete on public.lu_tasks to authenticated;
-- Clients do not need direct access to reward-event sequence or reward table.

create or replace function public.lu_touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end; $$;
drop trigger if exists lu_profiles_touch_updated_at on public.lu_profiles;
create trigger lu_profiles_touch_updated_at before update on public.lu_profiles for each row execute function public.lu_touch_updated_at();
drop trigger if exists lu_tasks_touch_updated_at on public.lu_tasks;
create trigger lu_tasks_touch_updated_at before update on public.lu_tasks for each row execute function public.lu_touch_updated_at();

-- Garante perfil inicial quando uma conta Auth é criada. Não sobrescreve perfis existentes.
create or replace function public.lu_create_profile_for_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.lu_profiles(user_id, player_name)
  values (new.id, coalesce(nullif(left(new.raw_user_meta_data->>'player_name',30),''), split_part(coalesce(new.email,'Jogador'),'@',1)))
  on conflict (user_id) do nothing;
  return new;
end; $$;
drop trigger if exists lu_auth_user_profile on auth.users;
create trigger lu_auth_user_profile after insert on auth.users for each row execute function public.lu_create_profile_for_user();

-- XP é calculado no banco. Cada tarefa só pode gerar um evento de recompensa.
-- Progressão: nível 1 requer 100 XP; nível 2 requer 200; nível 3 requer 300 etc.
create or replace function public.lu_complete_task(p_task_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := auth.uid(); v_task public.lu_tasks%rowtype; v_old_xp integer; v_new_xp integer; v_old_level integer := 1; v_new_level integer := 1; v_remaining integer; v_xp integer := 50; v_inserted integer;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  select * into v_task from public.lu_tasks where id=p_task_id and user_id=v_uid for update;
  if not found then raise exception 'Task not found or not owned by user'; end if;
  if v_task.completed_at is not null then
    return jsonb_build_object('xp_awarded',0,'leveled_up',false,'already_completed',true);
  end if;
  select total_xp into v_old_xp from public.lu_profiles where user_id=v_uid for update;
  if not found then raise exception 'Player profile not found'; end if;
  insert into public.lu_reward_events(user_id,task_id,xp_amount) values(v_uid,p_task_id,v_xp) on conflict(task_id) do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted=0 then return jsonb_build_object('xp_awarded',0,'leveled_up',false,'already_completed',true); end if;
  update public.lu_tasks set completed_at=now(),xp_awarded=v_xp where id=p_task_id and user_id=v_uid;
  v_new_xp := v_old_xp + v_xp;
  update public.lu_profiles set total_xp=v_new_xp where user_id=v_uid;
  v_remaining := v_old_xp;
  while v_remaining >= v_old_level*100 loop v_remaining := v_remaining-v_old_level*100; v_old_level := v_old_level+1; end loop;
  v_remaining := v_new_xp;
  while v_remaining >= v_new_level*100 loop v_remaining := v_remaining-v_new_level*100; v_new_level := v_new_level+1; end loop;
  return jsonb_build_object('xp_awarded',v_xp,'total_xp',v_new_xp,'leveled_up',v_new_level>v_old_level,'new_level',v_new_level,'first_achievement',(select count(*)=1 from public.lu_tasks where user_id=v_uid and completed_at is not null));
end; $$;
revoke all on function public.lu_complete_task(uuid) from public, anon;
grant execute on function public.lu_complete_task(uuid) to authenticated;
revoke all on function public.lu_create_profile_for_user() from public, anon, authenticated;
revoke all on function public.lu_touch_updated_at() from public, anon, authenticated;
