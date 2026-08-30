/* ==========================================================================
   GigZen — main.js
   Shared UI helpers: auth/session, navbar + sidebar, toasts, formatting.
   ========================================================================== */

(function(){
  const DB = window.GZ_DB;

  function currentUser(){
    return DB.profile || null;
  }

  async function logout(){
    await DB.auth.signOut();
    window.location.href = 'index.html';
  }

  async function requireRole(roles){
    await window.GZ_READY;
    const u = currentUser();
    if(!u || (roles && roles.length && !roles.includes(u.role))){
      window.location.href = 'login.html';
      return null;
    }
    return u;
  }

  function redirectForRole(role){
    if(role==='student') return 'student-dashboard.html';
    if(role==='employer') return 'employer-dashboard.html';
    if(role==='admin') return 'admin-dashboard.html';
    return 'index.html';
  }

  function escapeHtml(str){
    return String(str==null?'':str).replace(/[&<>"']/g, m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));
  }

  function initials(name){
    if(!name) return '?';
    return name.trim().split(/\s+/).slice(0,2).map(w=>w[0].toUpperCase()).join('');
  }

  function formatSalary(job){
    const amt = Number(job.salary||0).toLocaleString('en-IN');
    const per = job.salary_type==='month' ? '/month' : job.salary_type==='day' ? '/day' : job.salary_type==='hour' ? '/hour' : '';
    return '\u20B9' + amt + per;
  }

  function timeAgo(iso){
    const diff = Date.now() - new Date(iso).getTime();
    const mins = Math.floor(diff/60000);
    if(mins < 1) return 'just now';
    if(mins < 60) return mins + 'm ago';
    const hrs = Math.floor(mins/60);
    if(hrs < 24) return hrs + 'h ago';
    const days = Math.floor(hrs/24);
    if(days < 30) return days + 'd ago';
    return new Date(iso).toLocaleDateString('en-IN', { day:'numeric', month:'short', year:'numeric' });
  }

  function formatDate(iso){
    if(!iso) return '\u2014';
    return new Date(iso).toLocaleDateString('en-IN', { day:'numeric', month:'short', year:'numeric' });
  }

  function badge(status){
    const cls = 'badge-' + String(status||'').toLowerCase().replace(/\s+/g,'-');
    return '<span class="badge ' + cls + '">' + escapeHtml(status) + '</span>';
  }

  function ensureToastWrap(){
    let wrap = document.querySelector('.toast-wrap');
    if(!wrap){ wrap = document.createElement('div'); wrap.className='toast-wrap'; document.body.appendChild(wrap); }
    return wrap;
  }
  function toast(message, type){
    const wrap = ensureToastWrap();
    const el = document.createElement('div');
    el.className = 'toast' + (type ? ' '+type : '');
    el.textContent = message;
    wrap.appendChild(el);
    setTimeout(()=>{ el.style.opacity='0'; el.style.transition='opacity .25s ease'; setTimeout(()=>el.remove(), 260); }, 3200);
  }

  function openModal(id){ const m = document.getElementById(id); if(m) m.classList.add('open'); }
  function closeModal(id){ const m = document.getElementById(id); if(m) m.classList.remove('open'); }

  function showConfigBanner(){
    if(DB.configured) return;
    if(document.getElementById('gz-config-banner')) return;
    const el = document.createElement('div');
    el.id = 'gz-config-banner';
    el.style.cssText = 'background:#3b1d0a;color:#ffd9a8;padding:10px 16px;font-size:.85rem;text-align:center;position:relative;z-index:200;';
    el.innerHTML = 'Supabase is not configured. Add your project URL and anon key in <code>js/config.js</code>.';
    document.body.prepend(el);
  }

  const ICONS = {
    home:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>',
    search:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>',
    briefcase:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="7" width="20" height="14" rx="2"/><path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/></svg>',
    user:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>',
    plus:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>',
    list:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/></svg>',
    people:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
    grid:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/></svg>',
    flag:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"/><line x1="4" y1="22" x2="4" y2="15"/></svg>',
    bell:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>',
    logout:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>',
    menu:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="3" y1="12" x2="21" y2="12"/><line x1="3" y1="6" x2="21" y2="6"/><line x1="3" y1="18" x2="21" y2="18"/></svg>',
    empty:'<svg width="52" height="52" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><rect x="3" y="7" width="18" height="13" rx="2"/><path d="M16 7V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2"/><line x1="3" y1="12" x2="21" y2="12"/></svg>'
  };

  function publicNavLinks(){
    return [
      {href:'jobs.html', key:'jobs', label:'Find Jobs'},
    ];
  }

  function mountNav(activeKey){
    showConfigBanner();
    const host = document.getElementById('gz-nav');
    if(!host) return;
    const u = currentUser();
    let linksHtml = '';
    let actionsHtml = '';

    if(!u){
      linksHtml = publicNavLinks().map(l=>`<a class="nav-link ${activeKey===l.key?'active':''}" href="${l.href}">${l.label}</a>`).join('');
      actionsHtml = `<a class="btn btn-ghost btn-sm" href="login.html">Log in</a><a class="btn btn-primary btn-sm" href="signup.html">Get started</a>`;
    } else {
      const dash = redirectForRole(u.role);
      const dashLabel = u.role==='student' ? 'Dashboard' : u.role==='employer' ? 'Dashboard' : 'Admin';
      linksHtml = `<a class="nav-link ${activeKey==='jobs'?'active':''}" href="jobs.html">Find Jobs</a>
        <a class="nav-link ${activeKey==='dashboard'?'active':''}" href="${dash}">${dashLabel}</a>`;
      actionsHtml = `
        <div style="position:relative">
          <div class="avatar-chip" id="gz-user-chip">
            <span class="avatar-dot">${initials(u.full_name)}</span>
            <span class="menu-name">${escapeHtml(u.full_name.split(' ')[0])}</span>
          </div>
          <div class="card" id="gz-user-menu" style="display:none;position:absolute;right:0;top:44px;min-width:180px;padding:8px;z-index:80;">
            <a class="side-link" style="color:var(--ink);" href="${dash}">${ICONS.grid} Dashboard</a>
            <a class="side-link" style="color:var(--ink);" id="gz-logout-link" href="#">${ICONS.logout} Log out</a>
          </div>
        </div>`;
    }

    host.innerHTML = `
      <div class="nav">
        <div class="nav-inner">
          <a class="brand" href="${u?redirectForRole(u.role):'index.html'}"><span class="brand-mark">G</span>GigZen</a>
          <button class="nav-toggle" id="gz-nav-toggle" aria-label="Menu">${ICONS.menu}</button>
          <div class="nav-links" id="gz-nav-links">${linksHtml}</div>
          <div class="nav-actions">${actionsHtml}</div>
        </div>
      </div>`;

    const toggle = document.getElementById('gz-nav-toggle');
    const links = document.getElementById('gz-nav-links');
    if(toggle) toggle.addEventListener('click', ()=> links.classList.toggle('open'));

    const chip = document.getElementById('gz-user-chip');
    const menu = document.getElementById('gz-user-menu');
    if(chip){
      chip.addEventListener('click', (e)=>{ e.stopPropagation(); menu.style.display = menu.style.display==='none' ? 'block' : 'none'; });
      document.addEventListener('click', ()=>{ menu.style.display='none'; });
    }
    const out = document.getElementById('gz-logout-link');
    if(out) out.addEventListener('click', (e)=>{ e.preventDefault(); logout(); });
  }

  const SIDEBARS = {
    student:[
      {href:'student-dashboard.html', key:'dashboard', label:'Dashboard', icon:'grid'},
      {href:'jobs.html', key:'jobs', label:'Find Jobs', icon:'search'},
      {href:'applications.html', key:'applications', label:'My Applications', icon:'list'},
      {href:'profile.html', key:'profile', label:'My Profile', icon:'user'}
    ],
    employer:[
      {href:'employer-dashboard.html', key:'dashboard', label:'Dashboard', icon:'grid'},
      {href:'post-job.html', key:'post', label:'Post a Job', icon:'plus'},
      {href:'manage-jobs.html', key:'manage', label:'Manage Jobs', icon:'briefcase'},
      {href:'employer-profile.html', key:'profile', label:'Business Profile', icon:'user'}
    ],
    admin:[
      {href:'admin-dashboard.html', key:'dashboard', label:'Overview', icon:'grid'},
      {href:'admin-users.html', key:'users', label:'Students & Employers', icon:'people'},
      {href:'admin-jobs.html', key:'jobs', label:'Jobs', icon:'briefcase'},
      {href:'admin-applications.html', key:'applications', label:'Applications', icon:'list'},
      {href:'admin-reports.html', key:'reports', label:'Reports', icon:'flag'}
    ]
  };

  function mountSidebar(role, activeKey){
    const host = document.getElementById('gz-sidebar');
    if(!host) return;
    const items = SIDEBARS[role] || [];
    host.innerHTML = `
      <div class="sidebar-backdrop" id="gz-sb-backdrop"></div>
      <aside class="sidebar" id="gz-sidebar-el">
        <div class="sidebar-group">
          <div class="sidebar-label">${role==='admin'?'Admin':role==='employer'?'Employer':'Student'}</div>
          ${items.map(i=>`<a class="side-link ${activeKey===i.key?'active':''}" href="${i.href}">${ICONS[i.icon]||''}<span>${i.label}</span></a>`).join('')}
        </div>
      </aside>`;
    const toggle = document.getElementById('gz-nav-toggle');
    const sb = document.getElementById('gz-sidebar-el');
    const backdrop = document.getElementById('gz-sb-backdrop');
    if(toggle && sb){
      toggle.addEventListener('click', ()=>{ sb.classList.toggle('open'); backdrop.classList.toggle('open'); });
      backdrop.addEventListener('click', ()=>{ sb.classList.remove('open'); backdrop.classList.remove('open'); });
    }
  }

  function emptyState(title, sub, iconKey){
    return `<div class="empty">${ICONS[iconKey||'empty']}<h3>${escapeHtml(title)}</h3><p>${escapeHtml(sub||'')}</p></div>`;
  }

  window.GZ = {
    ICONS, currentUser, logout, requireRole, redirectForRole,
    escapeHtml, initials, formatSalary, timeAgo, formatDate, badge,
    toast, openModal, closeModal, mountNav, mountSidebar, emptyState,
    uid: DB.uid, db: DB,
    boot(fn){
      window.GZ_READY.then(fn).catch(err=>{
        console.error(err);
        toast(err.message || 'Something went wrong', 'error');
      });
    }
  };
})();
