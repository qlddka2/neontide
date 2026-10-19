-- 네온 타이드 클라우드 저장 (v0.17.0)
-- 퇴마·맞수와 같은 Supabase 프로젝트의 SQL Editor에서 한 번 실행하세요. 여러 번 실행해도 안전합니다.
-- profiles 테이블(맞수 schema.sql)이 이미 있어야 합니다.
create table if not exists public.nt_saves (
  user_id    uuid primary key references public.profiles(id) on delete cascade,
  data       jsonb not null,
  progress   bigint not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.nt_saves enable row level security;
revoke all on public.nt_saves from anon, authenticated;

create or replace function public.nt_save_get()
returns jsonb language plpgsql security definer stable set search_path = public as $$
declare s public.nt_saves;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into s from public.nt_saves where user_id = auth.uid();
  if not found then return null; end if;
  return jsonb_build_object('data', s.data, 'progress', s.progress, 'updated_at', s.updated_at);
end $$;

-- 다른 기기에서 먼저 저장했으면(p_base보다 새 기록) 덮어쓰지 않고 서버 데이터를 돌려줘서 게임이 고르게 합니다.
create or replace function public.nt_save_put(p_data jsonb, p_progress bigint, p_base timestamptz, p_force boolean default false)
returns jsonb language plpgsql security definer set search_path = public as $$
declare s public.nt_saves; ts timestamptz := clock_timestamp();
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_data is null or jsonb_typeof(p_data) <> 'object' or octet_length(p_data::text) > 500000 then raise exception 'invalid'; end if;
  insert into public.profiles (id, nickname)
    values (auth.uid(), '플레이어' || substr(replace(auth.uid()::text, '-', ''), 1, 6)) on conflict (id) do nothing;
  select * into s from public.nt_saves where user_id = auth.uid() for update;
  if found and not coalesce(p_force, false) and (p_base is null or s.updated_at > p_base) then
    return jsonb_build_object('conflict', true, 'data', s.data, 'progress', s.progress, 'updated_at', s.updated_at);
  end if;
  insert into public.nt_saves (user_id, data, progress, updated_at) values (auth.uid(), p_data, coalesce(p_progress, 0), ts)
    on conflict (user_id) do update set data = excluded.data, progress = excluded.progress, updated_at = excluded.updated_at;
  return jsonb_build_object('ok', true, 'updated_at', ts);
end $$;

revoke all on function public.nt_save_get() from public, anon;
revoke all on function public.nt_save_put(jsonb, bigint, timestamptz, boolean) from public, anon;
grant execute on function public.nt_save_get() to authenticated;
grant execute on function public.nt_save_put(jsonb, bigint, timestamptz, boolean) to authenticated;
