-- LEVEL UP: reparo idempotente do esquema de tarefas e lembretes.
-- Execute no SQL Editor do MESMO projeto Supabase configurado em assets/js/config.js.
-- Somente adiciona colunas/índices; não apaga tabelas nem registros.

alter table public.lu_tasks
  add column if not exists description text not null default '',
  add column if not exists category text not null default 'general',
  add column if not exists priority text not null default 'medium',
  add column if not exists due_at timestamptz,
  add column if not exists estimated_minutes integer,
  add column if not exists spent_minutes integer,
  add column if not exists completed_at timestamptz,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists due_date_only boolean not null default false,
  add column if not exists reminder_minutes integer not null default 10,
  add column if not exists reminder_sent_at timestamptz;

alter table public.lu_events
  add column if not exists title text,
  add column if not exists category text not null default 'general',
  add column if not exists starts_at timestamptz,
  add column if not exists ends_at timestamptz,
  add column if not exists notes text not null default '',
  add column if not exists completed_at timestamptz,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists starts_date_only boolean not null default false,
  add column if not exists reminder_minutes integer not null default 10,
  add column if not exists reminder_sent_at timestamptz;

create index if not exists lu_tasks_reminder_idx
  on public.lu_tasks(user_id, due_at) where completed_at is null;
create index if not exists lu_events_reminder_idx
  on public.lu_events(user_id, starts_at) where completed_at is null;

-- Solicita ao PostgREST atualizar o cache de esquema após a migração.
notify pgrst, 'reload schema';
