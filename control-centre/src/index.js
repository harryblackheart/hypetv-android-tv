const VERSION = '1.5.4';
const enc = new TextEncoder();
const dec = new TextDecoder();

const json = (data, status = 200) => new Response(JSON.stringify(data), {
  status,
  headers: {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff'
  }
});
const errorJson = (code, message, status = 400) => json({ success: false, code, message }, status);
const clean = (v, max = 500) => String(v ?? '').trim().slice(0, max);
const int = (v, fallback = 0, min = 0, max = 100000) => {
  const n = Number.parseInt(v, 10);
  return Number.isFinite(n) ? Math.min(max, Math.max(min, n)) : fallback;
};
const nowIso = () => new Date().toISOString();
const expired = (value) => value ? new Date(value).getTime() < Date.now() : false;
const b64url = bytes => btoa(String.fromCharCode(...new Uint8Array(bytes))).replaceAll('+','-').replaceAll('/','_').replaceAll('=','');

async function sha256(value) {
  return b64url(await crypto.subtle.digest('SHA-256', enc.encode(value)));
}
async function hmac(secret, input) {
  const key = await crypto.subtle.importKey('raw', enc.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return b64url(await crypto.subtle.sign('HMAC', key, enc.encode(input)));
}
async function makeAdminToken(secret) {
  const payload = b64url(enc.encode(JSON.stringify({ exp: Date.now() + 12 * 60 * 60 * 1000 })));
  return `${payload}.${await hmac(secret, payload)}`;
}
async function validAdminToken(secret, token) {
  if (!secret || !token || !token.includes('.')) return false;
  const [payload, sig] = token.split('.');
  if ((await hmac(secret, payload)) !== sig) return false;
  try {
    const padded = payload.replaceAll('-','+').replaceAll('_','/') + '='.repeat((4 - payload.length % 4) % 4);
    return JSON.parse(dec.decode(Uint8Array.from(atob(padded), c => c.charCodeAt(0)))).exp > Date.now();
  } catch { return false; }
}
async function requireAdmin(request, env) {
  const token = request.headers.get('authorization')?.replace(/^Bearer\s+/i, '');
  return validAdminToken(env.ADMIN_PASSWORD || '', token);
}
async function readBody(request) {
  try { return await request.json(); } catch { return {}; }
}
function randomToken(bytes = 32) {
  const value = new Uint8Array(bytes);
  crypto.getRandomValues(value);
  return b64url(value);
}
function secureFiveDigitCode() {
  const max = 0x100000000;
  const limit = max - (max % 90000);
  const a = new Uint32Array(1);
  do crypto.getRandomValues(a); while (a[0] >= limit);
  return String(10000 + (a[0] % 90000));
}
function clientKey(request) {
  return request.headers.get('cf-connecting-ip') || 'unknown';
}
async function rateLimit(env, bucket, max, seconds) {
  const t = Math.floor(Date.now() / 1000);
  const row = await env.HYPETV_DB.prepare('SELECT count,window_start FROM rate_limits WHERE bucket=?').bind(bucket).first();
  if (!row || t - row.window_start >= seconds) {
    await env.HYPETV_DB.prepare('INSERT INTO rate_limits(bucket,count,window_start) VALUES(?,1,?) ON CONFLICT(bucket) DO UPDATE SET count=1,window_start=excluded.window_start').bind(bucket,t).run();
    return true;
  }
  if (row.count >= max) return false;
  await env.HYPETV_DB.prepare('UPDATE rate_limits SET count=count+1 WHERE bucket=?').bind(bucket).run();
  return true;
}
async function settings(env) {
  const rows = await env.HYPETV_DB.prepare("SELECT key,value FROM settings WHERE key LIKE 'maintenance_%'").all();
  return Object.fromEntries((rows.results || []).map(x => [x.key, x.value]));
}
async function deviceFromRequest(request, env) {
  const raw = request.headers.get('authorization')?.replace(/^Bearer\s+/i, '');
  if (!raw) return null;
  const hash = await sha256(raw);
  return env.HYPETV_DB.prepare(`SELECT d.*,c.name AS customer_name,c.status AS customer_status,c.expires_at AS customer_expires_at,c.content_access AS customer_content_access,c.connection_allowance,COALESCE(c.device_limit,3) AS device_limit,c.service_username AS customer_username
    FROM devices d JOIN customers c ON c.id=d.customer_id WHERE d.token_hash=?`).bind(hash).first();
}




function decodeB64url(value) {
  const padded = String(value).replaceAll('-','+').replaceAll('_','/') + '='.repeat((4 - String(value).length % 4) % 4);
  return Uint8Array.from(atob(padded), c => c.charCodeAt(0));
}
async function credentialKey(env) {
  if (!env.STREAM_CREDENTIAL_KEY) throw new Error('STREAM_CREDENTIAL_KEY is not configured');
  const raw = await crypto.subtle.digest('SHA-256', enc.encode(env.STREAM_CREDENTIAL_KEY));
  return crypto.subtle.importKey('raw', raw, { name:'AES-GCM' }, false, ['encrypt','decrypt']);
}
async function encryptCredential(value, env) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const cipher = await crypto.subtle.encrypt({ name:'AES-GCM', iv }, await credentialKey(env), enc.encode(String(value)));
  return { ciphertext:b64url(cipher), iv:b64url(iv) };
}
async function decryptCredential(ciphertext, iv, env) {
  const plain = await crypto.subtle.decrypt({ name:'AES-GCM', iv:decodeB64url(iv) }, await credentialKey(env), decodeB64url(ciphertext));
  return dec.decode(plain);
}
function publicSource(row) {
  if (!row) return null;
  return { id:String(row.id), customer_id:String(row.customer_id), source_type:row.source_type, display_name:row.display_name, base_url:row.base_url, username:'••••••••', password:'••••••••', output_format:row.output_format, user_agent:row.user_agent, is_enabled:Boolean(row.is_enabled), last_tested_at:row.last_tested_at, last_test_status:row.last_test_status, last_test_message:row.last_test_message };
}
async function sourceForCustomer(customerId, env) {
  const row = await env.HYPETV_DB.prepare('SELECT * FROM streaming_sources WHERE customer_id=? AND is_enabled=1 ORDER BY id DESC LIMIT 1').bind(customerId).first();
  if (row) {
    const presetRows=await env.HYPETV_DB.prepare('SELECT base_url FROM streaming_source_presets WHERE active=1 ORDER BY id').all();
    const candidate_urls=[row.base_url,...(presetRows.results||[]).map(x=>x.base_url)].filter((x,i,a)=>x&&a.indexOf(x)===i);
    return { ...row, service_url:row.base_url, candidate_urls, service_username:await decryptCredential(row.username_ciphertext,row.username_iv,env), service_password:await decryptCredential(row.password_ciphertext,row.password_iv,env), service_output:row.output_format };
  }
  const legacy = await env.HYPETV_DB.prepare('SELECT id,service_url,service_username,service_password,service_output FROM customers WHERE id=?').bind(customerId).first();
  if (legacy?.service_url && legacy?.service_username && legacy?.service_password) return { id:0, customer_id:customerId, base_url:legacy.service_url, service_url:legacy.service_url, service_username:legacy.service_username, service_password:legacy.service_password, service_output:legacy.service_output||'m3u8', output_format:legacy.service_output||'m3u8', user_agent:'HypeTV', is_enabled:1, legacy:true };
  return null;
}
function safeSourceUrl(value, allowPrivate=false) {
  const normalized = normaliseServiceUrl(value);
  if (allowPrivate) return normalized;
  return normalized;
}
function upstreamError(err) {
  if (err?.name === 'AbortError') return ['SOURCE_TIMEOUT','The streaming source timed out.',504];
  if (/invalid JSON/i.test(err?.message||'')) return ['SOURCE_BAD_RESPONSE','The streaming source returned an invalid response.',502];
  return ['SOURCE_UNAVAILABLE','The streaming source is temporarily unavailable.',502];
}

function contentAccess(value) {
  return ['hype_only','hype_plus_premium','premium_only'].includes(value) ? value : 'hype_only';
}
function hasHypeAccess(value) { return contentAccess(value) !== 'premium_only'; }
function hasPremiumAccess(value) { return contentAccess(value) !== 'hype_only'; }
async function premiumizeApiKey(env) {
  const rows = await env.HYPETV_DB.prepare("SELECT key,value FROM settings WHERE key IN ('premiumize_key_ciphertext','premiumize_key_iv')").all();
  const cfg = Object.fromEntries((rows.results||[]).map(x=>[x.key,x.value]));
  if (cfg.premiumize_key_ciphertext && cfg.premiumize_key_iv) return decryptCredential(cfg.premiumize_key_ciphertext,cfg.premiumize_key_iv,env);
  if (env.PREMIUMIZE_API_KEY) return env.PREMIUMIZE_API_KEY;
  throw new Error('PREMIUMIZE_API_KEY is not configured');
}
async function premiumizeHeaders(env) {
  const key = await premiumizeApiKey(env);
  return { 'accept':'application/json', 'authorization':`Bearer ${key}` };
}
async function premiumizeJson(env, path, params={}) {
  const u = new URL(`https://www.premiumize.me${path}`);
  for (const [k,v] of Object.entries(params)) if (v !== undefined && v !== null && String(v) !== '') u.searchParams.set(k,String(v));
  const controller = new AbortController();
  const timer = setTimeout(()=>controller.abort(),12000);
  try {
    const r = await fetch(u,{headers:await premiumizeHeaders(env),signal:controller.signal,redirect:'follow'});
    const text = await r.text();
    let body={};
    try { body=JSON.parse(text); } catch { throw new Error('Premiumize returned invalid JSON'); }
    if (!r.ok || body?.status === 'error') {
      const err = new Error(clean(body?.message || `Premiumize returned HTTP ${r.status}`,300));
      err.publicCode = clean(body?.code,80) || 'PREMIUMIZE_ERROR';
      throw err;
    }
    return body;
  } finally { clearTimeout(timer); }
}
function premiumizeError(err) {
  if (err?.name === 'AbortError') return errorJson('PREMIUMIZE_TIMEOUT','Premium VOD timed out. Please try again.',504);
  if (/not configured/i.test(err?.message||'')) return errorJson('PREMIUMIZE_NOT_CONFIGURED','Premium VOD is not configured.',503);
  console.error(JSON.stringify({event:'premiumize_error',message:clean(err?.message,300),code:clean(err?.publicCode,80)}));
  return errorJson('PREMIUMIZE_UNAVAILABLE','Premium VOD is temporarily unavailable.',502);
}
function premiumVideo(entry) {
  const mime=String(entry?.mime_type||'').toLowerCase();
  const name=String(entry?.name||'');
  return mime.startsWith('video/') || /\.(mkv|mp4|m4v|avi|mov|webm|ts|m2ts)$/i.test(name);
}
function safePremiumEntry(entry) {
  const isFolder=entry?.type === 'folder';
  return {
    id:String(entry?.id||''),
    name:String(entry?.name||''),
    type:isFolder?'folder':'file',
    created_at:Number(entry?.created_at||0)||null,
    size:isFolder?null:(Number(entry?.size||0)||null),
    mime_type:isFolder?null:(entry?.mime_type||null),
    playable:!isFolder && premiumVideo(entry)
  };
}
async function premiumContext(request,env) {
  const device=await deviceFromRequest(request,env);
  if (!device || device.disabled) return {error:errorJson('UNAUTHENTICATED','Authentication is required.',401)};
  if (device.customer_status !== 'active') return {error:errorJson('CUSTOMER_SUSPENDED','Customer account is suspended.',403)};
  if (expired(device.customer_expires_at)) return {error:errorJson('SUBSCRIPTION_EXPIRED','Subscription has expired.',403)};
  if (!hasPremiumAccess(device.customer_content_access)) return {error:errorJson('PREMIUM_VOD_NOT_INCLUDED','Premium VOD is not enabled for this account.',403)};
  const appVersion=clean(request.headers.get('x-app-version'),40);
  await env.HYPETV_DB.prepare("UPDATE devices SET last_seen=CURRENT_TIMESTAMP,app_version=COALESCE(NULLIF(?,''),app_version) WHERE id=?").bind(appVersion,device.id).run();
  return {device};
}

function normalItem(item, type) {
  const sourceId = String(item.stream_id ?? item.series_id ?? item.id ?? '');
  const yearRaw = item.year ?? item.releaseDate ?? item.release_date;
  const ratingRaw = item.rating ?? item.rating_5based;
  return {
    id:`${type}:${sourceId}`,
    source_id:sourceId,
    type,
    title:String(item.name ?? item.title ?? ''),
    subtitle:[item.genre,yearRaw].filter(Boolean).join(' · '),
    description:item.plot ?? item.description ?? '',
    poster_url:item.stream_icon ?? item.cover ?? item.movie_image ?? null,
    backdrop_url:Array.isArray(item.backdrop_path)?item.backdrop_path[0]:(item.backdrop_path ?? item.backdrop ?? null),
    rating:ratingRaw===null||ratingRaw===undefined?null:Number(ratingRaw)||null,
    year:yearRaw===null||yearRaw===undefined?null:Number.parseInt(yearRaw,10)||null,
    category_id:String(item.category_id ?? ''),
    is_adult:Boolean(Number(item.is_adult||0)),
    badge:null,
    container_extension:item.container_extension ?? null,
    added:item.added ?? null,
    catchup:Boolean(Number(item.tv_archive ?? item.catchup ?? item.has_catchup ?? 0)),
    catchup_days:Number.parseInt(item.tv_archive_duration ?? item.catchup_days ?? item.archive_days ?? 0,10)||0
  };
}
function categoryItem(item) { return { id:String(item.category_id ?? item.id ?? ''), name:String(item.category_name ?? item.name ?? '') }; }
async function cachedProvider(env, source, action, params={}, ttl=300) {
  const key = await sha256(JSON.stringify([source.id||0, action, params]));
  const now = Math.floor(Date.now()/1000);
  const hit = await env.HYPETV_DB.prepare('SELECT payload FROM catalogue_cache_v2 WHERE cache_key=? AND expires_at>?').bind(key,now).first();
  if (hit) return JSON.parse(hit.payload);
  const data = await upstreamJsonForSource(source,action,params);
  if (source.id) await env.HYPETV_DB.prepare(`INSERT INTO catalogue_cache_v2(cache_key,source_id,payload,expires_at) VALUES(?,?,?,?) ON CONFLICT(cache_key) DO UPDATE SET payload=excluded.payload,expires_at=excluded.expires_at,created_at=CURRENT_TIMESTAMP`).bind(key,source.id,JSON.stringify(data),now+ttl).run();
  return data;
}

async function cachedProviderLimited(env, source, action, params={}, ttl=120, limit=16) {
  const safeLimit = Math.max(1, Math.min(50, Number(limit) || 16));
  const key = await sha256(JSON.stringify([source.id||0, 'limited-v2', action, params, safeLimit]));
  const now = Math.floor(Date.now()/1000);
  const hit = await env.HYPETV_DB.prepare('SELECT payload FROM catalogue_cache_v2 WHERE cache_key=? AND expires_at>?').bind(key,now).first();
  if (hit) return JSON.parse(hit.payload);

  // Xtream-compatible servers do not consistently support page/limit parameters.
  // Some return an empty array when those parameters are supplied. Request the
  // normal endpoint and limit the already category-scoped result in the Worker.
  const raw = await upstreamJsonForSource(source,action,params);
  const data = Array.isArray(raw) ? raw.slice(0,safeLimit) : [];
  if (source.id) {
    await env.HYPETV_DB.prepare(`INSERT INTO catalogue_cache_v2(cache_key,source_id,payload,expires_at) VALUES(?,?,?,?) ON CONFLICT(cache_key) DO UPDATE SET payload=excluded.payload,expires_at=excluded.expires_at,created_at=CURRENT_TIMESTAMP`)
      .bind(key,source.id,JSON.stringify(data),now+ttl).run();
  }
  return data;
}

async function firstPopulatedCategory(env, source, categories, action, ttl=120, limit=12) {
  // Providers often place an empty or hidden category first. Try a few categories
  // and return the first one that actually contains visible catalogue items.
  for (const category of (Array.isArray(categories) ? categories.slice(0, 8) : [])) {
    const categoryId = String(category?.category_id ?? category?.id ?? '');
    if (!categoryId) continue;
    const items = await cachedProviderLimited(env, source, action, { category_id:categoryId }, ttl, limit);
    if (items.length) return items;
  }
  return [];
}
async function authenticatedContext(request, env, requireSource=true) {
  const device = await deviceFromRequest(request,env);
  if (!device) return { error:errorJson('UNAUTHENTICATED','Authentication is required.',401) };
  if (device.disabled) return { error:errorJson('DEVICE_BLOCKED','This device has been blocked.',403) };
  if (device.customer_status !== 'active') return { error:errorJson('CUSTOMER_SUSPENDED','Customer account is suspended.',403) };
  if (expired(device.customer_expires_at)) return { error:errorJson('SUBSCRIPTION_EXPIRED','Subscription has expired.',403) };
  const appVersion=clean(request.headers.get('x-app-version'),40);
  await env.HYPETV_DB.prepare("UPDATE devices SET last_seen=CURRENT_TIMESTAMP,app_version=COALESCE(NULLIF(?,''),app_version) WHERE id=?").bind(appVersion,device.id).run();
  const source = await sourceForCustomer(device.customer_id,env);
  if (requireSource && !source) return { error:errorJson('SOURCE_NOT_CONFIGURED','No streaming source has been configured for this account.',409) };
  if (requireSource && !source.is_enabled) return { error:errorJson('SOURCE_DISABLED','The streaming source is disabled.',409) };
  return { device, source };
}

function normaliseServiceUrl(value) {
  const raw = clean(value, 500).replace(/\/+$/, '');
  if (!raw) return '';
  const u = new URL(raw.includes('://') ? raw : `http://${raw}`);
  if (!['http:', 'https:'].includes(u.protocol)) throw new Error('Unsupported service URL');
  const h = u.hostname.toLowerCase();
  const privateHost = h === 'localhost' || h === '::1' || h.startsWith('127.') || h.startsWith('10.') || h.startsWith('192.168.') || h.startsWith('169.254.') || /^172\.(1[6-9]|2\d|3[01])\./.test(h);
  if (privateHost) throw new Error('Private service addresses are not allowed');
  return u.origin + u.pathname.replace(/\/$/, '');
}

// Source-preset URLs use the same validation/normalisation rules as customer service URLs.
// This alias fixes the Settings save path, which previously called an undefined helper.
function normaliseBaseUrl(value) { return normaliseServiceUrl(value); }
async function loadServiceForDevice(device, env) { return sourceForCustomer(device.customer_id,env); }
function xtreamUrl(service, action, params={}) {
  const u = new URL(`${normaliseServiceUrl(service.service_url)}/player_api.php`);
  u.searchParams.set('username', service.service_username || '');
  u.searchParams.set('password', service.service_password || '');
  if (action) u.searchParams.set('action', action);
  for (const [k,v] of Object.entries(params)) if (v !== undefined && v !== null && String(v) !== '') u.searchParams.set(k,String(v));
  return u;
}
async function upstreamJsonForSource(source, action, params={}, timeoutMs=15000) {
  const candidates=(source.candidate_urls?.length?source.candidate_urls:[source.service_url]).filter(Boolean);
  let lastError=null;
  for (const base of candidates) {
    try {
      const data=await upstreamJson(xtreamUrl({...source,service_url:base},action,params),timeoutMs);
      source.service_url=base;
      return data;
    } catch(e) { lastError=e; }
  }
  throw lastError||new Error('No streaming servers are configured');
}
async function upstreamCount(url, needle, timeoutMs=30000) {
  const controller = new AbortController();
  const timer = setTimeout(()=>controller.abort(), timeoutMs);
  try {
    const r = await fetch(url, { signal:controller.signal, redirect:'follow', headers:{'accept':'application/json'} });
    if (!r.ok) {
      const err = new Error(`Upstream returned HTTP ${r.status}`);
      err.upstreamStatus = r.status;
      throw err;
    }
    if (!r.body) return 0;
    const reader = r.body.getReader();
    const decoder = new TextDecoder();
    let carry = '';
    let count = 0;
    const token = `"${needle}"`;
    while (true) {
      const {value, done} = await reader.read();
      const text = carry + decoder.decode(value || new Uint8Array(), {stream:!done});
      let pos = 0;
      while ((pos = text.indexOf(token, pos)) !== -1) { count++; pos += token.length; }
      carry = text.slice(Math.max(0, text.length - token.length));
      if (done) break;
    }
    return count;
  } finally { clearTimeout(timer); }
}

async function upstreamJson(url, timeoutMs=15000) {
  async function attempt(headers) {
    const controller = new AbortController();
    const timer = setTimeout(()=>controller.abort(), timeoutMs);
    try {
      const r = await fetch(url, { signal: controller.signal, redirect:'follow', headers });
      const text = await r.text();
      if (!r.ok) {
        const err = new Error(`Upstream returned HTTP ${r.status}`);
        err.upstreamStatus = r.status;
        err.upstreamBody = text.slice(0, 200);
        throw err;
      }
      try { return JSON.parse(text); } catch {
        const err = new Error('Upstream returned invalid JSON');
        err.upstreamBody = text.slice(0, 200);
        throw err;
      }
    } finally { clearTimeout(timer); }
  }
  try {
    return await attempt({ 'accept':'application/json', 'user-agent':'HypeTV-Control-Centre/1.3.1' });
  } catch (firstError) {
    if (firstError?.name === 'AbortError' || firstError?.upstreamStatus === 401 || firstError?.upstreamStatus === 404) throw firstError;
    try {
      return await attempt({ 'accept':'application/json' });
    } catch (secondError) {
      secondError.firstAttemptMessage = firstError?.message || '';
      throw secondError;
    }
  }
}
async function cachedXtream(env, service, action, params={}, ttl=300) {
  const key = await sha256(JSON.stringify([service.service_url,service.service_username,action,params]));
  const now = Math.floor(Date.now()/1000);
  const hit = await env.HYPETV_DB.prepare('SELECT payload FROM catalogue_cache WHERE cache_key=? AND expires_at>?').bind(key,now).first();
  if (hit) return JSON.parse(hit.payload);
  const data = await upstreamJson(xtreamUrl(service,action,params));
  await env.HYPETV_DB.prepare(`INSERT INTO catalogue_cache(cache_key,payload,expires_at) VALUES(?,?,?) ON CONFLICT(cache_key) DO UPDATE SET payload=excluded.payload,expires_at=excluded.expires_at,created_at=CURRENT_TIMESTAMP`).bind(key,JSON.stringify(data),now+ttl).run();
  return data;
}
async function requireAppDevice(request, env) {
  const device = await deviceFromRequest(request,env);
  if (!device || device.disabled) return { error:errorJson('DEVICE_BLOCKED','Invalid or revoked device token',401) };
  if (device.customer_status !== 'active') return { error:errorJson('CUSTOMER_SUSPENDED','Customer account is suspended',403) };
  if (expired(device.customer_expires_at)) return { error:errorJson('SUBSCRIPTION_EXPIRED','Subscription has expired',403) };
  const service = await loadServiceForDevice(device,env);
  if (!service?.service_url || !service?.service_username || !service?.service_password) return { error:errorJson('SERVICE_NOT_CONFIGURED','Streaming service is not configured',409) };
  return {device,service};
}
function mapStream(item, kind) {
  const id = String(item.stream_id ?? item.series_id ?? item.id ?? '');
  return {
    id,
    name:item.name || item.title || '',
    category_id:String(item.category_id ?? ''),
    poster:item.stream_icon || item.cover || item.movie_image || null,
    backdrop:item.backdrop_path || item.backdrop || null,
    rating:item.rating || item.rating_5based || null,
    year:item.year || item.releaseDate || item.release_date || null,
    plot:item.plot || item.description || null,
    added:item.added || null,
    container_extension:item.container_extension || null,
    kind,
    playback_path: kind==='live' ? `/api/app/play/live/${encodeURIComponent(id)}` : kind==='movie' ? `/api/app/play/movie/${encodeURIComponent(id)}` : null
  };
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    try {
      if (!url.pathname.startsWith('/api/')) return env.ASSETS.fetch(request);
      if (url.pathname === '/api/health') return json({ ok: true, version: VERSION });

      if (url.pathname === '/api/login' && request.method === 'POST') {
        if (!(await rateLimit(env, `login:${clientKey(request)}`, 8, 900))) return errorJson('RATE_LIMITED','Too many login attempts',429);
        const d = await readBody(request);
        if (!env.ADMIN_PASSWORD) return errorJson('SERVER_ERROR','Admin login is not configured',503);
        if (clean(d.password,200) !== env.ADMIN_PASSWORD) return errorJson('INVALID_LOGIN','Incorrect password',401);
        return json({ success:true, token: await makeAdminToken(env.ADMIN_PASSWORD) });
      }

      if (url.pathname === '/api/activate' && request.method === 'POST') {
        if (!(await rateLimit(env, `activate:${clientKey(request)}`, 30, 900))) return errorJson('RATE_LIMITED','Too many activation attempts',429);
        const d = await readBody(request);
        const code = clean(d.code,5);
        const deviceId = clean(d.device_id,200);
        const platform = clean(d.platform || 'android_tv',80);
        const deviceName = clean(d.device_name || 'HypeTV Device',120);
        const appVersion = clean(d.app_version,40);
        if (!/^\d{5}$/.test(code) || !deviceId) return errorJson('INVALID_CODE','Invalid activation code',400);

        const row = await env.HYPETV_DB.prepare(`SELECT a.*,c.name,c.status,c.expires_at AS customer_expires_at,c.connection_allowance,c.service_url,c.service_username,c.service_password,c.content_access
          FROM activation_codes a JOIN customers c ON c.id=a.customer_id WHERE a.code=?`).bind(code).first();
        if (!row || row.revoked) return errorJson('INVALID_CODE','Invalid activation code',404);
        if (expired(row.expires_at)) return errorJson('CODE_EXPIRED','Activation code has expired',410);
        if (row.status !== 'active') return errorJson('CUSTOMER_SUSPENDED','Customer account is suspended',403);
        if (expired(row.customer_expires_at)) return errorJson('SUBSCRIPTION_EXPIRED','Subscription has expired',403);

        let existing = await env.HYPETV_DB.prepare('SELECT * FROM devices WHERE device_id=?').bind(deviceId).first();
        if (existing && Number(existing.customer_id) !== Number(row.customer_id)) {
          console.warn(JSON.stringify({event:'activation_rejected',reason:'device_linked_elsewhere',device_db_id:existing.id,existing_customer_id:existing.customer_id,requested_customer_id:row.customer_id}));
          return errorJson('DEVICE_BLOCKED','This device is already linked to another customer',403);
        }
        if (existing && existing.disabled) {
          await env.HYPETV_DB.batch([
            env.HYPETV_DB.prepare('DELETE FROM message_receipts WHERE device_id=?').bind(existing.id),
            env.HYPETV_DB.prepare('DELETE FROM messages WHERE target_device_id=?').bind(existing.id),
            env.HYPETV_DB.prepare('DELETE FROM devices WHERE id=?').bind(existing.id)
          ]);
          existing = null;
        }
        if (Number(row.uses || 0) >= Number(row.max_uses || 1) && !existing) {
          return errorJson('CODE_EXPIRED','Activation code has already been used',410);
        }

        const rawToken = randomToken();
        const tokenHash = await sha256(rawToken);
        let device;
        if (existing) {
          await env.HYPETV_DB.prepare(`UPDATE devices SET token_hash=?,device_name=?,platform=?,app_version=?,last_seen=CURRENT_TIMESTAMP,status='active' WHERE id=?`)
            .bind(tokenHash,deviceName,platform,appVersion,existing.id).run();
          device = { ...existing, device_name: deviceName, platform, app_version: appVersion };
        } else {
          const insert = await env.HYPETV_DB.prepare(`INSERT INTO devices(customer_id,device_id,device_name,platform,app_version,token_hash)
            SELECT ?,?,?,?,?,? WHERE (SELECT COUNT(*) FROM devices WHERE customer_id=? AND disabled=0 AND revoked_at IS NULL) < (SELECT COALESCE(device_limit,3) FROM customers WHERE id=?)`)
            .bind(row.customer_id,deviceId,deviceName,platform,appVersion,tokenHash,row.customer_id,row.customer_id).run();
          if (!insert.meta.changes) return errorJson('DEVICE_LIMIT_REACHED','Device limit reached',403);
          device = await env.HYPETV_DB.prepare('SELECT * FROM devices WHERE device_id=?').bind(deviceId).first();
          await env.HYPETV_DB.prepare('UPDATE activation_codes SET uses=uses+1 WHERE id=? AND uses < max_uses').bind(row.id).run();
        }
        return json({
          success:true,
          token:rawToken,
          customer:{ id:String(row.customer_id), name:row.name, expires_at:row.customer_expires_at },
          device:{ id:String(device.id), name:device.device_name },
          service:{ configured:Boolean(row.service_url && row.service_username && row.service_password) },
          entitlements:{ hype_catalogue:hasHypeAccess(row.content_access), premium_vod:hasPremiumAccess(row.content_access), mode:contentAccess(row.content_access) }
        });
      }

      if (url.pathname === '/api/app/bootstrap' && request.method === 'GET') {
        const device = await deviceFromRequest(request,env);
        if (!device || device.disabled) return errorJson('DEVICE_BLOCKED','Invalid or revoked device token',401);
        if (device.customer_status !== 'active') return errorJson('CUSTOMER_SUSPENDED','Customer account is suspended',403);
        if (expired(device.customer_expires_at)) return errorJson('SUBSCRIPTION_EXPIRED','Subscription has expired',403);
        const appVersion = clean(request.headers.get('x-app-version'),40);
        await env.HYPETV_DB.prepare('UPDATE devices SET last_seen=CURRENT_TIMESTAMP,app_version=COALESCE(NULLIF(?,\'\'),app_version) WHERE id=?').bind(appVersion,device.id).run();
        const s = await settings(env);
        const messages = await env.HYPETV_DB.prepare(`SELECT m.id,m.title,m.message,m.priority,m.created_at,m.expires_at
          FROM messages m LEFT JOIN message_receipts r ON r.message_id=m.id AND r.device_id=?
          WHERE m.active=1 AND (m.expires_at IS NULL OR datetime(m.expires_at)>datetime('now')) AND r.read_at IS NULL
          AND (m.target_type='everyone' OR (m.target_type='customer' AND m.target_customer_id=?) OR (m.target_type='device' AND m.target_device_id=?))
          ORDER BY CASE m.priority WHEN 'critical' THEN 3 WHEN 'important' THEN 2 ELSE 1 END DESC,m.id DESC`).bind(device.id,device.customer_id,device.id).all();
        for (const m of messages.results || []) await env.HYPETV_DB.prepare('INSERT OR IGNORE INTO message_receipts(message_id,device_id,delivered_at) VALUES(?,?,CURRENT_TIMESTAMP)').bind(m.id,device.id).run();
        return json({
          success:true,
          maintenance:{ enabled:s.maintenance_enabled==='true', message:s.maintenance_message||null, estimated_return:s.maintenance_estimated_return||null },
          messages:messages.results || [],
          customer:{ id:String(device.customer_id), name:device.customer_name, expires_at:device.customer_expires_at },
          device:{ id:String(device.id), name:device.device_name, platform:device.platform||'', model:device.model||'', app_version:device.app_version||'', device_limit:Number(device.device_limit||3) },
          entitlements:{ hype_catalogue:hasHypeAccess(device.customer_content_access), premium_vod:hasPremiumAccess(device.customer_content_access), mode:contentAccess(device.customer_content_access) }
        });
      }


      // Device registry: the app reports local metadata and receives the owner-controlled friendly name.
      if (url.pathname === '/api/app/device' && request.method === 'GET') {
        const device=await deviceFromRequest(request,env);
        if(!device || device.disabled || device.revoked_at) return errorJson('DEVICE_REVOKED','This device has been unlinked.',401);
        return json({success:true,device:{id:String(device.id),name:device.device_name,platform:device.platform||'',model:device.model||'',os_version:device.os_version||'',app_version:device.app_version||'',active_profile_id:device.active_profile_id||''},account:{id:String(device.customer_id),name:device.customer_name,username:device.customer_username||'',device_limit:Number(device.device_limit||3)}});
      }
      if (url.pathname === '/api/app/device' && request.method === 'PUT') {
        const device=await deviceFromRequest(request,env);
        if(!device || device.disabled || device.revoked_at) return errorJson('DEVICE_REVOKED','This device has been unlinked.',401);
        const d=await readBody(request);
        await env.HYPETV_DB.prepare(`UPDATE devices SET platform=COALESCE(NULLIF(?,''),platform),model=COALESCE(NULLIF(?,''),model),os_version=COALESCE(NULLIF(?,''),os_version),app_version=COALESCE(NULLIF(?,''),app_version),active_profile_id=?,last_seen=CURRENT_TIMESTAMP,updated_at=CURRENT_TIMESTAMP WHERE id=?`)
          .bind(clean(d.platform,80),clean(d.model,120),clean(d.os_version,80),clean(d.app_version,40),clean(d.active_profile_id,120),device.id).run();
        const fresh=await env.HYPETV_DB.prepare('SELECT * FROM devices WHERE id=?').bind(device.id).first();
        return json({success:true,device:{id:String(fresh.id),name:fresh.device_name,platform:fresh.platform||'',model:fresh.model||'',os_version:fresh.os_version||'',app_version:fresh.app_version||'',active_profile_id:fresh.active_profile_id||''}});
      }
      if (url.pathname === '/api/app/devices' && request.method === 'GET') {
        const device=await deviceFromRequest(request,env);
        if(!device || device.disabled || device.revoked_at) return errorJson('DEVICE_REVOKED','This device has been unlinked.',401);
        const rows=await env.HYPETV_DB.prepare(`SELECT id,device_name,platform,model,app_version,last_seen,registered_at,active_profile_id FROM devices WHERE customer_id=? AND disabled=0 AND revoked_at IS NULL ORDER BY id`).bind(device.customer_id).all();
        return json({success:true,used:(rows.results||[]).length,limit:Number(device.device_limit||3),devices:(rows.results||[]).map(x=>({...x,id:String(x.id),current:Number(x.id)===Number(device.id)}))});
      }
      const appDeviceMatch=url.pathname.match(/^\/api\/app\/devices\/(\d+)$/);
      if(appDeviceMatch && request.method==='DELETE'){
        const current=await deviceFromRequest(request,env);
        if(!current || current.disabled || current.revoked_at) return errorJson('DEVICE_REVOKED','This device has been unlinked.',401);
        const targetId=Number(appDeviceMatch[1]);
        const target=await env.HYPETV_DB.prepare('SELECT id,customer_id FROM devices WHERE id=?').bind(targetId).first();
        if(!target || Number(target.customer_id)!==Number(current.customer_id)) return errorJson('NOT_FOUND','Linked device not found',404);
        await env.HYPETV_DB.batch([
          env.HYPETV_DB.prepare('DELETE FROM message_receipts WHERE device_id=?').bind(targetId),
          env.HYPETV_DB.prepare('DELETE FROM messages WHERE target_device_id=?').bind(targetId),
          env.HYPETV_DB.prepare('DELETE FROM devices WHERE id=?').bind(targetId)
        ]);
        return json({success:true,device_id:String(targetId),logged_out:true,current:Number(targetId)===Number(current.id)});
      }

      const syncMatch=url.pathname.match(/^\/api\/app\/sync\/([a-z0-9_-]+)$/i);
      if(syncMatch){
        const device=await deviceFromRequest(request,env);
        if(!device || device.disabled || device.revoked_at) return errorJson('DEVICE_REVOKED','This device has been unlinked.',401);
        const key=syncMatch[1].toLowerCase();
        if(!['profiles','favourites','progress','history','preferences'].includes(key)) return errorJson('INVALID_SYNC_KEY','Unsupported sync data type',400);
        if(request.method==='GET'){
          const row=await env.HYPETV_DB.prepare('SELECT payload,revision,updated_at FROM account_sync WHERE customer_id=? AND sync_key=?').bind(device.customer_id,key).first();
          return json({success:true,key,payload:row?JSON.parse(row.payload||'{}'):{},revision:Number(row?.revision||0),updated_at:row?.updated_at||null});
        }
        if(request.method==='PUT'){
          const d=await readBody(request); const payload=JSON.stringify(d.payload??{});
          if(payload.length>500000) return errorJson('PAYLOAD_TOO_LARGE','Sync payload is too large',413);
          await env.HYPETV_DB.prepare(`INSERT INTO account_sync(customer_id,sync_key,payload,revision,updated_at,updated_by_device_id) VALUES(?,?,?,1,CURRENT_TIMESTAMP,?) ON CONFLICT(customer_id,sync_key) DO UPDATE SET payload=excluded.payload,revision=account_sync.revision+1,updated_at=CURRENT_TIMESTAMP,updated_by_device_id=excluded.updated_by_device_id`).bind(device.customer_id,key,payload,device.id).run();
          const row=await env.HYPETV_DB.prepare('SELECT revision,updated_at FROM account_sync WHERE customer_id=? AND sync_key=?').bind(device.customer_id,key).first();
          return json({success:true,key,revision:Number(row.revision),updated_at:row.updated_at});
        }
      }
      if (url.pathname === '/api/app/pairing/code' && request.method === 'POST') {
        const device=await deviceFromRequest(request,env);
        if(!device || device.disabled || device.revoked_at) return errorJson('DEVICE_REVOKED','This device has been unlinked.',401);
        let code=''; for(let i=0;i<50;i++){code=secureFiveDigitCode();if(!(await env.HYPETV_DB.prepare('SELECT id FROM pairing_sessions WHERE code=?').bind(code).first()))break;}
        const expiresAt=new Date(Date.now()+10*60*1000).toISOString();
        await env.HYPETV_DB.prepare('INSERT INTO pairing_sessions(customer_id,source_device_id,code,expires_at) VALUES(?,?,?,?)').bind(device.customer_id,device.id,code,expiresAt).run();
        return json({success:true,code,expires_at:expiresAt});
      }
      if (url.pathname === '/api/app/pairing/claim' && request.method === 'POST') {
        const d=await readBody(request), code=clean(d.code,5), hardwareId=clean(d.device_id,200);
        if(!/^\d{5}$/.test(code)||!hardwareId) return errorJson('INVALID_CODE','Invalid pairing code',400);
        const pair=await env.HYPETV_DB.prepare(`SELECT p.*,c.connection_allowance,COALESCE(c.device_limit,3) AS device_limit,c.status,c.expires_at customer_expires_at FROM pairing_sessions p JOIN customers c ON c.id=p.customer_id WHERE p.code=?`).bind(code).first();
        if(!pair || pair.claimed_at || expired(pair.expires_at)) return errorJson('PAIRING_CODE_EXPIRED','Pairing code is invalid or expired',410);
        if(pair.status!=='active'||expired(pair.customer_expires_at)) return errorJson('CUSTOMER_INACTIVE','Customer account is not active',403);
        const existing=await env.HYPETV_DB.prepare('SELECT * FROM devices WHERE device_id=?').bind(hardwareId).first();
        if(existing && Number(existing.customer_id)!==Number(pair.customer_id)) return errorJson('DEVICE_LINKED_ELSEWHERE','This device is linked to another account',403);
        const count=await env.HYPETV_DB.prepare('SELECT COUNT(*) n FROM devices WHERE customer_id=? AND disabled=0 AND revoked_at IS NULL').bind(pair.customer_id).first();
        if(!existing && Number(count.n)>=Number(pair.device_limit||3)) return errorJson('DEVICE_LIMIT_REACHED',`Device limit reached (${pair.device_limit||3}). Unlink a device or contact your provider.`,403);
        const rawToken=randomToken(32),tokenHash=await sha256(rawToken);
        let linked;
        if(existing){await env.HYPETV_DB.prepare(`UPDATE devices SET token_hash=?,device_name=COALESCE(NULLIF(?,''),device_name),platform=?,model=?,app_version=?,disabled=0,status='active',revoked_at=NULL,last_seen=CURRENT_TIMESTAMP,updated_at=CURRENT_TIMESTAMP WHERE id=?`).bind(tokenHash,clean(d.device_name,120),clean(d.platform,80),clean(d.model,120),clean(d.app_version,40),existing.id).run();linked=await env.HYPETV_DB.prepare('SELECT * FROM devices WHERE id=?').bind(existing.id).first();}
        else {const r=await env.HYPETV_DB.prepare(`INSERT INTO devices(customer_id,device_id,device_name,platform,app_version,token_hash,model,registered_at,status) VALUES(?,?,?,?,?,?,?,?, 'active')`).bind(pair.customer_id,hardwareId,clean(d.device_name||'HypeTV Device',120),clean(d.platform,80),clean(d.app_version,40),tokenHash,clean(d.model,120),nowIso()).run();linked=await env.HYPETV_DB.prepare('SELECT * FROM devices WHERE id=?').bind(r.meta.last_row_id).first();}
        await env.HYPETV_DB.prepare('UPDATE pairing_sessions SET claimed_device_id=?,claimed_at=CURRENT_TIMESTAMP WHERE id=?').bind(linked.id,pair.id).run();
        return json({success:true,token:rawToken,device:{id:String(linked.id),name:linked.device_name},device_limit:Number(pair.connection_allowance||3)});
      }



      if (url.pathname === '/api/catalog/home' && request.method === 'GET') {
        const auth=await authenticatedContext(request,env,true); if(auth.error)return auth.error;
        const startedAt = Date.now();
        const requestId = randomToken(8);
        try {
          // Never load and cache the provider's entire catalogue for the home screen.
          // Large Xtream accounts can contain tens of thousands of records and exceed
          // the Worker CPU limit while parsing, mapping and serialising the response.
          const [liveCategories,movieCategories,seriesCategories,s] = await Promise.all([
            cachedProviderLimited(env,auth.source,'get_live_categories',{},600,30),
            cachedProviderLimited(env,auth.source,'get_vod_categories',{},600,30),
            cachedProviderLimited(env,auth.source,'get_series_categories',{},600,30),
            settings(env)
          ]);
          const [live,movies,series] = await Promise.all([
            firstPopulatedCategory(env,auth.source,liveCategories,'get_live_streams',120,12),
            firstPopulatedCategory(env,auth.source,movieCategories,'get_vod_streams',300,12),
            firstPopulatedCategory(env,auth.source,seriesCategories,'get_series',300,12)
          ]);
          const messages=await env.HYPETV_DB.prepare(`SELECT m.id,m.title,m.message,m.priority,m.created_at FROM messages m LEFT JOIN message_receipts r ON r.message_id=m.id AND r.device_id=? WHERE m.active=1 AND (m.expires_at IS NULL OR datetime(m.expires_at)>datetime('now')) AND r.read_at IS NULL AND (m.target_type='everyone' OR (m.target_type='customer' AND m.target_customer_id=?) OR (m.target_type='device' AND m.target_device_id=?)) ORDER BY m.id DESC LIMIT 20`).bind(auth.device.id,auth.device.customer_id,auth.device.id).all();
          console.log(JSON.stringify({event:'catalogue_home_diagnostic',request_id:requestId,customer_id:auth.device.customer_id,source_id:auth.source.id||0,live_category_count:liveCategories.length,movie_category_count:movieCategories.length,series_category_count:seriesCategories.length,live_item_count:live.length,movie_item_count:movies.length,series_item_count:series.length,elapsed_ms:Date.now()-startedAt}));
          return json({success:true,generated_at:nowIso(),customer:{id:String(auth.device.customer_id),name:auth.device.customer_name,expires_at:auth.device.customer_expires_at},maintenance:{enabled:s.maintenance_enabled==='true',message:s.maintenance_message||null,estimated_return:s.maintenance_estimated_return||null},messages:messages.results||[],sections:[{id:'live_featured',title:'Live TV',type:'live',items:live.map(x=>normalItem(x,'live'))},{id:'latest_movies',title:'Latest Movies',type:'movie',items:movies.map(x=>normalItem(x,'movie'))},{id:'latest_series',title:'Latest Series',type:'series',items:series.map(x=>normalItem(x,'series'))}]});
        } catch(e) {
          console.error(JSON.stringify({event:'catalogue_home_error',request_id:requestId,customer_id:auth.device.customer_id,source_id:auth.source?.id||0,elapsed_ms:Date.now()-startedAt,message:e?.message||String(e),stack:e?.stack||null}));
          const [c,m,st]=upstreamError(e); return errorJson(c,m,st);
        }
      }
      const catalogueRoutes = {
        '/api/catalog/live/categories':['get_live_categories','category',600],
        '/api/catalog/live':['get_live_streams','live',120],
        '/api/catalog/movies/categories':['get_vod_categories','category',600],
        '/api/catalog/movies':['get_vod_streams','movie',300],
        '/api/catalog/series/categories':['get_series_categories','category',600],
        '/api/catalog/series':['get_series','series',300]
      };
      if (catalogueRoutes[url.pathname] && request.method==='GET') {
        const auth=await authenticatedContext(request,env,true); if(auth.error)return auth.error;
        const [action,type,ttl]=catalogueRoutes[url.pathname];
        try {
          const params={}; const category=url.searchParams.get('category_id'); if(category)params.category_id=clean(category,50);
          const raw=await cachedProvider(env,auth.source,action,params,ttl);
          let data=Array.isArray(raw)?raw:[];
          if(type==='category') data=data.map(categoryItem); else data=data.map(x=>normalItem(x,type));
          const page=int(url.searchParams.get('page'),1,1,100000), limit=int(url.searchParams.get('limit'),100,1,500), total=data.length;
          if(type!=='category') data=data.slice((page-1)*limit,(page-1)*limit+limit);
          return json({success:true,data,pagination:type==='category'?undefined:{page,limit,total}});
        } catch(e) { const [c,m,st]=upstreamError(e); return errorJson(c,m,st); }
      }
      const movieDetail=url.pathname.match(/^\/api\/catalog\/movies\/([^/]+)$/);
      if(movieDetail && request.method==='GET') { const auth=await authenticatedContext(request,env,true); if(auth.error)return auth.error; try{return json({success:true,data:await cachedProvider(env,auth.source,'get_vod_info',{vod_id:clean(movieDetail[1],50)},600)});}catch(e){const [c,m,st]=upstreamError(e);return errorJson(c,m,st);} }
      const seriesDetail=url.pathname.match(/^\/api\/catalog\/series\/([^/]+)$/);
      if(seriesDetail && request.method==='GET') { const auth=await authenticatedContext(request,env,true); if(auth.error)return auth.error; try{return json({success:true,data:await cachedProvider(env,auth.source,'get_series_info',{series_id:clean(seriesDetail[1],50)},600)});}catch(e){const [c,m,st]=upstreamError(e);return errorJson(c,m,st);} }
      const epgDetail=url.pathname.match(/^\/api\/catalog\/epg\/([^/]+)$/);
      if(epgDetail && request.method==='GET') {
        const auth=await authenticatedContext(request,env,true); if(auth.error)return auth.error;
        try{
          const streamId=clean(epgDetail[1],50);
          const limit=int(url.searchParams.get('limit'),12,1,2000);
          const includePast=url.searchParams.get('include_past')==='1';
          const action=includePast?'get_simple_data_table':'get_short_epg';
          const raw=await cachedProvider(
            env,
            auth.source,
            action,
            includePast?{stream_id:streamId}:{stream_id:streamId,limit},
            60
          );
          let listings=Array.isArray(raw)?raw:(raw?.epg_listings||raw?.listings||[]);
          if(!Array.isArray(listings))listings=[];
          if(limit>0 && listings.length>limit) listings=listings.slice(-limit);
          return json({success:true,data:{epg_listings:listings}});
        }catch(e){const [c,m,st]=upstreamError(e);return errorJson(c,m,st);}
      }
      if(url.pathname==='/api/catalog/search' && request.method==='GET') {
        const auth=await authenticatedContext(request,env,true); if(auth.error)return auth.error;
        if(!(await rateLimit(env,`search:${auth.device.id}`,30,60)))return errorJson('RATE_LIMITED','Too many search requests.',429);
        const q=clean(url.searchParams.get('q'),100).toLowerCase(), wanted=clean(url.searchParams.get('type'),20);
        if(q.length<2)return errorJson('INVALID_REQUEST','Search query must contain at least two characters.',400);
        try{const kinds=wanted&&['live','movie','series'].includes(wanted)?[wanted]:['live','movie','series'];const actions={live:'get_live_streams',movie:'get_vod_streams',series:'get_series'};let out=[];for(const kind of kinds){const raw=await cachedProvider(env,auth.source,actions[kind],{},kind==='live'?120:300);out.push(...(Array.isArray(raw)?raw:[]).filter(x=>String(x.name||x.title||'').toLowerCase().includes(q)).slice(0,50).map(x=>normalItem(x,kind)));}return json({success:true,data:out.slice(0,100)});}catch(e){const [c,m,st]=upstreamError(e);return errorJson(c,m,st);}
      }
      if(url.pathname==='/api/playback/catchup' && request.method==='POST') {
        const auth=await authenticatedContext(request,env,true); if(auth.error)return auth.error;
        const d=await readBody(request);
        const id=clean(d.content_id,80);
        const start=Number(d.start_timestamp||0);
        const end=Number(d.end_timestamp||0);
        const requested=clean(d.container_extension,10).toLowerCase();
        if(!/^[A-Za-z0-9_-]+$/.test(id)||!Number.isFinite(start)||!Number.isFinite(end)||end<=start){
          return errorJson('INVALID_REQUEST','Invalid catch-up playback request.',400);
        }
        const duration=Math.max(1,Math.ceil((end-start)/60));
        const dt=new Date(start*1000);
        const pad=n=>String(n).padStart(2,'0');
        const startText=dt.getUTCFullYear()+'-'+pad(dt.getUTCMonth()+1)+'-'+pad(dt.getUTCDate())+':'+pad(dt.getUTCHours())+'-'+pad(dt.getUTCMinutes());
        const ext=['ts','m3u8'].includes(requested)?requested:'ts';
        const base=normaliseServiceUrl(auth.source.service_url);
        const user=encodeURIComponent(auth.source.service_username);
        const pass=encodeURIComponent(auth.source.service_password);
        return json({success:true,playback:{
          url:base+'/timeshift/'+user+'/'+pass+'/'+duration+'/'+encodeURIComponent(startText)+'/'+encodeURIComponent(id)+'.'+ext,
          expires_at:new Date(Date.now()+5*60*1000).toISOString(),
          headers:{'User-Agent':auth.source.user_agent||'HypeTV'}
        }});
      }

      if(url.pathname==='/api/playback/resolve' && request.method==='POST') {
        const auth=await authenticatedContext(request,env,true); if(auth.error)return auth.error;
        const d=await readBody(request), type=clean(d.content_type,20), id=clean(d.content_id,80), requested=clean(d.container_extension,10).toLowerCase();
        if(!['live','movie','series'].includes(type)||!/^[A-Za-z0-9_-]+$/.test(id))return errorJson('INVALID_REQUEST','Invalid playback request.',400);
        const allowed=type==='live'?['ts','m3u8']:['mp4','mkv','avi','m3u8']; const ext=allowed.includes(requested)?requested:(type==='live'?(auth.source.service_output||'m3u8'):'mp4');
        const base=normaliseServiceUrl(auth.source.service_url), user=encodeURIComponent(auth.source.service_username), pass=encodeURIComponent(auth.source.service_password);
        return json({success:true,playback:{url:`${base}/${type}/${user}/${pass}/${encodeURIComponent(id)}.${ext}`,expires_at:new Date(Date.now()+5*60*1000).toISOString(),headers:{'User-Agent':auth.source.user_agent||'HypeTV'}}});
      }

      if (url.pathname === '/api/app/live-categories' && request.method === 'GET') {
        const auth=await requireAppDevice(request,env); if(auth.error)return auth.error;
        return json({success:true,categories:await cachedXtream(env,auth.service,'get_live_categories')});
      }
      if (url.pathname === '/api/app/live-streams' && request.method === 'GET') {
        const auth=await requireAppDevice(request,env); if(auth.error)return auth.error;
        const data=await cachedXtream(env,auth.service,'get_live_streams',{category_id:url.searchParams.get('category_id')||''});
        return json({success:true,streams:Array.isArray(data)?data.map(x=>mapStream(x,'live')):[]});
      }
      if (url.pathname === '/api/app/vod-categories' && request.method === 'GET') {
        const auth=await requireAppDevice(request,env); if(auth.error)return auth.error;
        return json({success:true,categories:await cachedXtream(env,auth.service,'get_vod_categories')});
      }
      if (url.pathname === '/api/app/movies' && request.method === 'GET') {
        const auth=await requireAppDevice(request,env); if(auth.error)return auth.error;
        const data=await cachedXtream(env,auth.service,'get_vod_streams',{category_id:url.searchParams.get('category_id')||''});
        return json({success:true,movies:Array.isArray(data)?data.map(x=>mapStream(x,'movie')):[]});
      }
      if (url.pathname === '/api/app/series-categories' && request.method === 'GET') {
        const auth=await requireAppDevice(request,env); if(auth.error)return auth.error;
        return json({success:true,categories:await cachedXtream(env,auth.service,'get_series_categories')});
      }
      if (url.pathname === '/api/app/series' && request.method === 'GET') {
        const auth=await requireAppDevice(request,env); if(auth.error)return auth.error;
        const data=await cachedXtream(env,auth.service,'get_series',{category_id:url.searchParams.get('category_id')||''});
        return json({success:true,series:Array.isArray(data)?data.map(x=>mapStream(x,'series')):[]});
      }
      const seriesInfo=url.pathname.match(/^\/api\/app\/series\/([^/]+)$/);
      if(seriesInfo && request.method==='GET'){
        const auth=await requireAppDevice(request,env); if(auth.error)return auth.error;
        return json({success:true,series:await cachedXtream(env,auth.service,'get_series_info',{series_id:seriesInfo[1]},120)});
      }
      if (url.pathname === '/api/app/epg' && request.method === 'GET') {
        const auth=await requireAppDevice(request,env); if(auth.error)return auth.error;
        const streamId=clean(url.searchParams.get('stream_id'),40); if(!streamId)return errorJson('VALIDATION_ERROR','stream_id is required',400);
        return json({success:true,epg:await cachedXtream(env,auth.service,'get_short_epg',{stream_id:streamId,limit:int(url.searchParams.get('limit'),10,1,100)},60)});
      }
      const play=url.pathname.match(/^\/api\/app\/play\/(live|movie|series)\/([^/]+)$/);
      if(play && request.method==='GET'){
        const auth=await requireAppDevice(request,env); if(auth.error)return auth.error;
        const base=normaliseServiceUrl(auth.service.service_url), user=encodeURIComponent(auth.service.service_username), pass=encodeURIComponent(auth.service.service_password), id=encodeURIComponent(play[2]);
        const ext=play[1]==='live'?(auth.service.service_output||'m3u8'):(clean(url.searchParams.get('ext'),10)||'mp4');
        return json({success:true,url:`${base}/${play[1]}/${user}/${pass}/${id}.${ext}`,expires_in:60});
      }


      if (url.pathname === '/api/premiumize/account' && request.method === 'GET') {
        const auth=await premiumContext(request,env); if(auth.error)return auth.error;
        try {
          const d=await premiumizeJson(env,'/api/account/info');
          return json({success:true,account:{premium_until:d.premium_until||null,limit_used:d.limit_used??null,booster_points:d.booster_points??null}});
        } catch(e) { return premiumizeError(e); }
      }
      if (url.pathname === '/api/premiumize/folder' && request.method === 'GET') {
        const auth=await premiumContext(request,env); if(auth.error)return auth.error;
        try {
          const id=clean(url.searchParams.get('id'),200);
          const d=await premiumizeJson(env,'/api/folder/list',id?{id,includebreadcrumbs:'true'}:{includebreadcrumbs:'true'});
          const items=(Array.isArray(d.content)?d.content:[]).filter(x=>x?.type==='folder'||premiumVideo(x)).map(safePremiumEntry);
          return json({success:true,folder:{id:String(d.folder_id||id||''),name:String(d.name||'Premium VOD'),parent_id:d.parent_id?String(d.parent_id):null,breadcrumbs:Array.isArray(d.breadcrumbs)?d.breadcrumbs.map(x=>({id:String(x.id||''),name:String(x.name||'')})):[]},items});
        } catch(e) { return premiumizeError(e); }
      }
      if (url.pathname === '/api/premiumize/search' && request.method === 'GET') {
        const auth=await premiumContext(request,env); if(auth.error)return auth.error;
        const q=clean(url.searchParams.get('q'),120);
        if (q.length < 2) return errorJson('INVALID_REQUEST','Enter at least 2 characters.',400);
        try {
          const d=await premiumizeJson(env,'/api/folder/search',{q});
          const items=(Array.isArray(d.content)?d.content:[]).filter(x=>x?.type==='folder'||premiumVideo(x)).map(safePremiumEntry);
          return json({success:true,items});
        } catch(e) { return premiumizeError(e); }
      }
      const premiumPlay=url.pathname.match(/^\/api\/premiumize\/play\/([^/]+)$/);
      if (premiumPlay && request.method === 'GET') {
        const auth=await premiumContext(request,env); if(auth.error)return auth.error;
        try {
          const d=await premiumizeJson(env,'/api/item/details',{id:decodeURIComponent(premiumPlay[1])});
          if (!premiumVideo(d) || !d.link) return errorJson('NOT_PLAYABLE','This Premium VOD item cannot be played.',422);
          return json({success:true,playback:{url:String(d.link),headers:{},title:String(d.name||'Premium VOD')}});
        } catch(e) { return premiumizeError(e); }
      }

      if (url.pathname === '/api/admin/premiumize/config' && request.method === 'GET') {
        const rows=await env.HYPETV_DB.prepare("SELECT key,value FROM settings WHERE key IN ('premiumize_key_ciphertext','premiumize_key_iv')").all();
        const cfg=Object.fromEntries((rows.results||[]).map(x=>[x.key,x.value]));
        return json({success:true,configured:Boolean((cfg.premiumize_key_ciphertext&&cfg.premiumize_key_iv)||env.PREMIUMIZE_API_KEY),source:cfg.premiumize_key_ciphertext?'dashboard':(env.PREMIUMIZE_API_KEY?'worker_secret':null)});
      }
      if (url.pathname === '/api/admin/premiumize/config' && request.method === 'PUT') {
        const d=await readBody(request), key=clean(d.api_key,1000);
        if(!key) return errorJson('INVALID_REQUEST','Enter a Premiumize API key.',400);
        const encrypted=await encryptCredential(key,env);
        await env.HYPETV_DB.batch([
          env.HYPETV_DB.prepare("INSERT INTO settings(key,value) VALUES('premiumize_key_ciphertext',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value").bind(encrypted.ciphertext),
          env.HYPETV_DB.prepare("INSERT INTO settings(key,value) VALUES('premiumize_key_iv',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value").bind(encrypted.iv)
        ]);
        return json({success:true,configured:true});
      }
      if (url.pathname === '/api/admin/premiumize/config' && request.method === 'DELETE') {
        await env.HYPETV_DB.prepare("DELETE FROM settings WHERE key IN ('premiumize_key_ciphertext','premiumize_key_iv')").run();
        return json({success:true});
      }
      if (url.pathname === '/api/admin/premiumize/test' && request.method === 'GET') {
        if (!(await requireAdmin(request,env))) return errorJson('UNAUTHORISED','Unauthorised',401);
        try {
          const d=await premiumizeJson(env,'/api/account/info');
          return json({success:true,configured:true,account:{premium_until:d.premium_until||null,limit_used:d.limit_used??null,booster_points:d.booster_points??null}});
        } catch(e) { return premiumizeError(e); }
      }

      const ack = url.pathname.match(/^\/api\/messages\/(\d+)\/acknowledge$/);
      if (ack && request.method === 'POST') {
        const device = await deviceFromRequest(request,env);
        if (!device || device.disabled) return errorJson('DEVICE_BLOCKED','Invalid or revoked device token',401);
        await env.HYPETV_DB.prepare(`INSERT INTO message_receipts(message_id,device_id,delivered_at,read_at) VALUES(?,?,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)
          ON CONFLICT(message_id,device_id) DO UPDATE SET read_at=CURRENT_TIMESTAMP`).bind(Number(ack[1]),device.id).run();
        return json({ success:true });
      }

      if (!(await requireAdmin(request,env))) return errorJson('UNAUTHORISED','Unauthorised',401);

      const catalogTest=url.pathname.match(/^\/api\/admin\/customers\/(\d+)\/catalog-test$/);
      if(catalogTest && request.method==='GET') {
        const customerId=Number(catalogTest[1]);
        const source=await sourceForCustomer(customerId,env);
        if(!source)return errorJson('SOURCE_NOT_CONFIGURED','No streaming source has been configured for this account.',404);
        if(!source.is_enabled)return errorJson('SOURCE_DISABLED','The streaming source is disabled.',409);
        const startedAt=Date.now(), requestId=randomToken(8);
        try {
          const account=await upstreamJsonForSource(source,'',{},12000);
          const info=account?.user_info||{};
          if(String(info.auth)!=='1')return errorJson('SOURCE_AUTH_FAILED','The streaming source rejected these credentials.',422);
          const [liveCategories,movieCategories,seriesCategories] = await Promise.all([
            cachedProviderLimited(env,source,'get_live_categories',{},600,500),
            cachedProviderLimited(env,source,'get_vod_categories',{},600,500),
            cachedProviderLimited(env,source,'get_series_categories',{},600,500)
          ]);
          const [liveItems,movieItems,seriesItems] = await Promise.all([
            firstPopulatedCategory(env,source,liveCategories,'get_live_streams',120,12),
            firstPopulatedCategory(env,source,movieCategories,'get_vod_streams',300,12),
            firstPopulatedCategory(env,source,seriesCategories,'get_series',300,12)
          ]);
          const [liveStreams,movies,series] = await Promise.all([
            upstreamCount(xtreamUrl(source,'get_live_streams'),'stream_id'),
            upstreamCount(xtreamUrl(source,'get_vod_streams'),'stream_id'),
            upstreamCount(xtreamUrl(source,'get_series'),'series_id')
          ]);
          const result={success:true,source:{connected:true,status:info.status||'Active'},counts:{live_categories:liveCategories.length,live_streams:liveStreams,vod_categories:movieCategories.length,movies,series_categories:seriesCategories.length,series},home:{sections:3,live_items:liveItems.length,movie_items:movieItems.length,series_items:seriesItems.length}};
          console.log(JSON.stringify({event:'catalogue_admin_test',request_id:requestId,customer_id:customerId,source_id:source.id||0,...result.counts,...result.home,elapsed_ms:Date.now()-startedAt}));
          return json(result);
        } catch(e) {
          const [code,message,status]=upstreamError(e);
          console.error(JSON.stringify({event:'catalogue_admin_test_error',request_id:requestId,customer_id:customerId,source_id:source.id||0,elapsed_ms:Date.now()-startedAt,code,message:e?.message||String(e)}));
          return errorJson(code,message,status);
        }
      }

      const sourceList=url.pathname.match(/^\/api\/admin\/customers\/(\d+)\/streaming-source$/);
      if(sourceList && request.method==='GET') {
        const row=await env.HYPETV_DB.prepare('SELECT * FROM streaming_sources WHERE customer_id=? ORDER BY id DESC LIMIT 1').bind(Number(sourceList[1])).first();
        return json({success:true,source:publicSource(row)});
      }
      if(sourceList && (request.method==='PUT'||request.method==='POST')) {
        const customerId=Number(sourceList[1]), d=await readBody(request), existing=await env.HYPETV_DB.prepare('SELECT * FROM streaming_sources WHERE customer_id=? ORDER BY id DESC LIMIT 1').bind(customerId).first();
        let username=clean(d.username,300), password=clean(d.password,300);
        if(existing && (!username||username==='••••••••')) username=await decryptCredential(existing.username_ciphertext,existing.username_iv,env);
        if(existing && (!password||password==='••••••••')) password=await decryptCredential(existing.password_ciphertext,existing.password_iv,env);
        if(!username||!password)return errorJson('VALIDATION_ERROR','Username and password are required.',400);
        const firstPreset=await env.HYPETV_DB.prepare('SELECT * FROM streaming_source_presets WHERE active=1 ORDER BY id LIMIT 1').first();
        let baseUrl; try{baseUrl=safeSourceUrl(clean(d.base_url,500)||existing?.base_url||firstPreset?.base_url||'');}catch{return errorJson('VALIDATION_ERROR','Add at least one active HypeTV server in Settings.',400);}
        const ue=await encryptCredential(username,env), pe=await encryptCredential(password,env), output=firstPreset?.output_format||existing?.output_format||'m3u8';
        if(existing){await env.HYPETV_DB.prepare(`UPDATE streaming_sources SET source_type='xtream',display_name='HypeTV',base_url=?,username_ciphertext=?,username_iv=?,password_ciphertext=?,password_iv=?,output_format=?,user_agent='HypeTV',is_enabled=1,updated_at=CURRENT_TIMESTAMP WHERE id=?`).bind(baseUrl,ue.ciphertext,ue.iv,pe.ciphertext,pe.iv,output,existing.id).run();}
        else{await env.HYPETV_DB.prepare(`INSERT INTO streaming_sources(customer_id,source_type,display_name,base_url,username_ciphertext,username_iv,password_ciphertext,password_iv,output_format,user_agent,is_enabled) VALUES(?,'xtream','HypeTV',?,?,?,?,?,?,'HypeTV',1)`).bind(customerId,baseUrl,ue.ciphertext,ue.iv,pe.ciphertext,pe.iv,output).run();}
        const saved=await env.HYPETV_DB.prepare('SELECT * FROM streaming_sources WHERE customer_id=? ORDER BY id DESC LIMIT 1').bind(customerId).first();
        return json({success:true,source:publicSource(saved)});
      }
      const testSource=url.pathname.match(/^\/api\/admin\/streaming-sources\/(\d+)\/test$/);
      if(testSource && request.method==='POST') {
        if(!(await rateLimit(env,`source-test:${clientKey(request)}`,10,300)))return errorJson('RATE_LIMITED','Too many source tests.',429);
        const row=await env.HYPETV_DB.prepare('SELECT * FROM streaming_sources WHERE id=?').bind(Number(testSource[1])).first(); if(!row)return errorJson('SOURCE_NOT_CONFIGURED','Streaming source not found.',404);
        const source={...row,service_url:row.base_url,service_username:await decryptCredential(row.username_ciphertext,row.username_iv,env),service_password:await decryptCredential(row.password_ciphertext,row.password_iv,env)};
        try{const fullSource=await sourceForCustomer(row.customer_id,env); const account=await upstreamJsonForSource(fullSource,'',{},12000), info=account?.user_info||{}, ok=String(info.auth)==='1'; if(!ok)throw new Error('AUTH'); const exp=info.exp_date?new Date(Number(info.exp_date)*1000).toISOString():null; if(exp&&expired(exp))return errorJson('SOURCE_ACCOUNT_EXPIRED','The streaming source account has expired.',422); await env.HYPETV_DB.prepare("UPDATE streaming_sources SET last_tested_at=CURRENT_TIMESTAMP,last_test_status='connected',last_test_message='Connected',updated_at=CURRENT_TIMESTAMP WHERE id=?").bind(row.id).run(); return json({success:true,status:'connected',account:{username:'masked',status:info.status||'Active',expires_at:exp,max_connections:Number(info.max_connections||0),active_connections:Number(info.active_cons||0)}});}catch(e){const code=e.message==='AUTH'?'SOURCE_AUTH_FAILED':upstreamError(e)[0]; const detail=e.message==='AUTH'?'The streaming source rejected these credentials.':clean(e?.message||upstreamError(e)[1],220); const msg=e.message==='AUTH'?detail:`The streaming source could not be reached (${detail}).`; console.error(JSON.stringify({event:'streaming_source_test_failed',source_id:row.id,host:new URL(row.base_url).host,code,error:e?.message,first_attempt:e?.firstAttemptMessage||null,status:e?.upstreamStatus||null,body_preview:e?.upstreamBody||null})); await env.HYPETV_DB.prepare("UPDATE streaming_sources SET last_tested_at=CURRENT_TIMESTAMP,last_test_status='failed',last_test_message=?,updated_at=CURRENT_TIMESTAMP WHERE id=?").bind(msg,row.id).run();return errorJson(code,msg,code==='SOURCE_AUTH_FAILED'?422:502);}
      }
      const clearSource=url.pathname.match(/^\/api\/admin\/streaming-sources\/(\d+)\/clear-cache$/);
      if(clearSource && request.method==='POST'){await env.HYPETV_DB.prepare('DELETE FROM catalogue_cache_v2 WHERE source_id=?').bind(Number(clearSource[1])).run();return json({success:true});}


      if (url.pathname === '/api/dashboard') {
        const [customers,online,codes,expiring] = await Promise.all([
          env.HYPETV_DB.prepare("SELECT COUNT(*) n FROM customers WHERE status='active'").first(),
          env.HYPETV_DB.prepare("SELECT COUNT(*) n FROM devices WHERE disabled=0 AND datetime(last_seen)>=datetime('now','-15 minutes')").first(),
          env.HYPETV_DB.prepare("SELECT COUNT(*) n FROM activation_codes WHERE revoked=0 AND (expires_at IS NULL OR datetime(expires_at)>datetime('now'))").first(),
          env.HYPETV_DB.prepare("SELECT COUNT(*) n FROM customers WHERE status='active' AND date(expires_at) BETWEEN date('now') AND date('now','+14 days')").first()
        ]);
        return json({ active_customers:customers.n,online_devices:online.n,active_codes:codes.n,expiring_soon:expiring.n,version:VERSION });
      }

      if (url.pathname === '/api/source-presets') {
        if (request.method === 'GET') return json((await env.HYPETV_DB.prepare('SELECT * FROM streaming_source_presets ORDER BY active DESC,name').all()).results);
        if (request.method === 'POST') {
          const d=await readBody(request), name=clean(d.name,120);
          let baseUrl='';
          try { baseUrl=normaliseBaseUrl(d.base_url); }
          catch(e) { return errorJson('VALIDATION_ERROR',e?.message||'Enter a valid HypeTV server URL',400); }
          if(!name||!baseUrl) return errorJson('VALIDATION_ERROR','Preset name and server URL are required',400);
          const duplicate=await env.HYPETV_DB.prepare('SELECT id FROM streaming_source_presets WHERE lower(name)=lower(?)').bind(name).first();
          if(duplicate) return errorJson('DUPLICATE_SERVER','A server with this name already exists. Edit the existing entry or use a different name.',409);
          const r=await env.HYPETV_DB.prepare(`INSERT INTO streaming_source_presets(name,base_url,output_format,user_agent,active) VALUES(?,?,?,?,?)`)
            .bind(name,baseUrl,['m3u8','ts'].includes(d.output_format)?d.output_format:'m3u8',clean(d.user_agent,200)||'HypeTV',d.active===false?0:1).run();
          return json({success:true,id:r.meta.last_row_id},201);
        }
      }
      const presetMatch=url.pathname.match(/^\/api\/source-presets\/(\d+)$/);
      if(presetMatch){
        const id=Number(presetMatch[1]);
        if(request.method==='PUT'){
          const d=await readBody(request), name=clean(d.name,120);
          let baseUrl='';
          try { baseUrl=normaliseBaseUrl(d.base_url); }
          catch(e) { return errorJson('VALIDATION_ERROR',e?.message||'Enter a valid HypeTV server URL',400); }
          if(!name||!baseUrl) return errorJson('VALIDATION_ERROR','Preset name and server URL are required',400);
          const duplicate=await env.HYPETV_DB.prepare('SELECT id FROM streaming_source_presets WHERE lower(name)=lower(?) AND id<>?').bind(name,id).first();
          if(duplicate) return errorJson('DUPLICATE_SERVER','A different server with this name already exists.',409);
          await env.HYPETV_DB.prepare(`UPDATE streaming_source_presets SET name=?,base_url=?,output_format=?,user_agent=?,active=?,updated_at=CURRENT_TIMESTAMP WHERE id=?`)
            .bind(name,baseUrl,['m3u8','ts'].includes(d.output_format)?d.output_format:'m3u8',clean(d.user_agent,200)||'HypeTV',d.active===false?0:1,id).run();
          return json({success:true});
        }
        if(request.method==='DELETE'){
          await env.HYPETV_DB.prepare('DELETE FROM streaming_source_presets WHERE id=?').bind(id).run();
          return json({success:true});
        }
      }

      if (url.pathname === '/api/packages' && request.method === 'GET') return json((await env.HYPETV_DB.prepare('SELECT * FROM packages ORDER BY name').all()).results);

      if (url.pathname === '/api/customers') {
        if (request.method === 'GET') {
          const q = `%${clean(url.searchParams.get('q'),100)}%`;
          const rows = await env.HYPETV_DB.prepare(`SELECT c.*,p.name package_name,
            (SELECT COUNT(*) FROM devices d WHERE d.customer_id=c.id AND d.disabled=0) connections_used
            FROM customers c LEFT JOIN packages p ON p.id=c.package_id WHERE c.name LIKE ? OR c.contact LIKE ? ORDER BY c.id DESC`).bind(q,q).all();
          return json(rows.results);
        }
        if (request.method === 'POST') {
          const d = await readBody(request);
          if (!clean(d.name,120)) return errorJson('VALIDATION_ERROR','Customer name is required',400);
          const r = await env.HYPETV_DB.prepare(`INSERT INTO customers(name,contact,package_id,package_label,expires_at,status,connection_allowance,notes,service_url,service_username,service_password,service_output,content_access)
            VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)`).bind(clean(d.name,120),clean(d.contact,200),d.package_id||null,clean(d.package_label,80),d.expires_at||null,['active','suspended'].includes(d.status)?d.status:'active',int(d.connection_allowance,3,1,100),clean(d.notes,2000),clean(d.service_url,500),clean(d.service_username,300),clean(d.service_password,300),['m3u8','ts'].includes(d.service_output)?d.service_output:'m3u8',contentAccess(d.content_access)).run();
          return json({ success:true,id:r.meta.last_row_id },201);
        }
      }

      const customerMatch = url.pathname.match(/^\/api\/customers\/(\d+)$/);
      if (customerMatch) {
        const id = Number(customerMatch[1]);
        if (request.method === 'PUT') {
          const d = await readBody(request);
          const current=await env.HYPETV_DB.prepare('SELECT * FROM customers WHERE id=?').bind(id).first();
          await env.HYPETV_DB.prepare(`UPDATE customers SET name=?,contact=?,package_id=?,package_label=?,expires_at=?,status=?,connection_allowance=?,notes=?,service_url=?,service_username=?,service_password=?,service_output=?,content_access=?,updated_at=CURRENT_TIMESTAMP WHERE id=?`)
            .bind(clean(d.name,120),d.contact===undefined?(current?.contact||''):clean(d.contact,200),d.package_id===undefined?(current?.package_id||null):(d.package_id||null),d.package_label===undefined?(current?.package_label||''):clean(d.package_label,80),d.expires_at||null,['active','suspended'].includes(d.status)?d.status:'active',int(d.connection_allowance,3,1,100),clean(d.notes,2000),d.service_url===undefined?(current?.service_url||''):clean(d.service_url,500),d.service_username===undefined?(current?.service_username||''):clean(d.service_username,300),d.service_password===undefined?(current?.service_password||''):clean(d.service_password,300),d.service_output===undefined?(current?.service_output||'m3u8'):(['m3u8','ts'].includes(d.service_output)?d.service_output:'m3u8'),contentAccess(d.content_access),id).run();
          return json({ success:true });
        }
        if (request.method === 'DELETE') {
          const statements=[
            env.HYPETV_DB.prepare('DELETE FROM message_receipts WHERE device_id IN (SELECT id FROM devices WHERE customer_id=?)').bind(id),
            env.HYPETV_DB.prepare('DELETE FROM messages WHERE target_customer_id=? OR target_device_id IN (SELECT id FROM devices WHERE customer_id=?)').bind(id,id),
            env.HYPETV_DB.prepare('DELETE FROM catalogue_cache_v2 WHERE source_id IN (SELECT id FROM streaming_sources WHERE customer_id=?)').bind(id),
            env.HYPETV_DB.prepare('DELETE FROM streaming_sources WHERE customer_id=?').bind(id),
            env.HYPETV_DB.prepare('DELETE FROM activation_codes WHERE customer_id=?').bind(id),
            env.HYPETV_DB.prepare('DELETE FROM devices WHERE customer_id=?').bind(id),
            env.HYPETV_DB.prepare('DELETE FROM customers WHERE id=?').bind(id)
          ];
          await env.HYPETV_DB.batch(statements);
          return json({success:true});
        }
      }


      const testService = url.pathname.match(/^\/api\/customers\/(\d+)\/test-service$/);
      if (testService && request.method === 'POST') {
        const id=Number(testService[1]);
        const service=await env.HYPETV_DB.prepare('SELECT service_url,service_username,service_password,service_output FROM customers WHERE id=?').bind(id).first();
        if(!service?.service_url||!service?.service_username||!service?.service_password)return errorJson('SERVICE_NOT_CONFIGURED','Enter the service URL, username and password first',400);
        try{
          const account=await upstreamJson(xtreamUrl(service,''),12000);
          const ok=Boolean(account?.user_info && String(account.user_info.auth)==='1');
          const status=ok?'connected':'invalid';
          await env.HYPETV_DB.prepare('UPDATE customers SET service_last_tested_at=CURRENT_TIMESTAMP,service_last_status=?,service_last_error=? WHERE id=?').bind(status,ok?'':clean(account?.user_info?.message||'Authentication failed',300),id).run();
          if(!ok)return errorJson('UPSTREAM_AUTH_FAILED','Xtream credentials were rejected',422);
          return json({success:true,status,account:{username:account.user_info.username,status:account.user_info.status,exp_date:account.user_info.exp_date,max_connections:account.user_info.max_connections,active_cons:account.user_info.active_cons}});
        }catch(e){
          await env.HYPETV_DB.prepare('UPDATE customers SET service_last_tested_at=CURRENT_TIMESTAMP,service_last_status=?,service_last_error=? WHERE id=?').bind('error',clean(e.message,300),id).run();
          return errorJson('UPSTREAM_UNAVAILABLE','Could not connect to the Xtream service',502);
        }
      }

      const customerDevices = url.pathname.match(/^\/api\/customers\/(\d+)\/devices$/);
      if (customerDevices && request.method === 'GET') {
        return json((await env.HYPETV_DB.prepare(`SELECT d.*,COALESCE(NULLIF(s.username,''),NULLIF(c.service_username,''),'') AS account_username FROM devices d JOIN customers c ON c.id=d.customer_id LEFT JOIN streaming_sources s ON s.customer_id=d.customer_id AND s.is_enabled=1 WHERE d.customer_id=? AND d.disabled=0 ORDER BY d.id DESC`).bind(Number(customerDevices[1])).all()).results);
      }
      const resetDevices = url.pathname.match(/^\/api\/customers\/(\d+)\/devices\/reset$/);
      if (resetDevices && request.method === 'POST') {
        const customerId = Number(resetDevices[1]);
        const rows = await env.HYPETV_DB.prepare('SELECT id FROM devices WHERE customer_id=?').bind(customerId).all();
        const ids = (rows.results || []).map(x => Number(x.id)).filter(Number.isFinite);
        for (const id of ids) {
          await env.HYPETV_DB.batch([
            env.HYPETV_DB.prepare('DELETE FROM message_receipts WHERE device_id=?').bind(id),
            env.HYPETV_DB.prepare('DELETE FROM messages WHERE target_device_id=?').bind(id),
            env.HYPETV_DB.prepare('DELETE FROM devices WHERE id=? AND customer_id=?').bind(id,customerId)
          ]);
        }
        const remaining = await env.HYPETV_DB.prepare('SELECT COUNT(*) n FROM devices WHERE customer_id=?').bind(customerId).first();
        if (Number(remaining?.n || 0) !== 0) return errorJson('SERVER_ERROR','Some devices could not be reset',500);
        return json({success:true,removed:ids.length});
      }
      const deviceMatch = url.pathname.match(/^\/api\/devices\/(\d+)$/);
      if (deviceMatch) {
        const id = Number(deviceMatch[1]);
        if (request.method === 'PUT') { const d=await readBody(request); await env.HYPETV_DB.prepare('UPDATE devices SET device_name=?,updated_at=CURRENT_TIMESTAMP WHERE id=?').bind(clean(d.device_name,120),id).run(); return json({success:true,device_name:clean(d.device_name,120)}); }
        if (request.method === 'DELETE') {
          const existingDevice = await env.HYPETV_DB.prepare('SELECT id,customer_id FROM devices WHERE id=?').bind(id).first();
          if (!existingDevice) return errorJson('NOT_FOUND','Device not found',404);
          await env.HYPETV_DB.batch([
            env.HYPETV_DB.prepare('DELETE FROM message_receipts WHERE device_id=?').bind(id),
            env.HYPETV_DB.prepare('DELETE FROM messages WHERE target_device_id=?').bind(id),
            env.HYPETV_DB.prepare('DELETE FROM devices WHERE id=?').bind(id)
          ]);
          const stillExists = await env.HYPETV_DB.prepare('SELECT id FROM devices WHERE id=?').bind(id).first();
          if (stillExists) return errorJson('SERVER_ERROR','The device could not be removed',500);
          return json({success:true,device_id:String(id),customer_id:String(existingDevice.customer_id)});
        }
      }

      if (url.pathname === '/api/codes') {
        if (request.method === 'GET') return json((await env.HYPETV_DB.prepare(`SELECT a.*,c.name customer_name FROM activation_codes a JOIN customers c ON c.id=a.customer_id ORDER BY a.id DESC`).all()).results);
        if (request.method === 'POST') {
          const d = await readBody(request);
          let code = '';
          for (let i=0;i<50;i++) { code=secureFiveDigitCode(); if (!(await env.HYPETV_DB.prepare('SELECT id FROM activation_codes WHERE code=?').bind(code).first())) break; }
          const expiresAt = d.expires_at || new Date(Date.now()+24*60*60*1000).toISOString();
          await env.HYPETV_DB.prepare('INSERT INTO activation_codes(code,customer_id,max_uses,expires_at) VALUES(?,?,?,?)').bind(code,int(d.customer_id,0,1),int(d.max_uses,1,1,100),expiresAt).run();
          return json({success:true,code,expires_at:expiresAt},201);
        }
      }

      const codeMatch=url.pathname.match(/^\/api\/codes\/(\d+)$/);
      if(codeMatch && request.method==='DELETE'){
        const id=Number(codeMatch[1]);
        const existingCode=await env.HYPETV_DB.prepare('SELECT id FROM activation_codes WHERE id=?').bind(id).first();
        if(!existingCode) return errorJson('NOT_FOUND','Activation code not found',404);
        const result=await env.HYPETV_DB.prepare('DELETE FROM activation_codes WHERE id=?').bind(id).run();
        const stillExists=await env.HYPETV_DB.prepare('SELECT id FROM activation_codes WHERE id=?').bind(id).first();
        if(stillExists || Number(result?.meta?.changes || 0) < 1) return errorJson('SERVER_ERROR','The activation code could not be deleted',500);
        return json({success:true,id:String(id)});
      }

      if (url.pathname === '/api/messages') {
        if (request.method === 'GET') return json((await env.HYPETV_DB.prepare(`SELECT m.*,c.name customer_name,d.device_name FROM messages m LEFT JOIN customers c ON c.id=m.target_customer_id LEFT JOIN devices d ON d.id=m.target_device_id ORDER BY m.id DESC`).all()).results);
        if (request.method === 'POST') {
          const d=await readBody(request);
          const type=['everyone','customer','device'].includes(d.target_type)?d.target_type:'everyone';
          const priority=['normal','important','critical'].includes(d.priority)?d.priority:'normal';
          await env.HYPETV_DB.prepare(`INSERT INTO messages(title,message,priority,target_type,target_customer_id,target_device_id,expires_at) VALUES(?,?,?,?,?,?,?)`)
            .bind(clean(d.title,150),clean(d.message,2000),priority,type,type==='customer'?int(d.target_customer_id):null,type==='device'?int(d.target_device_id):null,d.expires_at||null).run();
          return json({success:true},201);
        }
      }

      const messageMatch=url.pathname.match(/^\/api\/messages\/(\d+)$/);
      if(messageMatch && request.method==='DELETE'){
        const id=Number(messageMatch[1]);
        await env.HYPETV_DB.prepare('DELETE FROM message_receipts WHERE message_id=?').bind(id).run();
        await env.HYPETV_DB.prepare('DELETE FROM messages WHERE id=?').bind(id).run();
        return json({success:true});
      }

      if (url.pathname === '/api/maintenance') {
        if (request.method === 'GET') { const s=await settings(env); return json({enabled:s.maintenance_enabled==='true',message:s.maintenance_message||'',estimated_return:s.maintenance_estimated_return||''}); }
        if (request.method === 'PUT') {
          const d=await readBody(request);
          const values=[['maintenance_enabled',d.enabled?'true':'false'],['maintenance_message',clean(d.message,1000)],['maintenance_estimated_return',clean(d.estimated_return,80)]];
          for (const [k,v] of values) await env.HYPETV_DB.prepare('INSERT INTO settings(key,value,updated_at) VALUES(?,?,CURRENT_TIMESTAMP) ON CONFLICT(key) DO UPDATE SET value=excluded.value,updated_at=CURRENT_TIMESTAMP').bind(k,v).run();
          return json({success:true});
        }
      }

      return errorJson('NOT_FOUND','Not found',404);
    } catch (err) {
      console.error(JSON.stringify({event:'request_error',path:new URL(request.url).pathname,message:err?.message,stack:err?.stack}));
      return errorJson('SERVER_ERROR','An unexpected server error occurred',500);
    }
  }
};
