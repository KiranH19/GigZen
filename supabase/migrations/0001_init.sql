-- GigZen schema, RLS, triggers, RPCs, and storage.
-- Apply with: supabase db reset   or paste into SQL Editor.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.user_role as enum ('student', 'employer', 'admin');
create type public.job_status as enum ('active', 'paused', 'closed');
create type public.application_status as enum ('applied', 'shortlisted', 'interview', 'hired', 'rejected');
create type public.salary_period as enum ('month', 'day', 'hour');
create type public.report_status as enum ('open', 'resolved');
create type public.notification_type as enum ('info', 'status');

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  role public.user_role not null default 'student',
  full_name text not null default '',
  email text not null,
  phone text default '',
  avatar_url text default '',
  location text default '',
  suspended boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (email)
);

create table public.student_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles (id) on delete cascade,
  college text default '',
  course text default '',
  year text default '',
  skills text[] not null default '{}',
  bio text default '',
  availability text default '',
  resume_url text default '',
  profile_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references public.profiles (id) on delete cascade,
  business_name text not null,
  description text default '',
  category text default '',
  phone text default '',
  email text default '',
  logo_url text default '',
  address text default '',
  city text default '',
  location text default '',
  verified boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.jobs (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  title text not null,
  description text not null default '',
  category text not null default 'Other',
  location text not null default '',
  city text not null default '',
  salary numeric not null default 0 check (salary >= 0),
  salary_type public.salary_period not null default 'month',
  job_type text not null default 'Part Time',
  hours_per_day numeric not null default 4 check (hours_per_day > 0 and hours_per_day <= 24),
  days_per_week integer not null default 5 check (days_per_week between 1 and 7),
  required_skills text[] not null default '{}',
  requirements text default '',
  application_deadline date,
  status public.job_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs (id) on delete cascade,
  student_id uuid not null references public.profiles (id) on delete cascade,
  cover_message text default '',
  status public.application_status not null default 'applied',
  applied_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (job_id, student_id)
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  job_id uuid references public.jobs (id) on delete set null,
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  reason text not null,
  description text default '',
  status public.report_status not null default 'open',
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  message text not null,
  type public.notification_type not null default 'info',
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create index jobs_status_created_idx on public.jobs (status, created_at desc);
create index jobs_city_idx on public.jobs (city);
create index jobs_category_idx on public.jobs (category);
create index jobs_business_idx on public.jobs (business_id);
create index applications_student_idx on public.applications (student_id, applied_at desc);
create index applications_job_idx on public.applications (job_id, applied_at desc);
create index notifications_user_idx on public.notifications (user_id, created_at desc);
create index reports_status_idx on public.reports (status, created_at desc);

-- ---------------------------------------------------------------------------
-- updated_at helper
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger student_profiles_updated_at before update on public.student_profiles
  for each row execute function public.set_updated_at();
create trigger businesses_updated_at before update on public.businesses
  for each row execute function public.set_updated_at();
create trigger jobs_updated_at before update on public.jobs
  for each row execute function public.set_updated_at();
create trigger applications_updated_at before update on public.applications
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Auth helpers (security definer so RLS policies can call them)
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin' and suspended = false
  );
$$;

create or replace function public.current_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.is_suspended()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select suspended from public.profiles where id = auth.uid()), false);
$$;

create or replace function public.owns_business(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.businesses
    where id = p_business_id and owner_id = auth.uid()
  );
$$;

create or replace function public.owns_job(p_job_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.jobs j
    join public.businesses b on b.id = j.business_id
    where j.id = p_job_id and b.owner_id = auth.uid()
  );
$$;

-- ---------------------------------------------------------------------------
-- Signup: create profile (+ student row or business) from auth metadata
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  chosen_role text := coalesce(meta->>'role', 'student');
  safe_role public.user_role;
begin
  if chosen_role = 'admin' then
    safe_role := 'student'; -- never allow self-signup as admin
  elsif chosen_role in ('student', 'employer') then
    safe_role := chosen_role::public.user_role;
  else
    safe_role := 'student';
  end if;

  insert into public.profiles (id, role, full_name, email, phone, location)
  values (
    new.id,
    safe_role,
    coalesce(meta->>'full_name', ''),
    new.email,
    coalesce(meta->>'phone', ''),
    coalesce(meta->>'location', '')
  )
  on conflict (id) do nothing;

  if safe_role = 'student' then
    insert into public.student_profiles (user_id)
    values (new.id)
    on conflict (user_id) do nothing;
  elsif safe_role = 'employer' then
    insert into public.businesses (
      owner_id, business_name, category, city, location, phone, email
    ) values (
      new.id,
      coalesce(nullif(meta->>'business_name', ''), 'My business'),
      coalesce(meta->>'business_category', 'Other'),
      coalesce(meta->>'business_city', coalesce(meta->>'location', '')),
      coalesce(meta->>'business_city', coalesce(meta->>'location', '')),
      coalesce(meta->>'phone', ''),
      new.email
    )
    on conflict (owner_id) do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Keep profile email in sync if auth email changes
create or replace function public.handle_user_email_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email is distinct from old.email then
    update public.profiles set email = new.email where id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
  after update of email on auth.users
  for each row execute function public.handle_user_email_change();

-- Non-admins cannot change role; employers cannot self-verify
create or replace function public.protect_privileged_columns()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- auth.uid() is null for SQL Editor / seed (postgres role) — allow those updates
  if tg_table_name = 'profiles' then
    if new.role is distinct from old.role and auth.uid() is not null and not public.is_admin() then
      new.role := old.role;
    end if;
    if new.suspended is distinct from old.suspended and auth.uid() is not null and not public.is_admin() then
      new.suspended := old.suspended;
    end if;
  elsif tg_table_name = 'businesses' then
    if new.verified is distinct from old.verified and auth.uid() is not null and not public.is_admin() then
      new.verified := old.verified;
    end if;
    if new.owner_id is distinct from old.owner_id then
      new.owner_id := old.owner_id;
    end if;
  end if;
  return new;
end;
$$;

create trigger profiles_protect before update on public.profiles
  for each row execute function public.protect_privileged_columns();
create trigger businesses_protect before update on public.businesses
  for each row execute function public.protect_privileged_columns();

-- Auto-complete student profile flag
create or replace function public.touch_student_completion()
returns trigger
language plpgsql
as $$
begin
  new.profile_completed := (
    coalesce(new.college, '') <> ''
    and coalesce(new.course, '') <> ''
    and coalesce(new.year, '') <> ''
    and coalesce(array_length(new.skills, 1), 0) > 0
    and coalesce(new.bio, '') <> ''
    and coalesce(new.availability, '') <> ''
  );
  return new;
end;
$$;

create trigger student_completion before insert or update on public.student_profiles
  for each row execute function public.touch_student_completion();

-- Notifications from applications (never trust the client for these)
create or replace function public.notify_application_events()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  job_title text;
  student_name text;
  owner_id uuid;
begin
  select j.title, b.owner_id into job_title, owner_id
  from public.jobs j
  join public.businesses b on b.id = j.business_id
  where j.id = coalesce(new.job_id, old.job_id);

  if tg_op = 'INSERT' then
    select full_name into student_name from public.profiles where id = new.student_id;
    insert into public.notifications (user_id, message, type)
    values (owner_id, coalesce(student_name, 'A student') || ' applied for "' || coalesce(job_title, 'a job') || '"', 'info');
  elsif tg_op = 'UPDATE' and new.status is distinct from old.status then
    insert into public.notifications (user_id, message, type)
    values (new.student_id, 'Your application for "' || coalesce(job_title, 'a job') || '" is now ' || new.status::text || '.', 'status');
  end if;
  return new;
end;
$$;

create trigger applications_notify
  after insert or update of status on public.applications
  for each row execute function public.notify_application_events();

-- Block writes from suspended accounts
create or replace function public.reject_if_suspended()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() is not null and public.is_suspended() and not public.is_admin() then
    raise exception 'Account is suspended';
  end if;
  return new;
end;
$$;

create trigger jobs_not_suspended before insert or update on public.jobs
  for each row execute function public.reject_if_suspended();
create trigger applications_not_suspended before insert or update on public.applications
  for each row execute function public.reject_if_suspended();
create trigger reports_not_suspended before insert or update on public.reports
  for each row execute function public.reject_if_suspended();

-- ---------------------------------------------------------------------------
-- Public stats (landing page) — aggregates only
-- ---------------------------------------------------------------------------
create or replace function public.landing_stats()
returns json
language sql
stable
security definer
set search_path = public
as $$
  select json_build_object(
    'active_jobs', (select count(*)::int from public.jobs where status = 'active'),
    'businesses', (select count(*)::int from public.businesses),
    'hired', (select count(*)::int from public.applications where status = 'hired')
  );
$$;

grant execute on function public.landing_stats() to anon, authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.current_role() to authenticated;

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.student_profiles enable row level security;
alter table public.businesses enable row level security;
alter table public.jobs enable row level security;
alter table public.applications enable row level security;
alter table public.reports enable row level security;
alter table public.notifications enable row level security;

-- profiles
create policy profiles_select on public.profiles
  for select using (
    id = auth.uid()
    or public.is_admin()
    or exists (
      select 1
      from public.applications a
      join public.jobs j on j.id = a.job_id
      join public.businesses b on b.id = j.business_id
      where a.student_id = profiles.id
        and b.owner_id = auth.uid()
    )
  );

create policy profiles_update_own on public.profiles
  for update using (id = auth.uid() or public.is_admin())
  with check (id = auth.uid() or public.is_admin());

-- student_profiles
create policy student_profiles_select on public.student_profiles
  for select using (
    user_id = auth.uid()
    or public.is_admin()
    or exists (
      select 1
      from public.applications a
      join public.jobs j on j.id = a.job_id
      join public.businesses b on b.id = j.business_id
      where a.student_id = student_profiles.user_id
        and b.owner_id = auth.uid()
    )
  );

create policy student_profiles_insert_own on public.student_profiles
  for insert with check (user_id = auth.uid());

create policy student_profiles_update_own on public.student_profiles
  for update using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());

-- businesses: public read (job board)
create policy businesses_select on public.businesses
  for select using (true);

create policy businesses_insert_own on public.businesses
  for insert with check (
    owner_id = auth.uid()
    and public.current_role() = 'employer'
    and not public.is_suspended()
  );

create policy businesses_update_own on public.businesses
  for update using (owner_id = auth.uid() or public.is_admin())
  with check (owner_id = auth.uid() or public.is_admin());

-- jobs
create policy jobs_select on public.jobs
  for select using (
    status = 'active'
    or public.is_admin()
    or public.owns_business(business_id)
    or exists (
      select 1 from public.applications a
      where a.job_id = jobs.id and a.student_id = auth.uid()
    )
  );

create policy jobs_insert_owner on public.jobs
  for insert with check (
    public.owns_business(business_id)
    and public.current_role() = 'employer'
    and not public.is_suspended()
  );

create policy jobs_update_owner on public.jobs
  for update using (public.owns_business(business_id) or public.is_admin())
  with check (public.owns_business(business_id) or public.is_admin());

create policy jobs_delete_owner on public.jobs
  for delete using (public.owns_business(business_id) or public.is_admin());

-- applications
create policy applications_select on public.applications
  for select using (
    student_id = auth.uid()
    or public.owns_job(job_id)
    or public.is_admin()
  );

create policy applications_insert_student on public.applications
  for insert with check (
    student_id = auth.uid()
    and public.current_role() = 'student'
    and not public.is_suspended()
    and exists (select 1 from public.jobs j where j.id = job_id and j.status = 'active')
  );

create policy applications_update_employer on public.applications
  for update using (public.owns_job(job_id) or public.is_admin())
  with check (public.owns_job(job_id) or public.is_admin());

-- reports
create policy reports_insert_auth on public.reports
  for insert with check (
    reporter_id = auth.uid()
    and not public.is_suspended()
  );

create policy reports_select_admin on public.reports
  for select using (public.is_admin() or reporter_id = auth.uid());

create policy reports_update_admin on public.reports
  for update using (public.is_admin())
  with check (public.is_admin());

-- notifications
create policy notifications_select_own on public.notifications
  for select using (user_id = auth.uid() or public.is_admin());

create policy notifications_update_own on public.notifications
  for update using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('logos', 'logos', true),
  ('resumes', 'resumes', false)
on conflict (id) do nothing;

create policy avatars_public_read on storage.objects
  for select using (bucket_id = 'avatars');

create policy avatars_own_write on storage.objects
  for insert with check (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy avatars_own_update on storage.objects
  for update using (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy avatars_own_delete on storage.objects
  for delete using (
    bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy logos_public_read on storage.objects
  for select using (bucket_id = 'logos');

create policy logos_own_write on storage.objects
  for insert with check (
    bucket_id = 'logos' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy logos_own_update on storage.objects
  for update using (
    bucket_id = 'logos' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy logos_own_delete on storage.objects
  for delete using (
    bucket_id = 'logos' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy resumes_select on storage.objects
  for select using (
    bucket_id = 'resumes'
    and (
      auth.uid()::text = (storage.foldername(name))[1]
      or public.is_admin()
      or exists (
        select 1
        from public.applications a
        join public.jobs j on j.id = a.job_id
        join public.businesses b on b.id = j.business_id
        where a.student_id::text = (storage.foldername(name))[1]
          and b.owner_id = auth.uid()
      )
    )
  );

create policy resumes_own_write on storage.objects
  for insert with check (
    bucket_id = 'resumes' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy resumes_own_update on storage.objects
  for update using (
    bucket_id = 'resumes' and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy resumes_own_delete on storage.objects
  for delete using (
    bucket_id = 'resumes' and auth.uid()::text = (storage.foldername(name))[1]
  );
