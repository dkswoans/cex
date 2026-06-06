-- Run this in the Supabase SQL Editor.
-- It keeps the existing 20-minute database cap for normal machines,
-- and allows 30-minute reservations for treadmill and cycle.

alter table public.reservations
drop constraint if exists reservations_time_window_check;

alter table public.reservations
add constraint reservations_time_window_check
check (
  reserved_end_at > reserved_start_at
  and (
    (
      machine_id in ('treadmill', 'cycle')
      and reserved_end_at <= reserved_start_at + interval '30 minutes'
    )
    or (
      machine_id not in ('treadmill', 'cycle')
      and reserved_end_at <= reserved_start_at + interval '20 minutes'
    )
  )
);
