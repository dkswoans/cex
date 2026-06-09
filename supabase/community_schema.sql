-- Run this in the Supabase SQL Editor for the linked project.
-- The app uses a custom 4-digit user id, not Supabase Auth, so these policies
-- allow the publishable/anon key to read and write community rows.

create table if not exists public.community_posts (
  id text primary key,
  author_user_id text not null,
  author_name text not null,
  title text not null check (char_length(btrim(title)) between 1 and 80),
  body text not null check (char_length(btrim(body)) between 1 and 1200),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.community_comments (
  id text primary key,
  post_id text not null references public.community_posts(id) on delete cascade,
  author_user_id text not null,
  author_name text not null,
  body text not null check (char_length(btrim(body)) between 1 and 500),
  created_at timestamptz not null default now()
);

create index if not exists community_posts_created_at_idx
  on public.community_posts (created_at desc);

create index if not exists community_comments_post_created_idx
  on public.community_comments (post_id, created_at asc);

create or replace function public.community_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists community_posts_touch_updated_at
  on public.community_posts;

create trigger community_posts_touch_updated_at
before update on public.community_posts
for each row execute function public.community_touch_updated_at();

alter table public.community_posts enable row level security;
alter table public.community_comments enable row level security;

drop policy if exists community_posts_select on public.community_posts;
drop policy if exists community_posts_insert on public.community_posts;
drop policy if exists community_posts_update on public.community_posts;
drop policy if exists community_posts_delete on public.community_posts;

create policy community_posts_select
  on public.community_posts for select
  to anon, authenticated
  using (true);

create policy community_posts_insert
  on public.community_posts for insert
  to anon, authenticated
  with check (true);

create policy community_posts_update
  on public.community_posts for update
  to anon, authenticated
  using (true)
  with check (true);

create policy community_posts_delete
  on public.community_posts for delete
  to anon, authenticated
  using (true);

drop policy if exists community_comments_select on public.community_comments;
drop policy if exists community_comments_insert on public.community_comments;
drop policy if exists community_comments_update on public.community_comments;
drop policy if exists community_comments_delete on public.community_comments;

create policy community_comments_select
  on public.community_comments for select
  to anon, authenticated
  using (true);

create policy community_comments_insert
  on public.community_comments for insert
  to anon, authenticated
  with check (true);

create policy community_comments_update
  on public.community_comments for update
  to anon, authenticated
  using (true)
  with check (true);

create policy community_comments_delete
  on public.community_comments for delete
  to anon, authenticated
  using (true);

do $$
begin
  alter publication supabase_realtime add table public.community_posts;
exception
  when duplicate_object then null;
end;
$$;

do $$
begin
  alter publication supabase_realtime add table public.community_comments;
exception
  when duplicate_object then null;
end;
$$;
