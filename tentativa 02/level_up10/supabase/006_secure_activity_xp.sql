-- LEVEL UP: impede XP arbitrário via chamada direta da RPC.
-- A função só recompensa registros reais pertencentes ao usuário autenticado.
-- Execute no SQL Editor do mesmo projeto Supabase.
create or replace function public.lu_award_activity_xp(p_source_type text,p_source_id uuid,p_reason text,p_amount integer default 10)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_user uuid := auth.uid(); v_count integer := 0; v_total integer;
begin
 if v_user is null then raise exception 'É necessário entrar na conta.'; end if;
 if p_source_type not in ('study','workout','habit') then raise exception 'Tipo de recompensa inválido.'; end if;
 if (p_source_type='study' and p_amount<>10)
    or (p_source_type='workout' and p_amount<>10)
    or (p_source_type='habit' and p_amount<>5) then
   raise exception 'Quantidade de XP inválida para esta atividade.';
 end if;
 if p_source_type='study' and not exists(select 1 from public.lu_study_sessions where id=p_source_id and user_id=v_user) then
   raise exception 'Sessão de estudo não encontrada para esta conta.';
 elsif p_source_type='workout' and not exists(select 1 from public.lu_workouts where id=p_source_id and user_id=v_user) then
   raise exception 'Atividade física não encontrada para esta conta.';
 elsif p_source_type='habit' and not exists(
   select 1 from public.lu_habit_logs hl
   join public.lu_habits h on h.id=hl.habit_id and h.user_id=v_user
   where hl.id=p_source_id and hl.user_id=v_user and hl.log_date=current_date
 ) then
   raise exception 'Registro de hábito não encontrado para esta conta.';
 end if;
 insert into public.lu_xp_events(user_id,source_type,source_id,amount,reason)
 values(v_user,p_source_type,p_source_id,p_amount,left(coalesce(p_reason,''),120))
 on conflict(user_id,source_type,source_id) do nothing;
 get diagnostics v_count = row_count;
 if v_count=1 then
   insert into public.lu_activity_logs(user_id,activity_type,title,details)
   values(v_user,p_source_type,left(coalesce(p_reason,''),120),jsonb_build_object('xp',p_amount));
 end if;
 select coalesce(sum(amount),0) into v_total from public.lu_xp_events where user_id=v_user;
 return jsonb_build_object('awarded',case when v_count=1 then p_amount else 0 end,'total_xp',v_total);
end $$;
revoke all on function public.lu_award_activity_xp(text,uuid,text,integer) from public,anon;
grant execute on function public.lu_award_activity_xp(text,uuid,text,integer) to authenticated;
notify pgrst, 'reload schema';
