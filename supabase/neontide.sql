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

-- ───────── v0.17.1 정식판 권한 ─────────
-- 지금은 개발자가 직접 부여(아래 맨 끝 줄). 나중에 구글 플레이 결제 확인 서버가 이 표에 기록합니다.
create table if not exists public.nt_entitlements (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  full_game  boolean not null default false,
  source     text not null default 'manual',
  granted_at timestamptz not null default now()
);
alter table public.nt_entitlements enable row level security;
revoke all on public.nt_entitlements from anon, authenticated;

create or replace function public.nt_entitled()
returns boolean language sql security definer stable set search_path = public as $$
  select coalesce((select full_game from public.nt_entitlements where user_id = auth.uid()), false);
$$;
revoke all on function public.nt_entitled() from public, anon;
grant execute on function public.nt_entitled() to authenticated;

-- 개발자 계정에 정식판 부여 (그 구글 계정으로 게임에 한 번 로그인한 뒤에 실행해야 들어갑니다)
insert into public.nt_entitlements (user_id, full_game, source)
  select id, true, 'owner' from auth.users where email = 'bingkui1992@gmail.com'
  on conflict (user_id) do update set full_game = true;
