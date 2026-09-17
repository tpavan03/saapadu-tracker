-- Allow every signed-in Google account to access only its own backup row.
-- Run this once for projects created with the original single-email policy.
drop policy if exists "owner can read backup" on public.user_backups;
create policy "owner can read backup"
on public.user_backups for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "owner can create backup" on public.user_backups;
create policy "owner can create backup"
on public.user_backups for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "owner can update backup" on public.user_backups;
create policy "owner can update backup"
on public.user_backups for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
