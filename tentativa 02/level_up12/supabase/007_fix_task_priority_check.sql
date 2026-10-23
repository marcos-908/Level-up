-- LEVEL UP: corrigir definitivamente a restrição de prioridade das tarefas.
-- Execute no SQL Editor do MESMO projeto Supabase configurado em assets/js/config.js.
-- Esta versão remove a restrição antiga ANTES de normalizar os registros.
-- Não apaga tarefas; apenas normaliza o campo priority.

begin;

alter table public.lu_tasks
  drop constraint if exists lu_tasks_priority_check;

-- Converte valores conhecidos para os códigos usados pelo frontend.
update public.lu_tasks
set priority = case
  when lower(trim(coalesce(priority, ''))) in ('low', 'baixa', 'baixo') then 'low'
  when lower(trim(coalesce(priority, ''))) in ('high', 'alta', 'alto') then 'high'
  when lower(trim(coalesce(priority, ''))) in ('medium', 'média', 'media', 'normal', '') then 'medium'
  else 'medium'
end
where priority is null
   or lower(trim(priority)) not in ('low', 'medium', 'high');

alter table public.lu_tasks
  alter column priority set default 'medium';

alter table public.lu_tasks
  alter column priority set not null;

alter table public.lu_tasks
  add constraint lu_tasks_priority_check
  check (priority in ('low', 'medium', 'high'));

commit;

notify pgrst, 'reload schema';
