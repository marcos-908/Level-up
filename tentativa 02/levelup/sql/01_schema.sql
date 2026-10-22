-- LEVEL UP • Execute no Supabase: SQL Editor > New query. Não apaga nada existente.
create table if not exists public.profiles(
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Jogador' check (char_length(display_name) between 1 and 40),
  xp integer not null default 0 check (xp >= 0),
  level integer not null default 1,
  created_at timestamptz not null default now());
create table if not exists public.user_settings(
  user_id uuid primary key references auth.users(id) on delete cascade default auth.uid(),
  sound_on boolean not null default true,
  volume numeric not null default 0.6 check (volume between 0 and 1),
  reminders_on boolean not null default true,
  reminder_lead_min integer not null default 10 check (reminder_lead_min between -1 and 1440),
  reminder_sound boolean not null default true,
  updated_at timestamptz not null default now());
create table if not exists public.tasks(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 200),
  description text,
  category text not null default 'geral',
  priority text not null default 'media' check (priority in ('baixa','media','alta')),
  due_at timestamptz,
  estimate_min integer check (estimate_min is null or estimate_min >= 0),
  status text not null default 'pendente' check (status in ('pendente','concluida')),
  completed_at timestamptz,
  created_at timestamptz not null default now());
create table if not exists public.xp_events(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  source text not null, source_id uuid not null, amount integer not null,
  created_at timestamptz not null default now(),
  unique(user_id, source, source_id));   -- impede XP duplicado

alter table public.profiles enable row level security;
alter table public.user_settings enable row level security;
alter table public.tasks enable row level security;
alter table public.xp_events enable row level security;

drop policy if exists p_sel on public.profiles; drop policy if exists p_upd on public.profiles;
create policy p_sel on public.profiles for select using (id = auth.uid());
create policy p_upd on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());
-- usuário só pode editar o nome; XP e nível só mudam via função segura
revoke update on public.profiles from authenticated, anon;
grant update (display_name) on public.profiles to authenticated;

drop policy if exists s_all on public.user_settings;
create policy s_all on public.user_settings for all using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists t_all on public.tasks;
create policy t_all on public.tasks for all using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists x_sel on public.xp_events;
create policy x_sel on public.xp_events for select using (user_id = auth.uid());

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id, display_name)
  values (new.id, coalesce(nullif(split_part(new.email,'@',1),''),'Jogador')) on conflict do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

insert into public.profiles(id, display_name)
select id, coalesce(nullif(split_part(email,'@',1),''),'Jogador') from auth.users on conflict do nothing;

-- Nível = floor(sqrt(xp/100)) + 1
create or replace function public.complete_task(p_task_id uuid) returns json
language plpgsql security definer set search_path = public as $$
declare t public.tasks; gain int; ins int; old_lvl int; new_xp int; new_lvl int;
begin
  select * into t from public.tasks where id = p_task_id and user_id = auth.uid() for update;
  if not found then raise exception 'Tarefa não encontrada'; end if;
  gain := case t.priority when 'alta' then 30 when 'media' then 20 else 10 end;
  update public.tasks set status='concluida', completed_at = coalesce(completed_at, now()) where id = t.id;
  insert into public.xp_events(user_id, source, source_id, amount)
    values (auth.uid(), 'tarefa', t.id, gain) on conflict do nothing;
  get diagnostics ins = row_count;
  if ins = 0 then gain := 0; end if;
  select level into old_lvl from public.profiles where id = auth.uid();
  update public.profiles set xp = xp + gain, level = floor(sqrt((xp + gain) / 100.0))::int + 1
    where id = auth.uid() returning xp, level into new_xp, new_lvl;
  return json_build_object('xp_gained', gain, 'xp', new_xp, 'level', new_lvl, 'leveled_up', new_lvl > old_lvl);
end $$;
revoke all on function public.complete_task(uuid) from public, anon;
grant execute on function public.complete_task(uuid) to authenticated;
