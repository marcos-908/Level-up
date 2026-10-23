-- Harden activity XP awards: the source record must exist and belong to auth.uid().
-- Rewards stay fixed by activity type; this migration does not modify existing data.
create or replace function public.lu_award_activity_xp(
  p_source_type text,
  p_source_id uuid,
  p_reason text,
  p_amount integer default 10
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_expected integer;
  v_count integer := 0;
  v_total integer;
  v_source_exists boolean := false;
begin
  if v_user is null then raise exception 'É necessário entrar na conta.'; end if;

  if p_source_type = 'study' then
    select exists(select 1 from public.lu_study_sessions where id=p_source_id and user_id=v_user) into v_source_exists;
    v_expected := 10;
  elsif p_source_type = 'workout' then
    select exists(select 1 from public.lu_workouts where id=p_source_id and user_id=v_user) into v_source_exists;
    v_expected := 10;
  elsif p_source_type = 'habit' then
    select exists(select 1 from public.lu_habit_logs where id=p_source_id and user_id=v_user) into v_source_exists;
    v_expected := 5;
  else
    raise exception 'Tipo de recompensa inválido.';
  end if;

  if not v_source_exists then raise exception 'Registro de origem não encontrado para esta conta.'; end if;
  if p_amount is distinct from v_expected then raise exception 'Valor de XP inválido para este tipo de atividade.'; end if;

  insert into public.lu_xp_events(user_id,source_type,source_id,amount,reason)
  values(v_user,p_source_type,p_source_id,v_expected,left(coalesce(p_reason,''),120))
  on conflict(user_id,source_type,source_id) do nothing;
  get diagnostics v_count = row_count;

  if v_count=1 then
    insert into public.lu_activity_logs(user_id,activity_type,title,details)
    values(v_user,p_source_type,left(coalesce(p_reason,''),120),jsonb_build_object('xp',v_expected));
  end if;

  select coalesce(sum(amount),0) into v_total from public.lu_xp_events where user_id=v_user;
  return jsonb_build_object('awarded',case when v_count=1 then v_expected else 0 end,'total_xp',v_total);
end $$;

revoke all on function public.lu_award_activity_xp(text,uuid,text,integer) from public, anon;
grant execute on function public.lu_award_activity_xp(text,uuid,text,integer) to authenticated;

notify pgrst, 'reload schema';
