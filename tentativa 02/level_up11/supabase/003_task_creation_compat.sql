-- LEVEL UP: compatibilidade aditiva para cadastro de tarefas em bancos existentes.
-- Seguro para reaplicar; não apaga nem recria dados.
alter table public.lu_tasks
  add column if not exists spent_minutes integer,
  add column if not exists due_date_only boolean not null default false,
  add column if not exists reminder_minutes integer not null default 10,
  add column if not exists reminder_sent_at timestamptz;

alter table public.lu_tasks drop constraint if exists lu_tasks_spent_minutes_check;
alter table public.lu_tasks add constraint lu_tasks_spent_minutes_check
  check (spent_minutes is null or spent_minutes between 0 and 1440);

alter table public.lu_tasks drop constraint if exists lu_tasks_reminder_minutes_check;
alter table public.lu_tasks add constraint lu_tasks_reminder_minutes_check
  check (reminder_minutes in (-1, 0, 5, 10, 15, 30, 60, 1440));

-- Remove a antiga restrição de categoria fixa para permitir categorias personalizadas.
alter table public.lu_tasks drop constraint if exists lu_tasks_category_check;

create index if not exists lu_tasks_reminder_idx
  on public.lu_tasks(user_id, due_at) where completed_at is null;
