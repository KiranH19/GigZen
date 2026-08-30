-- Demo accounts. Password for every seed user: password123
-- Applied automatically by `supabase db reset`. For a hosted project, run this
-- in the SQL Editor AFTER the migration (or use the CLI).

create or replace function public._gigzen_seed_auth_user(
  p_id uuid,
  p_email text,
  p_password text,
  p_meta jsonb
) returns void
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    recovery_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at, confirmation_token, email_change,
    email_change_token_new, recovery_token
  ) values (
    '00000000-0000-0000-0000-000000000000',
    p_id,
    'authenticated',
    'authenticated',
    p_email,
    extensions.crypt(p_password, extensions.gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    p_meta,
    now(), now(), '', '', '', ''
  ) on conflict (id) do nothing;

  insert into auth.identities (
    id, user_id, identity_data, provider, provider_id, last_sign_in_at, created_at, updated_at
  ) values (
    gen_random_uuid(),
    p_id,
    jsonb_build_object('sub', p_id::text, 'email', p_email),
    'email',
    p_id::text,
    now(), now(), now()
  ) on conflict do nothing;
end;
$$;

do $$
declare
  pw text := 'password123';
  ananya uuid := '11111111-1111-4111-8111-111111111111';
  rohit  uuid := '22222222-2222-4222-8222-222222222222';
  priya  uuid := '33333333-3333-4333-8333-333333333333';
  suresh uuid := '44444444-4444-4444-8444-444444444444';
  meera  uuid := '55555555-5555-4555-8555-555555555555';
  arjun  uuid := '66666666-6666-4666-8666-666666666666';
  admin  uuid := '77777777-7777-4777-8777-777777777777';
  cafe   uuid := 'aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
  tuition uuid := 'aaaaaaa2-aaaa-4aaa-8aaa-aaaaaaaaaaa2';
  studio uuid := 'aaaaaaa3-aaaa-4aaa-8aaa-aaaaaaaaaaa3';
  job1 uuid := 'bbbbbbb1-bbbb-4bbb-8bbb-bbbbbbbbbbb1';
  job2 uuid := 'bbbbbbb2-bbbb-4bbb-8bbb-bbbbbbbbbbb2';
  job3 uuid := 'bbbbbbb3-bbbb-4bbb-8bbb-bbbbbbbbbbb3';
  job4 uuid := 'bbbbbbb4-bbbb-4bbb-8bbb-bbbbbbbbbbb4';
  job5 uuid := 'bbbbbbb5-bbbb-4bbb-8bbb-bbbbbbbbbbb5';
  job6 uuid := 'bbbbbbb6-bbbb-4bbb-8bbb-bbbbbbbbbbb6';
  job7 uuid := 'bbbbbbb7-bbbb-4bbb-8bbb-bbbbbbbbbbb7';
  job8 uuid := 'bbbbbbb8-bbbb-4bbb-8bbb-bbbbbbbbbbb8';
  job9 uuid := 'bbbbbbb9-bbbb-4bbb-8bbb-bbbbbbbbbbb9';
  job10 uuid := 'bbbbbb10-bbbb-4bbb-8bbb-bbbbbbbbbb10';
begin
  perform public._gigzen_seed_auth_user(ananya, 'ananya.student@gigzen.test', pw, jsonb_build_object(
    'role','student','full_name','Ananya Kulkarni','phone','9876500001','location','Hubli'));
  perform public._gigzen_seed_auth_user(rohit, 'rohit.student@gigzen.test', pw, jsonb_build_object(
    'role','student','full_name','Rohit Deshpande','phone','9876500002','location','Dharwad'));
  perform public._gigzen_seed_auth_user(priya, 'priya.student@gigzen.test', pw, jsonb_build_object(
    'role','student','full_name','Priya Nayak','phone','9876500003','location','Hubli'));
  perform public._gigzen_seed_auth_user(suresh, 'suresh.employer@gigzen.test', pw, jsonb_build_object(
    'role','employer','full_name','Suresh Hegde','phone','9876500101','location','Hubli',
    'business_name','Cafe Coffee Bean','business_category','Cafe & Restaurant','business_city','Hubli'));
  perform public._gigzen_seed_auth_user(meera, 'meera.employer@gigzen.test', pw, jsonb_build_object(
    'role','employer','full_name','Meera Joshi','phone','9876500102','location','Dharwad',
    'business_name','BrightMinds Tuition Centre','business_category','Education','business_city','Dharwad'));
  perform public._gigzen_seed_auth_user(arjun, 'arjun.employer@gigzen.test', pw, jsonb_build_object(
    'role','employer','full_name','Arjun Rao','phone','9876500103','location','Hubli',
    'business_name','PixelCraft Studio','business_category','IT & Web Services','business_city','Hubli'));
  perform public._gigzen_seed_auth_user(admin, 'admin@gigzen.test', pw, jsonb_build_object(
    'role','student','full_name','GigZen Admin','phone','9000000000','location','Hubli'));

  update public.profiles set role = 'admin' where id = admin;
  delete from public.student_profiles where user_id = admin;

  update public.student_profiles set
    college = 'KLE Institute of Technology, Hubli',
    course = 'Computer Science',
    year = '3rd Year',
    skills = array['Excel','Communication','Social Media'],
    bio = 'Aspiring marketer, love working with people and numbers.',
    availability = 'Weekends + evenings'
  where user_id = ananya;

  update public.student_profiles set
    college = 'SDM College of Engineering, Dharwad',
    course = 'Mechanical Engineering',
    year = '2nd Year',
    skills = array['Delivery','Two-wheeler license','Punctual'],
    bio = 'Looking for flexible evening gigs around Dharwad.',
    availability = 'Evenings, 4 hrs/day'
  where user_id = rohit;

  update public.student_profiles set
    college = 'KLE Institute of Technology, Hubli',
    course = 'Electronics & Communication',
    year = 'Final Year',
    skills = array['JavaScript','React','Git'],
    bio = 'Final-year ECE student building web projects on the side.',
    availability = 'Flexible, remote-friendly'
  where user_id = priya;

  update public.businesses set
    id = cafe,
    description = 'A cosy neighbourhood cafe known for filter coffee and quick bites.',
    address = 'Vidyanagar Main Road, Hubli',
    city = 'Hubli', location = 'Hubli', verified = true
  where owner_id = suresh;

  update public.businesses set
    id = tuition,
    description = 'After-school tuition centre for classes 6-10, Maths & Science.',
    address = 'Saptapur, Dharwad',
    city = 'Dharwad', location = 'Dharwad', verified = true
  where owner_id = meera;

  update public.businesses set
    id = studio,
    description = 'Small web design & digital marketing studio serving local businesses.',
    address = 'Deshpande Nagar, Hubli',
    city = 'Hubli', location = 'Hubli', verified = true
  where owner_id = arjun;

  insert into public.jobs (
    id, business_id, title, description, category, location, city, salary, salary_type,
    job_type, hours_per_day, days_per_week, required_skills, requirements, application_deadline, status, created_at
  ) values
    (job1, cafe, 'Part-Time Sales Assistant',
      'Handle counter sales, billing and customer queries during peak hours.',
      'Retail & Sales', 'Vidyanagar, Hubli', 'Hubli', 9000, 'month', 'Part Time', 4, 6,
      array['Communication','Billing'], 'Comfortable standing for shifts, basic spoken English/Kannada.',
      (current_date + 14), 'active', now() - interval '30 hours'),
    (job2, studio, 'Social Media Intern',
      'Plan and post content for client Instagram pages, track engagement.',
      'Marketing', 'Deshpande Nagar, Hubli', 'Hubli', 6000, 'month', 'Freelance', 3, 5,
      array['Instagram','Canva','Content Writing'], 'A phone with a decent camera; know your way around Canva or Reels.',
      (current_date + 15), 'active', now() - interval '27 hours'),
    (job3, tuition, 'Tuition Teacher — Maths & Science',
      'Teach Maths and Science to classes 8-10 in small batches after school hours.',
      'Education', 'Saptapur, Dharwad', 'Dharwad', 12000, 'month', 'Part Time', 2, 5,
      array['Subject Knowledge','Patience'], 'Strong grasp of PUC/SSLC syllabus, prior tutoring a plus.',
      (current_date + 16), 'active', now() - interval '24 hours'),
    (job4, cafe, 'Cafe Staff — Evening Shift',
      'Assist with orders, table service and closing duties in the evening shift.',
      'Cafe & Restaurant', 'Vidyanagar, Hubli', 'Hubli', 250, 'day', 'Evening', 5, 6,
      array['Customer Service','Hygiene'], 'Available 5pm-10pm, food handling basics preferred.',
      (current_date + 17), 'active', now() - interval '21 hours'),
    (job5, studio, 'Data Entry Assistant',
      'Digitise client records into spreadsheets, check for accuracy.',
      'Admin & Data', 'Deshpande Nagar, Hubli', 'Hubli', 180, 'day', 'Temporary', 3, 5,
      array['Excel','Typing Speed'], 'Comfortable with Excel/Google Sheets, good typing speed.',
      (current_date + 18), 'active', now() - interval '18 hours'),
    (job6, cafe, 'Delivery Assistant',
      'Deliver orders within a 5km radius, log deliveries in the app.',
      'Logistics', 'Vidyanagar & nearby, Hubli', 'Hubli', 300, 'day', 'Part Time', 4, 6,
      array['Two-wheeler license','Local area knowledge'], 'Own two-wheeler and valid license required.',
      (current_date + 19), 'active', now() - interval '15 hours'),
    (job7, tuition, 'Front Desk Receptionist',
      'Greet parents and students, manage enquiries and class scheduling.',
      'Admin & Data', 'Saptapur, Dharwad', 'Dharwad', 8000, 'month', 'Part Time', 4, 6,
      array['Communication','Scheduling'], 'Pleasant phone manner, basic computer use.',
      (current_date + 20), 'active', now() - interval '12 hours'),
    (job8, studio, 'Junior Web Developer',
      'Build and maintain small client websites alongside the studio team.',
      'IT & Web Services', 'Deshpande Nagar, Hubli (Remote-friendly)', 'Hubli', 14000, 'month', 'Part Time', 4, 5,
      array['HTML','CSS','JavaScript'], 'Portfolio or GitHub of past HTML/CSS/JS work.',
      (current_date + 21), 'active', now() - interval '9 hours'),
    (job9, cafe, 'Event Staff — Weekend Gigs',
      'Support setup, serving and cleanup at weekend catering events.',
      'Events', 'Various venues, Hubli', 'Hubli', 600, 'day', 'Weekend', 6, 2,
      array['Teamwork','Setup & Serving'], 'Available Saturdays/Sundays, physically active work.',
      (current_date + 22), 'active', now() - interval '6 hours'),
    (job10, studio, 'Customer Support Assistant',
      'Respond to client queries over chat/phone and log tickets.',
      'Admin & Data', 'Deshpande Nagar, Hubli', 'Hubli', 8500, 'month', 'Part Time', 4, 6,
      array['Communication','Patience','Basic English'], 'Clear communication, comfortable on calls.',
      (current_date + 23), 'active', now() - interval '3 hours')
  on conflict (id) do nothing;

  insert into public.applications (job_id, student_id, cover_message, status)
  values
    (job1, ananya, 'I have handled billing at my family shop and enjoy talking to customers.', 'shortlisted'),
    (job6, rohit, 'I have my own scooter and know most of Hubli well.', 'applied')
  on conflict (job_id, student_id) do nothing;
end $$;

drop function if exists public._gigzen_seed_auth_user(uuid, text, text, jsonb);
