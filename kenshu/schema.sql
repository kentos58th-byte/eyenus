-- KenMaP 研修支援ツール：Supabase 初期設定
-- Supabase の「SQL Editor」にこのファイルの中身を全部貼り付けて「Run」を押してください。

-- 研修セッション（受講者に見せる情報だけを置く。研修計画の三観・願いは講師の端末にだけ保存）
create table if not exists sessions (
  code text primary key,
  title text not null default '',
  content jsonb not null default '{}'::jsonb,
  active text,
  phase text,
  state text not null default 'open',
  updated_at timestamptz not null default now()
);

-- 講師用の合言葉（誰からも読めない）
create table if not exists session_keys (
  code text primary key references sessions(code) on delete cascade,
  host_key text not null
);

-- 受講者の回答（無記名。participant は端末ごとのランダムな番号）
create table if not exists responses (
  id bigserial primary key,
  session_code text not null references sessions(code) on delete cascade,
  question_id text not null,
  phase text,
  participant text not null,
  value jsonb not null,
  created_at timestamptz not null default now()
);
create index if not exists responses_session_idx on responses(session_code);

alter table sessions enable row level security;
alter table session_keys enable row level security;
alter table responses enable row level security;

drop policy if exists "sessions readable" on sessions;
create policy "sessions readable" on sessions for select using (true);

drop policy if exists "responses readable" on responses;
create policy "responses readable" on responses for select using (true);

drop policy if exists "responses insert while open" on responses;
create policy "responses insert while open" on responses for insert with check (
  exists (select 1 from sessions s where s.code = session_code and s.state = 'open')
  and length(value::text) < 4000
);

-- 受講者・投影画面に必要な権限（Supabaseでは通常すでに付いているが、念のため）
grant usage on schema public to anon;
grant select on sessions to anon;
grant select, insert on responses to anon;
grant usage, select on sequence responses_id_seq to anon;

-- 研修セッションを作る
create or replace function create_session(p_code text, p_key text, p_title text, p_content jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into sessions(code, title, content) values (p_code, p_title, p_content);
  insert into session_keys(code, host_key) values (p_code, p_key);
end; $$;

-- 研修セッションを更新する（講師の合言葉が合うときだけ）
create or replace function update_session(p_code text, p_key text, p_title text, p_content jsonb,
  p_active text, p_phase text, p_state text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from session_keys where code = p_code and host_key = p_key) then
    raise exception 'invalid key';
  end if;
  update sessions set title = p_title, content = p_content, active = p_active,
    phase = p_phase, state = p_state, updated_at = now()
  where code = p_code;
end; $$;

-- 回答をリセットする（講師の合言葉が合うときだけ）
create or replace function clear_responses(p_code text, p_key text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from session_keys where code = p_code and host_key = p_key) then
    raise exception 'invalid key';
  end if;
  delete from responses where session_code = p_code;
  update sessions set updated_at = now() where code = p_code;
end; $$;

grant execute on function create_session(text, text, text, jsonb) to anon;
grant execute on function update_session(text, text, text, jsonb, text, text, text) to anon;
grant execute on function clear_responses(text, text) to anon;

-- 回答が入ったら投影画面にすぐ届くようにする
do $$
begin
  begin
    alter publication supabase_realtime add table sessions;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table responses;
  exception when duplicate_object then null;
  end;
end $$;

-- ===== 分析と発問の依頼（後日届く仕組み） =====
create extension if not exists pgcrypto;

create table if not exists feedback_requests (
  id uuid primary key default gen_random_uuid(),
  session_code text not null references sessions(code) on delete cascade,
  payload jsonb not null,
  status text not null default 'waiting',
  feedback text,
  questions text,
  created_at timestamptz not null default now(),
  delivered_at timestamptz
);
alter table feedback_requests enable row level security;  -- 直接は誰も読めない（下の関数だけで扱う）

-- 運営用の合言葉（README の手順で1つ登録する）
create table if not exists admin_keys (key text primary key);
alter table admin_keys enable row level security;

-- 講師：依頼する
create or replace function request_feedback(p_code text, p_key text, p_payload jsonb)
returns feedback_requests language plpgsql security definer set search_path = public as $$
declare r feedback_requests;
begin
  if not exists (select 1 from session_keys where code = p_code and host_key = p_key) then
    raise exception 'invalid key';
  end if;
  insert into feedback_requests(session_code, payload) values (p_code, p_payload) returning * into r;
  return r;
end; $$;

-- 講師：届いたか確認する（いちばん新しい依頼）
create or replace function get_feedback(p_code text, p_key text)
returns setof feedback_requests language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from session_keys where code = p_code and host_key = p_key) then
    raise exception 'invalid key';
  end if;
  return query select * from feedback_requests where session_code = p_code order by created_at desc limit 1;
end; $$;

-- 運営：依頼の一覧
create or replace function admin_list_requests(p_admin text)
returns setof feedback_requests language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from admin_keys where key = p_admin) then
    raise exception 'invalid admin key';
  end if;
  return query select * from feedback_requests order by created_at desc limit 200;
end; $$;

-- 運営：フィードバックと発問を届ける
create or replace function admin_deliver(p_admin text, p_id uuid, p_feedback text, p_questions text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from admin_keys where key = p_admin) then
    raise exception 'invalid admin key';
  end if;
  update feedback_requests set feedback = p_feedback, questions = p_questions,
    status = 'delivered', delivered_at = now() where id = p_id;
end; $$;

grant execute on function request_feedback(text, text, jsonb) to anon;
grant execute on function get_feedback(text, text) to anon;
grant execute on function admin_list_requests(text) to anon;
grant execute on function admin_deliver(text, uuid, text, text) to anon;
