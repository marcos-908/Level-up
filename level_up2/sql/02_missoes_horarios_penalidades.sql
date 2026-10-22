-- LEVEL UP v2: horários, lembretes e penalidades. Migração aditiva, sem apagar dados.
-- Execute DEPOIS de 01_schema.sql no SQL Editor do projeto Supabase existente.

alter table public.lu_tasks add column if not exists due_at timestamptz;
alter table public.lu_tasks add column if not exists reminder_minutes integer not null default 10;
alter table public.lu_tasks add column if not exists missed_at timestamptz;
alter table public.lu_tasks add column if not exists xp_penalty integer not null default 0;
alter table public.lu_tasks drop constraint if exists lu_tasks_reminder_minutes_check;
alter table public.lu_tasks add constraint lu_tasks_reminder_minutes_check check (reminder_minutes in (0,5,10,15,30,60));
alter table public.lu_tasks drop constraint if exists lu_tasks_xp_penalty_check;
alter table public.lu_tasks add constraint lu_tasks_xp_penalty_check check (xp_penalty >= 0);
create index if not exists lu_tasks_due_at_idx on public.lu_tasks(user_id, due_at) where completed_at is null and missed_at is null;

create table if not exists public.lu_penalty_events (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  task_id uuid not null unique references public.lu_tasks(id) on delete cascade,
  xp_amount integer not null check (xp_amount > 0),
  created_at timestamptz not null default now()
);
revoke all on public.lu_penalty_events from anon, authenticated;

-- Recria as políticas de tarefas para impedir que o navegador marque uma tarefa como perdida
-- ou altere a penalidade diretamente. As funções SECURITY DEFINER abaixo fazem isso com segurança.
drop policy if exists "lu_tasks_insert_own" on public.lu_tasks;
create policy "lu_tasks_insert_own" on public.lu_tasks for insert to authenticated
with check (auth.uid() = user_id and completed_at is null and xp_awarded = 0 and missed_at is null and xp_penalty = 0);
drop policy if exists "lu_tasks_update_own_pending" on public.lu_tasks;
create policy "lu_tasks_update_own_pending" on public.lu_tasks for update to authenticated
using (auth.uid() = user_id and completed_at is null and missed_at is null)
with check (auth.uid() = user_id and completed_at is null and xp_awarded = 0 and missed_at is null and xp_penalty = 0);
drop policy if exists "lu_tasks_delete_own_pending" on public.lu_tasks;
create policy "lu_tasks_delete_own_pending" on public.lu_tasks for delete to authenticated
using (auth.uid() = user_id and completed_at is null);
grant select, insert, update, delete on public.lu_tasks to authenticated;

-- Cada atividade vencida é processada uma vez. A perda não reduz XP abaixo de zero.
create or replace function public.lu_process_overdue_tasks()
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_task public.lu_tasks%rowtype;
  v_inserted integer;
  v_processed integer := 0;
  v_total_penalty integer := 0;
  v_penalty constant integer := 25;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  for v_task in
    select * from public.lu_tasks
    where user_id = v_uid and due_at is not null and due_at <= now()
      and completed_at is null and missed_at is null
    order by due_at for update
  loop
    insert into public.lu_penalty_events(user_id, task_id, xp_amount)
    values (v_uid, v_task.id, v_penalty) on conflict (task_id) do nothing;
    get diagnostics v_inserted = row_count;
    if v_inserted = 1 then
      update public.lu_profiles
        set total_xp = greatest(0, total_xp - v_penalty)
        where user_id = v_uid;
      update public.lu_tasks set missed_at = now(), xp_penalty = v_penalty
        where id = v_task.id and user_id = v_uid and missed_at is null and completed_at is null;
      v_processed := v_processed + 1;
      v_total_penalty := v_total_penalty + v_penalty;
    end if;
  end loop;
  return jsonb_build_object('processed', v_processed, 'xp_penalty', v_total_penalty);
end; $$;
revoke all on function public.lu_process_overdue_tasks() from public, anon;
grant execute on function public.lu_process_overdue_tasks() to authenticated;

-- Atualiza a conclusão para verificar o prazo no banco antes de entregar XP.
create or replace function public.lu_complete_task(p_task_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_task public.lu_tasks%rowtype;
  v_old_xp integer;
  v_new_xp integer;
  v_old_level integer := 1;
  v_new_level integer := 1;
  v_remaining integer;
  v_xp integer := 50;
  v_inserted integer;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  perform public.lu_process_overdue_tasks();
  select * into v_task from public.lu_tasks where id = p_task_id and user_id = v_uid for update;
  if not found then raise exception 'Task not found or not owned by user'; end if;
  if v_task.missed_at is not null then
    return jsonb_build_object('xp_awarded',0,'leveled_up',false,'missed',true,'xp_penalty',v_task.xp_penalty);
  end if;
  if v_task.completed_at is not null then
    return jsonb_build_object('xp_awarded',0,'leveled_up',false,'already_completed',true);
  end if;
  select total_xp into v_old_xp from public.lu_profiles where user_id = v_uid for update;
  if not found then raise exception 'Player profile not found'; end if;
  insert into public.lu_reward_events(user_id,task_id,xp_amount) values(v_uid,p_task_id,v_xp) on conflict(task_id) do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted = 0 then return jsonb_build_object('xp_awarded',0,'leveled_up',false,'already_completed',true); end if;
  update public.lu_tasks set completed_at = now(), xp_awarded = v_xp where id = p_task_id and user_id = v_uid;
  v_new_xp := v_old_xp + v_xp;
  update public.lu_profiles set total_xp = v_new_xp where user_id = v_uid;
  v_remaining := v_old_xp;
  while v_remaining >= v_old_level * 100 loop v_remaining := v_remaining - v_old_level * 100; v_old_level := v_old_level + 1; end loop;
  v_remaining := v_new_xp;
  while v_remaining >= v_new_level * 100 loop v_remaining := v_remaining - v_new_level * 100; v_new_level := v_new_level + 1; end loop;
  return jsonb_build_object('xp_awarded',v_xp,'total_xp',v_new_xp,'leveled_up',v_new_level > v_old_level,'new_level',v_new_level,'first_achievement',(select count(*) = 1 from public.lu_tasks where user_id = v_uid and completed_at is not null));
end; $$;
revoke all on function public.lu_complete_task(uuid) from public, anon;
grant execute on function public.lu_complete_task(uuid) to authenticated;
