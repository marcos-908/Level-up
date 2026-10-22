-- LEVEL UP: resultados persistentes dos exercícios de inglês.
-- Migração aditiva: não altera nem apaga tabelas ou registros existentes.
create table if not exists public.lu_english_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  question_id text not null check (char_length(question_id) between 1 and 80),
  question_text text not null check (char_length(question_text) between 1 and 500),
  answer_text text not null check (char_length(answer_text) between 1 and 300),
  correct boolean not null,
  answered_on date not null default current_date,
  created_at timestamptz not null default now()
);
create index if not exists lu_english_attempts_user_created_idx
  on public.lu_english_attempts(user_id, created_at desc);
alter table public.lu_english_attempts enable row level security;
drop policy if exists lu_english_attempts_own_select on public.lu_english_attempts;
create policy lu_english_attempts_own_select on public.lu_english_attempts
  for select to authenticated using (auth.uid() = user_id);
drop policy if exists lu_english_attempts_own_insert on public.lu_english_attempts;
create policy lu_english_attempts_own_insert on public.lu_english_attempts
  for insert to authenticated with check (auth.uid() = user_id);
grant select, insert on public.lu_english_attempts to authenticated;
