import {SUPABASE_URL,SUPABASE_KEY} from './config.js';
export const hasSupabase = !!window.supabase && SUPABASE_KEY !== 'COLE_A_CHAVE_PUBLICAVEL_AQUI' && SUPABASE_KEY.trim().length>20;
export const sb = hasSupabase ? window.supabase.createClient(SUPABASE_URL,SUPABASE_KEY,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}}) : null;
const PREF='levelup.preferences.v1', DEMO='levelup.demo.v1';
export const defaultPrefs={sounds:true,volume:.35,reminders:true,reminderMinutes:10,browserNotifications:false,quietStart:'22:00',quietEnd:'08:00',silentCategories:[],motion:true,theme:'dark'};
export function prefs(){try{return {...defaultPrefs,...JSON.parse(localStorage.getItem(PREF)||'{}')}}catch{return {...defaultPrefs}}}
export function savePrefs(p){localStorage.setItem(PREF,JSON.stringify(p))}
export function sound(kind='click'){const p=prefs();if(!p.sounds||p.volume<=0)return;try{const C=window.AudioContext||window.webkitAudioContext;if(!C)return;const c=new C();const seq={click:[620,.045],success:[660,.09],xp:[520,.08],level:[660,.12],error:[180,.12],reminder:[740,.1]}[kind]||[520,.06];const o=c.createOscillator(),g=c.createGain();o.type=kind==='error'?'triangle':'sine';o.frequency.value=seq[0];g.gain.setValueAtTime(.0001,c.currentTime);g.gain.exponentialRampToValueAtTime(Math.max(.001,p.volume*.12),c.currentTime+.01);g.gain.exponentialRampToValueAtTime(.0001,c.currentTime+seq[1]);o.connect(g);g.connect(c.destination);o.start();o.stop(c.currentTime+seq[1]+.02);o.onended=()=>c.close()}catch{}}
export function toast(message,type='info',duration=4200){const host=document.querySelector('#toasts');if(!host)return;const key=message+type;if([...host.children].some(x=>x.dataset.key===key))return;const el=document.createElement('div');el.className='toast '+(type==='success'?'success':type==='warn'?'warn':'');el.dataset.key=key;const icon=type==='success'?'✓':type==='error'?'!':'◆';const span=document.createElement('span');span.textContent=icon+'  '+message;const close=document.createElement('button');close.textContent='×';close.setAttribute('aria-label','Fechar notificação');close.onclick=()=>el.remove();el.append(span,close);host.append(el);if(type==='error')sound('error');setTimeout(()=>el.remove(),duration)}
export function openModal(html){document.querySelector('#modal-content').innerHTML=html;document.querySelector('#modal-backdrop').classList.remove('hidden')}
export function closeModal(){document.querySelector('#modal-backdrop').classList.add('hidden');document.querySelector('#modal-content').innerHTML=''}
export const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
export const dateLabel=v=>v?new Date(v).toLocaleString('pt-BR',{dateStyle:'short',timeStyle: v.length>10?'short':undefined}):'Sem prazo';
export const today=()=>new Date().toISOString().slice(0,10);
export const levelFor=x=>Math.floor(Math.sqrt(Math.max(0,x)/100))+1;
export const levelProgress=x=>{const l=levelFor(x),start=(l-1)**2*100,end=l**2*100;return {level:l,current:x-start,needed:end-start,pct:Math.max(0,Math.min(100,(x-start)/(end-start)*100))}};
export function demoData(){try{return JSON.parse(localStorage.getItem(DEMO))||{tasks:[],events:[],habits:[],habitLogs:[],workouts:[],study:[],vocab:[],exerciseResults:[],xp:0,xpLog:[],achievements:[],missions:[],profile:{name:'Jogador'}}}catch{return {tasks:[],events:[],habits:[],habitLogs:[],workouts:[],study:[],vocab:[],exerciseResults:[],xp:0,xpLog:[],achievements:[],missions:[],profile:{name:'Jogador'}}}}
export function saveDemo(d){localStorage.setItem(DEMO,JSON.stringify(d))}
export const id=()=>crypto.randomUUID?crypto.randomUUID():String(Date.now())+Math.random().toString(36).slice(2);
export async function currentUser(){if(!sb)return null;const {data,error}=await sb.auth.getUser();if(error)throw error;return data.user||null}
