-- LEVEL UP: corrigir a restrição de prioridade das tarefas.
-- Execute no SQL Editor do MESMO projeto Supabase usado em assets/js/config.js.
-- Mantém as tarefas existentes e alinha o banco aos valores enviados pelo app.js:
-- low, medium, high.

begin;

-- Normaliza valores antigos/conhecidos antes de trocar a restrição.
update public.lu_tasks
set priority = case
  when lower(trim(priority)) in ('low', 'baixa', 'baixo') then 'low'
  when lower(trim(priority)) in ('high', 'alta', 'alto') then 'high'
  when lower(trim(priority)) in ('medium', 'media', 'média', 'normal', '') then 'medium'
  else 'medium'
end
where priority is null
   or lower(trim(priority)) not in ('low', 'medium', 'high');

-- Remove a restrição antiga, que não aceita os valores usados pelo aplicativo.
alter table public.lu_tasks
  drop constraint if exists lu_tasks_priority_check;

-- Garante que novas tarefas usem exatamente os valores esperados pelo frontend.
alter table public.lu_tasks
  alter column priority set default 'medium';

alter table public.lu_tasks
  alter column priority set not null;

alter table public.lu_tasks
  add constraint lu_tasks_priority_check
  check (priority in ('low', 'medium', 'high'));

commit;

notify pgrst, 'reload schema';
