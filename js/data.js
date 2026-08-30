/* ==========================================================================
   GigZen — data.js
   Supabase-backed data layer. Method names match the old localStorage API
   so pages stay thin; every read/write is async and goes through RLS.
   ========================================================================== */

(function(){
  const cfg = window.GZ_CONFIG || {};
  const configured = cfg.supabaseUrl && cfg.supabaseAnonKey
    && !String(cfg.supabaseUrl).includes('YOUR_SUPABASE')
    && !String(cfg.supabaseAnonKey).includes('YOUR_SUPABASE');

  function nowIso(){ return new Date().toISOString(); }
  function uid(prefix){ return (prefix||'id') + '_' + crypto.randomUUID(); }

  function fail(error){
    if(!error) return;
    const msg = error.message || String(error);
    console.error('[GigZen]', error);
    throw new Error(msg);
  }

  if(!configured){
    window.GZ_DB = {
      configured: false, uid, nowIso, client: null,
      users: { all: async()=>[], find: async()=>null, findByEmail: async()=>null, insert: async()=>null, update: async()=>null },
      students: { all: async()=>[], byUser: async()=>null, upsert: async()=>null },
      businesses: { all: async()=>[], find: async()=>null, byOwner: async()=>null, insert: async()=>null, update: async()=>null },
      jobs: { all: async()=>[], find: async()=>null, byBusiness: async()=>[], insert: async()=>null, update: async()=>null, remove: async()=>{} },
      applications: { all: async()=>[], find: async()=>null, byStudent: async()=>[], byJob: async()=>[], existing: async()=>null, insert: async()=>null, update: async()=>null },
      reports: { all: async()=>[], insert: async()=>null, update: async()=>null },
      notifications: { all: async()=>[], byUser: async()=>[], insert: async()=>null, markRead: async()=>{} },
      session: { get: async()=>null, set: async()=>{}, clear: async()=>{} },
      auth: { signIn: async()=>{ throw new Error('Supabase is not configured. Add your project URL and anon key in js/config.js'); }, signUp: async()=>{ throw new Error('Supabase is not configured.'); }, signOut: async()=>{} },
      landingStats: async()=>({ active_jobs:0, businesses:0, hired:0 }),
      notify: async()=>{}
    };
    window.GZ_READY = Promise.resolve(null);
    return;
  }

  const sb = window.supabase.createClient(cfg.supabaseUrl, cfg.supabaseAnonKey, {
    auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
  });

  let cachedProfile = null;

  async function loadProfile(){
    const { data: { session } } = await sb.auth.getSession();
    if(!session){ cachedProfile = null; return null; }
    const { data, error } = await sb.from('profiles').select('*').eq('id', session.user.id).maybeSingle();
    fail(error);
    cachedProfile = data;
    if(cachedProfile && cachedProfile.suspended){
      await sb.auth.signOut();
      cachedProfile = null;
      throw new Error('This account has been suspended. Contact GigZen admin.');
    }
    return cachedProfile;
  }

  const DB = {
    configured: true,
    uid, nowIso,
    client: sb,
    get profile(){ return cachedProfile; },
    setProfile(p){ cachedProfile = p; },

    auth: {
      async signIn(email, password){
        const { data, error } = await sb.auth.signInWithPassword({ email, password });
        if(error) throw new Error(error.message);
        const profile = await loadProfile();
        if(!profile) throw new Error('Profile is missing. Try signing up again.');
        return profile;
      },
      async signUp({ email, password, full_name, phone, location, role, business_name, business_category, business_city }){
        const { data, error } = await sb.auth.signUp({
          email, password,
          options: {
            data: {
              full_name, phone, location: location || business_city || '',
              role: role === 'employer' ? 'employer' : 'student',
              business_name: business_name || '',
              business_category: business_category || '',
              business_city: business_city || location || ''
            }
          }
        });
        if(error) throw new Error(error.message);
        if(!data.session){
          return { needsConfirmation: true, user: data.user };
        }
        const profile = await loadProfile();
        return { needsConfirmation: false, profile };
      },
      async signOut(){
        cachedProfile = null;
        await sb.auth.signOut();
      }
    },

    users: {
      async all(){
        const { data, error } = await sb.from('profiles').select('*').order('created_at', { ascending: false });
        fail(error); return data || [];
      },
      async find(id){
        if(!id) return null;
        const { data, error } = await sb.from('profiles').select('*').eq('id', id).maybeSingle();
        fail(error); return data;
      },
      async update(id, patch){
        const { data, error } = await sb.from('profiles').update(patch).eq('id', id).select().single();
        fail(error);
        if(cachedProfile && cachedProfile.id === id) cachedProfile = { ...cachedProfile, ...data };
        return data;
      }
    },

    students: {
      async all(){
        const { data, error } = await sb.from('student_profiles').select('*');
        fail(error); return data || [];
      },
      async byUser(userId){
        const { data, error } = await sb.from('student_profiles').select('*').eq('user_id', userId).maybeSingle();
        fail(error); return data;
      },
      async upsert(userId, patch){
        const existing = await this.byUser(userId);
        if(!existing){
          const { data, error } = await sb.from('student_profiles').insert({ user_id: userId, ...patch }).select().single();
          fail(error); return data;
        }
        const { data, error } = await sb.from('student_profiles').update(patch).eq('user_id', userId).select().single();
        fail(error); return data;
      }
    },

    businesses: {
      async all(){
        const { data, error } = await sb.from('businesses').select('*');
        fail(error); return data || [];
      },
      async find(id){
        const { data, error } = await sb.from('businesses').select('*').eq('id', id).maybeSingle();
        fail(error); return data;
      },
      async byOwner(ownerId){
        const { data, error } = await sb.from('businesses').select('*').eq('owner_id', ownerId).maybeSingle();
        fail(error); return data;
      },
      async insert(obj){
        const { id, created_at, updated_at, ...row } = obj;
        const { data, error } = await sb.from('businesses').insert(row).select().single();
        fail(error); return data;
      },
      async update(id, patch){
        const { data, error } = await sb.from('businesses').update(patch).eq('id', id).select().single();
        fail(error); return data;
      }
    },

    jobs: {
      async all(){
        const { data, error } = await sb.from('jobs').select('*').order('created_at', { ascending: false });
        fail(error); return data || [];
      },
      async find(id){
        const { data, error } = await sb.from('jobs').select('*').eq('id', id).maybeSingle();
        fail(error); return data;
      },
      async byBusiness(businessId){
        const { data, error } = await sb.from('jobs').select('*').eq('business_id', businessId).order('created_at', { ascending: false });
        fail(error); return data || [];
      },
      async insert(obj){
        const { id, created_at, updated_at, ...row } = obj;
        const { data, error } = await sb.from('jobs').insert(row).select().single();
        fail(error); return data;
      },
      async update(id, patch){
        const { data, error } = await sb.from('jobs').update(patch).eq('id', id).select().single();
        fail(error); return data;
      },
      async remove(id){
        const { error } = await sb.from('jobs').delete().eq('id', id);
        fail(error);
      }
    },

    applications: {
      async all(){
        const { data, error } = await sb.from('applications').select('*').order('applied_at', { ascending: false });
        fail(error); return data || [];
      },
      async find(id){
        const { data, error } = await sb.from('applications').select('*').eq('id', id).maybeSingle();
        fail(error); return data;
      },
      async byStudent(studentUserId){
        const { data, error } = await sb.from('applications').select('*').eq('student_id', studentUserId).order('applied_at', { ascending: false });
        fail(error); return data || [];
      },
      async byJob(jobId){
        const { data, error } = await sb.from('applications').select('*').eq('job_id', jobId).order('applied_at', { ascending: false });
        fail(error); return data || [];
      },
      async existing(jobId, studentUserId){
        const { data, error } = await sb.from('applications').select('*').eq('job_id', jobId).eq('student_id', studentUserId).maybeSingle();
        fail(error); return data;
      },
      async insert(obj){
        const { id, created_at, updated_at, applied_at, ...row } = obj;
        const { data, error } = await sb.from('applications').insert(row).select().single();
        fail(error); return data;
      },
      async update(id, patch){
        const { data, error } = await sb.from('applications').update(patch).eq('id', id).select().single();
        fail(error); return data;
      }
    },

    reports: {
      async all(){
        const { data, error } = await sb.from('reports').select('*').order('created_at', { ascending: false });
        fail(error); return data || [];
      },
      async insert(obj){
        const { id, created_at, ...row } = obj;
        const { data, error } = await sb.from('reports').insert(row).select().single();
        fail(error); return data;
      },
      async update(id, patch){
        if(patch.status === 'resolved') patch.resolved_at = nowIso();
        const { data, error } = await sb.from('reports').update(patch).eq('id', id).select().single();
        fail(error); return data;
      }
    },

    notifications: {
      async all(){
        const { data, error } = await sb.from('notifications').select('*').order('created_at', { ascending: false });
        fail(error); return data || [];
      },
      async byUser(userId){
        const { data, error } = await sb.from('notifications').select('*').eq('user_id', userId).order('created_at', { ascending: false });
        fail(error); return data || [];
      },
      async markRead(id){
        const { error } = await sb.from('notifications').update({ read: true }).eq('id', id);
        fail(error);
      }
    },

    async landingStats(){
      const { data, error } = await sb.rpc('landing_stats');
      fail(error);
      return data || { active_jobs: 0, businesses: 0, hired: 0 };
    },

    notify: async function(){ /* notifications are created by database triggers */ }
  };

  window.GZ_DB = DB;
  window.GZ_READY = loadProfile().catch(err => {
    console.error(err);
    return null;
  });
})();
