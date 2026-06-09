-- Run this in the Supabase SQL Editor for the linked project.
-- This is the database-side guard for reservation race conditions.
--
-- It serializes competing reservation writes with transaction-scoped advisory
-- locks, then rejects:
-- 1. overlapping reservations by the same user, and
-- 2. overlapping reservations that exceed machine capacity.
--
-- Dumbbell/barbell reservations are separated by machine_name because the app
-- stores the selected weight in that field.

create or replace function public.reservation_machine_capacity(
  p_machine_id text
)
returns integer
language sql
immutable
as $$
  select case
    when p_machine_id = 'treadmill' then 9
    when p_machine_id = 'cycle' then 4
    else 1
  end;
$$;

create or replace function public.reservations_prevent_overlap()
returns trigger
language plpgsql
as $$
declare
  machine_capacity integer;
  overlapping_count integer;
  has_user_overlap boolean;
begin
  if new.status not in ('waiting', 'active') then
    return new;
  end if;

  if new.reserved_start_at is null or new.reserved_end_at is null then
    return new;
  end if;

  -- Lock order is stable to avoid deadlocks: user first, then machine slot.
  perform pg_advisory_xact_lock(
    hashtextextended('reservation_user:' || new.user_id, 0)
  );

  perform pg_advisory_xact_lock(
    hashtextextended(
      'reservation_machine:'
        || new.machine_id
        || ':'
        || case
          when new.machine_id in ('dumbbell', 'barbell') then new.machine_name
          else '*'
        end,
      0
    )
  );

  select exists (
    select 1
    from public.reservations r
    where r.id is distinct from new.id
      and r.user_id = new.user_id
      and r.status in ('waiting', 'active')
      and r.reserved_start_at < new.reserved_end_at
      and r.reserved_end_at > new.reserved_start_at
  )
  into has_user_overlap;

  if has_user_overlap then
    raise exception 'reservation_conflict_user_overlap'
      using errcode = '23514',
            constraint = 'reservations_no_user_overlap';
  end if;

  machine_capacity := public.reservation_machine_capacity(new.machine_id);

  select count(*)
  from public.reservations r
  where r.id is distinct from new.id
    and r.machine_id = new.machine_id
    and r.status in ('waiting', 'active')
    and (
      new.machine_id not in ('dumbbell', 'barbell')
      or r.machine_name = new.machine_name
    )
    and r.reserved_start_at < new.reserved_end_at
    and r.reserved_end_at > new.reserved_start_at
  into overlapping_count;

  if overlapping_count >= machine_capacity then
    raise exception 'reservation_conflict_machine_capacity'
      using errcode = '23514',
            constraint = 'reservations_machine_capacity';
  end if;

  return new;
end;
$$;

drop trigger if exists reservations_prevent_overlap_trigger
  on public.reservations;

create trigger reservations_prevent_overlap_trigger
before insert or update on public.reservations
for each row
execute function public.reservations_prevent_overlap();
