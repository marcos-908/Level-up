-- LEVEL UP — SQL seguro (não apaga nada). Rode UMA vez em: Supabase > SQL Editor.
-- Usa tabelas com prefixo lu_ para não colidir com tabelas que você já tenha.
create table if not exists lu_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text, xp int not null default 0 check (xp >= 0),
  settings jsonb not null default '{}'::jsonb, created_at timestamptz default now());
create table if not exists lu_tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  title text not null, category text default 'pessoal', priority text default 'media' check (priority in ('baixa','media','alta')),
  due_at timestamptz, est_min int, status text not null default 'open' check (status in ('open','done')),
  completed_at timestamptz, created_at timestamptz default now());
create table if not exists lu_english_log (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  question text, correct boolean not null, created_at timestamptz default now());

alter table lu_profiles enable row level security;
alter table lu_tasks enable row level security;
alter table lu_english_log enable row level security;
drop policy if exists p_sel on lu_profiles; drop policy if exists p_ins on lu_profiles; drop policy if exists p_upd on lu_profiles;
create policy p_sel on lu_profiles for select using (id = auth.uid());
create policy p_ins on lu_profiles for insert with check (id = auth.uid() and xp = 0);
create policy p_upd on lu_profiles for update using (id = auth.uid());
drop policy if exists t_all on lu_tasks; create policy t_all on lu_tasks for all using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists e_sel on lu_english_log; drop policy if exists e_ins on lu_english_log;
create policy e_sel on lu_english_log for select using (user_id = auth.uid());
create policy e_ins on lu_english_log for insert with check (user_id = auth.uid());

-- O navegador NÃO pode alterar XP, status nem datas de conclusão: só colunas permitidas.
revoke insert, update on lu_profiles, lu_tasks from authenticated;
grant select on lu_profiles, lu_tasks, lu_english_log to authenticated;
grant delete on lu_tasks to authenticated;
grant insert (id, display_name) on lu_profiles to authenticated;
grant update (display_name, settings) on lu_profiles to authenticated;
grant insert (user_id, title, category, priority, due_at, est_min) on lu_tasks to authenticated;
grant update (title, category, priority, due_at, est_min) on lu_tasks to authenticated;
grant insert (question, correct, user_id) on lu_english_log to authenticated;

-- XP concedido só aqui, uma vez por tarefa (sem recompensa duplicada).
create or replace function complete_task(t uuid) returns int
language plpgsql security definer set search_path = public as $$
declare r lu_tasks; gain int;
begin
  select * into r from lu_tasks where id = t and user_id = auth.uid() for update;
  if not found then raise exception 'Tarefa não encontrada'; end if;
  if r.status = 'done' then return 0; end if;
  gain := case r.priority when 'alta' then 30 when 'media' then 20 else 10 end;
  update lu_tasks set status = 'done', completed_at = now() where id = t;
  insert into lu_profiles (id) values (auth.uid()) on conflict (id) do nothing;
  update lu_profiles set xp = xp + gain where id = auth.uid();
  return gain;
end $$;
revoke all on function complete_task(uuid) from public;
grant execute on function complete_task(uuid) to authenticated;
