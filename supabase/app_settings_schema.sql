-- Run this in the Supabase SQL Editor for the linked project.
-- The app uses a custom 4-digit user id, not Supabase Auth, so these policies
-- allow the publishable/anon key to read and write app settings.

create table if not exists public.app_settings (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);

create or replace function public.app_settings_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists app_settings_touch_updated_at
  on public.app_settings;

create trigger app_settings_touch_updated_at
before update on public.app_settings
for each row execute function public.app_settings_touch_updated_at();

insert into public.app_settings (key, value)
values ('home_title', 'BSSM GYM !!!')
on conflict (key) do nothing;

alter table public.app_settings enable row level security;

drop policy if exists app_settings_select on public.app_settings;
drop policy if exists app_settings_insert on public.app_settings;
drop policy if exists app_settings_update on public.app_settings;
drop policy if exists app_settings_delete on public.app_settings;

create policy app_settings_select
  on public.app_settings for select
  to anon, authenticated
  using (true);

create policy app_settings_insert
  on public.app_settings for insert
  to anon, authenticated
  with check (true);

create policy app_settings_update
  on public.app_settings for update
  to anon, authenticated
  using (true)
  with check (true);

create policy app_settings_delete
  on public.app_settings for delete
  to anon, authenticated
  using (true);

do $$
begin
  alter publication supabase_realtime add table public.app_settings;
exception
  when duplicate_object then null;
end;
$$;
