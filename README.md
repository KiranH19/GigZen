# GigZen

GigZen is a Supabase-backed part-time job marketplace for college students and local businesses in Hubli-Dharwad, Karnataka.

The app is intentionally simple on the frontend: plain HTML, CSS, and JavaScript. Supabase provides the backend, database, authentication, row-level security, database triggers, RPCs, storage buckets, and seed data.

## What Is Included

- Student, employer, and admin authentication through Supabase Auth
- Student profiles with skills, education, bio, availability, and resume URL
- Employer business profiles
- Job posting, editing, pausing, closing, and deleting
- Student job search, job details, and applications
- Employer applicant review with shortlist, interview, hire, and reject states
- Admin dashboards for users, jobs, applications, and reports
- Supabase Postgres schema with RLS policies
- Database triggers for profile creation, timestamps, student completion status, and notifications
- Storage buckets for avatars, business logos, and resumes
- Demo seed accounts and sample jobs

## Project Structure

```text
gigzen/
├── index.html
├── login.html
├── signup.html
├── jobs.html
├── job-details.html
├── student-dashboard.html
├── applications.html
├── profile.html
├── employer-dashboard.html
├── post-job.html
├── manage-jobs.html
├── applicants.html
├── employer-profile.html
├── admin-dashboard.html
├── admin-users.html
├── admin-jobs.html
├── admin-applications.html
├── admin-reports.html
├── css/
│   └── style.css
├── js/
│   ├── config.js
│   ├── data.js
│   └── main.js
└── supabase/
    ├── migrations/
    │   └── 0001_init.sql
    └── seed.sql
```

## Backend And Database

The Supabase backend lives in:

- `supabase/migrations/0001_init.sql`
- `supabase/seed.sql`

Main database tables:

- `profiles`
- `student_profiles`
- `businesses`
- `jobs`
- `applications`
- `reports`
- `notifications`

Supabase storage buckets:

- `avatars` public
- `logos` public
- `resumes` private

## Environment Files

Use the examples in this project as templates:

- `.env.example`
- `.env.local.example`

Create your local env file:

```bash
cp .env.local.example .env.local
```

Then fill in:

```env
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
```

Important:

- Keep committed values empty.
- Do not commit `.env.local`.
- Never put your Supabase `service_role` key in frontend JavaScript.
- The current plain HTML app cannot read `.env.local` directly in the browser. For local testing, copy only `SUPABASE_URL` and `SUPABASE_ANON_KEY` into `js/config.js` on your own machine, or add a small build step later to generate `js/config.js` from `.env.local`.

## Supabase Setup

1. Create a new project at Supabase.

2. Open your Supabase project dashboard.

3. Go to SQL Editor.

4. Run the full contents of:

```text
supabase/migrations/0001_init.sql
```

5. Run the full contents of:

```text
supabase/seed.sql
```

6. Go to Project Settings > API.

7. Copy your Project URL and anon public key into `.env.local`.

8. For local browser testing only, copy the Project URL and anon public key into:

```text
js/config.js
```

Do not add the service role key to `js/config.js`.

## Run Locally

No build step is required.

```bash
cd /Users/kiranhandi/Downloads/gigzen
python3 -m http.server 8080
```

Then open:

```text
http://localhost:8080
```

## Demo Accounts

Every seed account uses this password:

```text
password123
```

| Role | Email |
|---|---|
| Student | ananya.student@gigzen.test |
| Student | rohit.student@gigzen.test |
| Student | priya.student@gigzen.test |
| Employer | suresh.employer@gigzen.test |
| Employer | meera.employer@gigzen.test |
| Employer | arjun.employer@gigzen.test |
| Admin | admin@gigzen.test |

## What You Should Do Next

1. Create your Supabase project.

2. Run `supabase/migrations/0001_init.sql` in the Supabase SQL Editor.

3. Run `supabase/seed.sql` in the Supabase SQL Editor.

4. Add your Supabase URL and anon public key to `.env.local`.

5. For local testing, put only the public URL and anon key into `js/config.js`, then start the local server with `python3 -m http.server 8080`.

6. Test login with the demo accounts.

7. Test the full flow:

- Student signs up and edits profile
- Employer signs up and posts a job
- Student applies to a job
- Employer changes application status
- Admin reviews users, jobs, applications, and reports

8. Before launch, replace demo emails and seed data with real data.

9. Configure Supabase Auth settings:

- Site URL
- Redirect URLs
- Email confirmation setting
- Email templates

10. Add file upload UI for avatars, logos, and resumes if you want users to upload files directly instead of pasting links.

## Important Notes

- The anon key is public, but you may still prefer not to commit it.
- The service role key is secret and must stay server-side only.
- Row-level security is enabled in the migration.
- Admin users should not be created from public signup. The migration blocks self-signup as admin.
- To create another admin, update a trusted user's role directly in Supabase SQL Editor.

Example:

```sql
update public.profiles
set role = 'admin'
where email = 'your-admin-email@example.com';
```

## Current Limitation

This project uses Supabase directly from frontend JavaScript. That is okay for an MVP because RLS protects the database. For production, add server-side functions only for sensitive operations such as payments, private admin workflows, webhooks, and integrations.
