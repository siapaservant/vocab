-- 單字卡片盒：帳號密碼登入 + 雲端進度
-- 在 Supabase 的 SQL Editor 整段貼上執行一次即可（重複執行也沒關係）。
create extension if not exists pgcrypto;

create table if not exists public.vocab_accounts (
  username    text primary key,
  pass_hash   text not null,
  name        text not null default '',
  data        jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now(),
  created_at  timestamptz not null default now()
);
create table if not exists public.vocab_sessions (
  token       text primary key,
  username    text not null references public.vocab_accounts(username) on delete cascade,
  created_at  timestamptz not null default now()
);

-- 兩張表完全上鎖：網頁不能直接讀寫，只能透過下面的函式
alter table public.vocab_accounts enable row level security;
alter table public.vocab_sessions enable row level security;
revoke all on public.vocab_accounts from anon, authenticated;
revoke all on public.vocab_sessions from anon, authenticated;

create or replace function public.vocab_new_session(p_user text) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare t text := encode(gen_random_bytes(24), 'hex');
begin
  insert into vocab_sessions(token, username) values (t, p_user);
  return t;
end $$;

-- 註冊：帳號 3–20 個英文小寫、數字、底線；密碼至少 6 碼
create or replace function public.vocab_register(p_user text, p_pass text, p_name text, p_data jsonb)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare u text := lower(trim(p_user)); now_ts timestamptz := now();
begin
  if u !~ '^[a-z0-9_]{3,20}$' then raise exception 'bad_username'; end if;
  if length(coalesce(p_pass,'')) < 6 then raise exception 'short_password'; end if;
  if exists(select 1 from vocab_accounts where username = u) then raise exception 'username_taken'; end if;
  insert into vocab_accounts(username, pass_hash, name, data, updated_at)
    values (u, crypt(p_pass, gen_salt('bf')), coalesce(p_name,''), coalesce(p_data,'{}'::jsonb), now_ts);
  return json_build_object('token', vocab_new_session(u), 'username', u, 'name', p_name, 'data', p_data, 'updated_at', now_ts);
end $$;

create or replace function public.vocab_login(p_user text, p_pass text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare a vocab_accounts;
begin
  select * into a from vocab_accounts where username = lower(trim(p_user));
  if a.username is null or a.pass_hash <> crypt(p_pass, a.pass_hash) then
    perform pg_sleep(0.5); raise exception 'wrong_login';
  end if;
  return json_build_object('token', vocab_new_session(a.username), 'username', a.username, 'name', a.name, 'data', a.data, 'updated_at', a.updated_at);
end $$;

create or replace function public.vocab_load(p_token text)
returns json language plpgsql security definer set search_path = public as $$
declare a vocab_accounts;
begin
  select ac.* into a from vocab_sessions s join vocab_accounts ac on ac.username = s.username where s.token = p_token;
  if a.username is null then raise exception 'bad_session'; end if;
  return json_build_object('username', a.username, 'name', a.name, 'data', a.data, 'updated_at', a.updated_at);
end $$;

create or replace function public.vocab_save(p_token text, p_name text, p_data jsonb)
returns timestamptz language plpgsql security definer set search_path = public as $$
declare u text; now_ts timestamptz := now();
begin
  select username into u from vocab_sessions where token = p_token;
  if u is null then raise exception 'bad_session'; end if;
  update vocab_accounts set data = p_data, name = coalesce(p_name, name), updated_at = now_ts where username = u;
  return now_ts;
end $$;

create or replace function public.vocab_logout(p_token text)
returns void language sql security definer set search_path = public as $$
  delete from vocab_sessions where token = p_token;
$$;

create or replace function public.vocab_change_password(p_token text, p_old text, p_new text)
returns void language plpgsql security definer set search_path = public, extensions as $$
declare u text; h text;
begin
  select s.username, a.pass_hash into u, h from vocab_sessions s join vocab_accounts a on a.username = s.username where s.token = p_token;
  if u is null then raise exception 'bad_session'; end if;
  if h <> crypt(p_old, h) then raise exception 'wrong_login'; end if;
  if length(coalesce(p_new,'')) < 6 then raise exception 'short_password'; end if;
  update vocab_accounts set pass_hash = crypt(p_new, gen_salt('bf')) where username = u;
  delete from vocab_sessions where username = u and token <> p_token;
end $$;

revoke all on function public.vocab_new_session(text) from public, anon, authenticated;
grant execute on function public.vocab_register(text,text,text,jsonb) to anon;
grant execute on function public.vocab_login(text,text) to anon;
grant execute on function public.vocab_load(text) to anon;
grant execute on function public.vocab_save(text,text,jsonb) to anon;
grant execute on function public.vocab_logout(text) to anon;
grant execute on function public.vocab_change_password(text,text,text) to anon;
