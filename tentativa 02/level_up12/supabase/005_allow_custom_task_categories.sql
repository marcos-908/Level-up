-- LEVEL UP: permitir categorias personalizadas em tarefas.
-- Execute no SQL Editor do MESMO projeto Supabase usado pelo aplicativo.
-- Remove apenas a restrição antiga de valores fixos; não apaga nem altera tarefas existentes.

alter table public.lu_tasks
  drop constraint if exists lu_tasks_category_check;

notify pgrst, 'reload schema';
