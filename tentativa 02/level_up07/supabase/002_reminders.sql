-- LEVEL UP: corrigir/atualizar colunas usadas por tarefas e lembretes.
-- Migração aditiva e idempotente: não apaga tarefas nem recria tabelas.

-- Compatibilidade para instalações que receberam apenas parte das migrações.
alter table public.lu_tasks
  add column if not exists description text not null default '',
  add column if not exists category text not null default 'general',
  add column if not exists priority text not null default 'medium',
  add column if not exists due_at timestamptz,
  add column if not exists estimated_minutes integer,
  add column if not exists spent_minutes integer,
  add column if not exists completed_at timestamptz,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists due_date_only boolean not null default false,
  add column if not exists reminder_minutes integer not null default 10,
  add column if not exists reminder_sent_at timestamptz;

alter table public.lu_events
  add column if not exists starts_date_only boolean not null default false,
  add column if not exists reminder_minutes integer not null default 10,
  add column if not exists reminder_sent_at timestamptz;

-- Categorias personalizadas são permitidas; prioridade continua restrita a valores válidos.
alter table public.lu_tasks drop constraint if exists lu_tasks_category_check;
alter table public.lu_tasks drop constraint if exists lu_tasks_spent_minutes_check;
alter table public.lu_tasks add constraint lu_tasks_spent_minutes_check
  check (spent_minutes is null or spent_minutes between 0 and 1440);
alter table public.lu_tasks drop constraint if exists lu_tasks_estimated_minutes_check;
alter table public.lu_tasks add constraint lu_tasks_estimated_minutes_check
  check (estimated_minutes is null or estimated_minutes between 1 and 1440);

-- Valores de lembrete: -1 = desativado, 0 = horário exato, positivos = minutos antes.
alter table public.lu_tasks drop constraint if exists lu_tasks_reminder_minutes_check;
alter table public.lu_tasks add constraint lu_tasks_reminder_minutes_check
  check (reminder_minutes in (-1, 0, 5, 10, 15, 30, 60, 1440));
alter table public.lu_events drop constraint if exists lu_events_reminder_minutes_check;
alter table public.lu_events add constraint lu_events_reminder_minutes_check
  check (reminder_minutes in (-1, 0, 5, 10, 15, 30, 60, 1440));

create index if not exists lu_tasks_reminder_idx
  on public.lu_tasks(user_id, due_at) where completed_at is null;
create index if not exists lu_events_reminder_idx
  on public.lu_events(user_id, starts_at) where completed_at is null;
