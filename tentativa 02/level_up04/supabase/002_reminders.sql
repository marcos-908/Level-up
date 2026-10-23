-- LEVEL UP: lembretes por atividade. Migração aditiva e segura; não remove dados.
alter table public.lu_tasks
  add column if not exists due_date_only boolean not null default false,
  add column if not exists reminder_minutes integer not null default 10,
  add column if not exists reminder_sent_at timestamptz;

alter table public.lu_events
  add column if not exists starts_date_only boolean not null default false,
  add column if not exists reminder_minutes integer not null default 10,
  add column if not exists reminder_sent_at timestamptz;

create index if not exists lu_tasks_reminder_idx
  on public.lu_tasks(user_id, due_at) where completed_at is null;
create index if not exists lu_events_reminder_idx
  on public.lu_events(user_id, starts_at) where completed_at is null;

-- -1 significa sem lembrete; valores positivos são minutos antes e 0 é no horário exato.
alter table public.lu_tasks drop constraint if exists lu_tasks_reminder_minutes_check;
alter table public.lu_tasks add constraint lu_tasks_reminder_minutes_check
  check (reminder_minutes in (-1, 0, 5, 10, 15, 30, 60, 1440));
alter table public.lu_events drop constraint if exists lu_events_reminder_minutes_check;
alter table public.lu_events add constraint lu_events_reminder_minutes_check
  check (reminder_minutes in (-1, 0, 5, 10, 15, 30, 60, 1440));
