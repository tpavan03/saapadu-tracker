create table if not exists public.user_backups (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  schema_version integer not null default 1 check (schema_version >= 1),
  revision bigint not null default 1 check (revision >= 1),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.user_backups enable row level security;

revoke all on table public.user_backups from anon, authenticated;
grant select, insert, update on table public.user_backups to authenticated;

drop policy if exists "owner can read backup" on public.user_backups;
create policy "owner can read backup"
on public.user_backups for select to authenticated
using (
  (select auth.uid()) = user_id
  and lower(coalesce((select auth.jwt()->>'email'), '')) =
      'thokalapavan.pp@gmail.com'
);

drop policy if exists "owner can create backup" on public.user_backups;
create policy "owner can create backup"
on public.user_backups for insert to authenticated
with check (
  (select auth.uid()) = user_id
  and lower(coalesce((select auth.jwt()->>'email'), '')) =
      'thokalapavan.pp@gmail.com'
);

drop policy if exists "owner can update backup" on public.user_backups;
create policy "owner can update backup"
on public.user_backups for update to authenticated
using (
  (select auth.uid()) = user_id
  and lower(coalesce((select auth.jwt()->>'email'), '')) =
      'thokalapavan.pp@gmail.com'
)
with check (
  (select auth.uid()) = user_id
  and lower(coalesce((select auth.jwt()->>'email'), '')) =
      'thokalapavan.pp@gmail.com'
);

