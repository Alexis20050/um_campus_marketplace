-- Repair existing profile names using signup/Google metadata only.
-- Never derive a student's name from their email address.
with candidates as (
  select u.id, candidate.name
  from auth.users u
  cross join lateral (
    select btrim(value) as name
    from (values
      (1, u.raw_user_meta_data ->> 'name'),
      (2, u.raw_user_meta_data ->> 'full_name'),
      (3, u.raw_user_meta_data ->> 'display_name')
    ) as names(priority, value)
    where btrim(coalesce(value, '')) <> ''
      and position('@' in value) = 0
      and lower(btrim(value)) not in ('um student', 'name unavailable')
    order by priority
    limit 1
  ) candidate
)
update public.profiles p
set name = c.name
from candidates c
where p.id = c.id
  and (btrim(coalesce(p.name, '')) = ''
    or position('@' in p.name) > 0
    or lower(btrim(p.name)) in ('um student', 'name unavailable'));
