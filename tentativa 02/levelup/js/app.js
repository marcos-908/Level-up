const C=window.LEVELUP_CONFIG,$=s=>document.querySelector(s);
const esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const keyOk=C.SUPABASE_ANON_KEY&&!C.SUPABASE_ANON_KEY.startsWith("COLE");
const sb=keyOk?supabase.createClient(C.SUPABASE_URL,C.SUPABASE_ANON_KEY):null;
let profile=null,tasks=[],S={sound_on:true,volume:.6,reminders_on:true,reminder_lead_min:10,reminder_sound:true},editing=null,filter="pendente",fired=new Set();
const lvlStart=l=>100*(l-1)**2;
function toast(msg,type="err",cb){if([...document.querySelectorAll(".toast span")].some(e=>e.textContent===msg))return;
const d=document.createElement("div");d.className="toast "+type;d.innerHTML=`<span>${esc(msg)}</span><button aria-label="Fechar">✕</button>`;
d.querySelector("span").onclick=()=>cb&&cb();d.querySelector("button").onclick=()=>d.remove();$("#toasts").append(d);setTimeout(()=>d.remove(),6000)}
const fail=(m,e)=>{console.error(e);Sfx.play("error");toast(m+(e?.message?": "+e.message:""))};
function show(app){$("#auth").classList.toggle("hidden",app);$("#shell").classList.toggle("hidden",!app)}
let mode="login";
function authMode(m){mode=m;$("#a-title").textContent={login:"Entrar",signup:"Criar conta",reset:"Recuperar senha"}[m];
$("#f-pass").classList.toggle("hidden",m==="reset");$("#f-pass2").classList.toggle("hidden",m!=="signup");
$("#a-go").textContent={login:"Entrar",signup:"Cadastrar",reset:"Enviar link"}[m]}
async function submitAuth(e){e.preventDefault();const email=$("#a-email").value.trim(),p=$("#a-pass").value;
if(!/^\S+@\S+\.\S+$/.test(email))return toast("E-mail inválido.");
try{if(mode==="reset"){const{error}=await sb.auth.resetPasswordForEmail(email,{redirectTo:location.origin+location.pathname});if(error)throw error;return toast("Pedido enviado (depende do envio de e-mails configurado no Supabase).","ok")}
if(p.length<6)return toast("A senha precisa de ao menos 6 caracteres.");
if(mode==="signup"){if(p!==$("#a-pass2").value)return toast("As senhas não coincidem.");
const{data,error}=await sb.auth.signUp({email,password:p,options:{emailRedirectTo:location.origin+location.pathname}});if(error)throw error;
toast(data.session?"Conta criada!":"Conta criada. Confirme o e-mail se a confirmação estiver ativa.","ok")}
else{const{error}=await sb.auth.signInWithPassword({email,password:p});if(error)throw error}}catch(err){fail("Falha na autenticação",err)}}
async function boot(session){if(!session){profile=null;tasks=[];fired.clear();return show(false)}
try{const[p,s,t]=await Promise.all([sb.from("profiles").select("*").single(),sb.from("user_settings").select("*").maybeSingle(),sb.from("tasks").select("*").order("due_at",{nullsFirst:false})]);
if(p.error)throw p.error;if(t.error)throw t.error;profile=p.data;if(s.data)S={...S,...s.data};tasks=t.data;Sfx.config(S);show(true);route()}
catch(e){fail("Não foi possível carregar seus dados (o SQL foi executado?)",e);show(false)}}
const fmt=d=>d?new Date(d).toLocaleString("pt-BR",{dateStyle:"short",timeStyle:"short"}):"sem prazo";
const late=t=>t.status==="pendente"&&t.due_at&&new Date(t.due_at)<new Date();
function route(){const r=location.hash.slice(1)||"inicio";document.querySelectorAll("nav a").forEach(a=>a.classList.toggle("on",a.dataset.r===r));
$("#who").textContent=profile.display_name;({inicio:home,tarefas:tasksView,config:settingsView}[r]||home)()}
function home(){const p=profile,a=lvlStart(p.level),b=lvlStart(p.level+1),pct=Math.round((p.xp-a)/(b-a)*100);
const pend=tasks.filter(t=>t.status==="pendente"),next=pend.filter(t=>t.due_at).sort((x,y)=>new Date(x.due_at)-new Date(y.due_at)).slice(0,3);
$("#view").innerHTML=`<h1>Olá, ${esc(p.display_name)}</h1><div class="card"><div class="row sp"><div><span class="mut">Nível</span><div class="lvl">${p.level}</div></div><div><b>${p.xp}</b> XP total</div></div>
<div class="bar" role="progressbar" aria-valuenow="${pct}"><i style="width:${pct}%"></i></div><p class="mut">${p.xp-a} / ${b-a} XP para o nível ${p.level+1}</p></div>
<div class="grid2"><div class="card"><h2>Pendentes</h2><div class="lvl" style="font-size:1.6rem">${pend.length}</div><p class="mut">${pend.filter(late).length} atrasada(s)</p></div>
<div class="card"><h2>Próximos prazos</h2>${next.map(t=>`<div>${esc(t.title)} <span class="mut">— ${fmt(t.due_at)}</span></div>`).join("")||'<span class="mut">Nenhum prazo definido.</span>'}</div></div>
${tasks.length?"":`<div class="card"><h2>Comece aqui</h2><p>Crie sua primeira tarefa e conclua-a para ganhar XP (10 baixa, 20 média, 30 alta).</p><a class="btn" href="#tarefas">Criar tarefa</a></div>`}`}
function tasksView(){$("#view").innerHTML=`<h1>Tarefas</h1><form id="tf" class="card"><h2 id="tf-h">Nova tarefa</h2><label>Título</label><input id="t-title" maxlength="200" required>
<label>Descrição</label><textarea id="t-desc" rows="2"></textarea><div class="grid2"><div><label>Prioridade</label><select id="t-pri"><option value="baixa">Baixa</option><option value="media" selected>Média</option><option value="alta">Alta</option></select></div>
<div><label>Categoria</label><select id="t-cat"><option>geral</option><option>estudos</option><option>inglês</option><option>exercícios</option><option>casa</option></select></div>
<div><label>Prazo</label><input id="t-due" type="datetime-local"></div><div><label>Tempo estimado (min)</label><input id="t-est" type="number" min="0"></div></div>
<div class="row" style="margin-top:.8rem"><button class="btn">Salvar tarefa</button><button type="button" id="t-cancel" class="btn ghost hidden">Cancelar edição</button></div></form>
<div class="row" style="margin-bottom:.6rem">${[["pendente","Pendentes"],["atrasada","Atrasadas"],["concluida","Concluídas"],["todas","Todas"]].map(([k,l])=>`<button class="btn ${filter===k?"":"ghost"} sm" data-f="${k}">${l}</button>`).join("")}</div><div id="tl"></div>`;
$("#tf").onsubmit=saveTask;$("#t-cancel").onclick=()=>{editing=null;tasksView()};
document.querySelectorAll("[data-f]").forEach(b=>b.onclick=()=>{filter=b.dataset.f;tasksView()});
if(editing){const t=tasks.find(x=>x.id===editing);if(t){$("#tf-h").textContent="Editar tarefa";$("#t-cancel").classList.remove("hidden");$("#t-title").value=t.title;$("#t-desc").value=t.description||"";$("#t-pri").value=t.priority;$("#t-cat").value=t.category;$("#t-est").value=t.estimate_min??"";
if(t.due_at){const d=new Date(t.due_at);d.setMinutes(d.getMinutes()-d.getTimezoneOffset());$("#t-due").value=d.toISOString().slice(0,16)}}}
const list=tasks.filter(t=>filter==="todas"||(filter==="atrasada"?late(t):t.status===filter));
$("#tl").innerHTML=list.map(t=>`<div class="task ${t.status==="concluida"?"done":""} ${late(t)?"late":""}"><div><div class="t"><b>${esc(t.title)}</b></div><div class="row"><span class="tag ${t.priority==="alta"?"alta":""}">${t.priority}</span><span class="tag">${esc(t.category)}</span><span class="mut">${fmt(t.due_at)}</span></div></div>
<div class="row">${t.status==="pendente"?`<button class="btn sm" data-a="done" data-id="${t.id}">Concluir</button><button class="btn ghost sm" data-a="edit" data-id="${t.id}">Editar</button>`:""}<button class="btn ghost sm" data-a="del" data-id="${t.id}">Excluir</button></div></div>`).join("")||'<p class="mut">Nenhuma tarefa neste filtro.</p>';
document.querySelectorAll("[data-a]").forEach(b=>b.onclick=()=>taskAction(b.dataset.a,b.dataset.id))}
async function saveTask(e){e.preventDefault();const title=$("#t-title").value.trim();if(!title)return toast("Informe o título.");
const due=$("#t-due").value,row={title,description:$("#t-desc").value.trim()||null,priority:$("#t-pri").value,category:$("#t-cat").value,due_at:due?new Date(due).toISOString():null,estimate_min:$("#t-est").value?+$("#t-est").value:null};
const q=editing?sb.from("tasks").update(row).eq("id",editing).select().single():sb.from("tasks").insert(row).select().single();
const{data,error}=await q;if(error)return fail("Não foi possível salvar a tarefa",error);
tasks=editing?tasks.map(t=>t.id===editing?data:t):[...tasks,data];editing=null;Sfx.play("ok");toast("Tarefa salva.","ok");tasksView()}
async function taskAction(a,id){if(a==="edit"){editing=id;return tasksView()}
if(a==="del"){if(!confirm("Excluir esta tarefa?"))return;const{error}=await sb.from("tasks").delete().eq("id",id);if(error)return fail("Falha ao excluir",error);tasks=tasks.filter(t=>t.id!==id);toast("Tarefa excluída.","ok");return tasksView()}
const{data,error}=await sb.rpc("complete_task",{p_task_id:id});if(error)return fail("Falha ao concluir",error);
const t=tasks.find(x=>x.id===id);if(t)t.status="concluida";profile={...profile,xp:data.xp,level:data.level};
toast(data.xp_gained?`+${data.xp_gained} XP!`:"Esta tarefa já havia gerado XP.","ok");Sfx.play("xp");if(data.leveled_up){toast(`Subiu para o nível ${data.level}!`,"ok");setTimeout(()=>Sfx.play("level"),350)}tasksView()}
function settingsView(){$("#view").innerHTML=`<h1>Configurações</h1><form id="sf" class="card"><h2>Perfil</h2><label>Nome de jogador</label><input id="s-name" maxlength="40" value="${esc(profile.display_name)}">
<h2 style="margin-top:1rem">Sons</h2><label><input type="checkbox" id="s-snd" style="width:auto" ${S.sound_on?"checked":""}> Sons ativados</label><label>Volume</label><input type="range" id="s-vol" min="0" max="1" step=".05" value="${S.volume}"><button type="button" id="s-test" class="btn ghost sm">Testar som</button>
<h2 style="margin-top:1rem">Lembretes</h2><label><input type="checkbox" id="s-rem" style="width:auto" ${S.reminders_on?"checked":""}> Lembretes ativados</label><label>Antecedência padrão</label><select id="s-lead">${[[0,"No horário do prazo"],[5,"5 min antes"],[10,"10 min antes"],[15,"15 min antes"],[30,"30 min antes"],[60,"1 hora antes"],[1440,"1 dia antes"],[-1,"Sem lembretes"]].map(([v,l])=>`<option value="${v}" ${S.reminder_lead_min==v?"selected":""}>${l}</option>`).join("")}</select>
<label><input type="checkbox" id="s-rsnd" style="width:auto" ${S.reminder_sound?"checked":""}> Som nos lembretes</label><div class="row" style="margin-top:1rem"><button class="btn">Salvar configurações</button><button type="button" id="s-perm" class="btn ghost">Permitir notificações do navegador</button></div></form>`;
$("#s-test").onclick=()=>{Sfx.config({sound_on:true,volume:$("#s-vol").value});Sfx.play("level",true)};
$("#s-perm").onclick=async()=>{if(!("Notification"in window))return toast("Navegador sem suporte.");toast("Permissão: "+await Notification.requestPermission(),"ok")};
$("#sf").onsubmit=async e=>{e.preventDefault();const name=$("#s-name").value.trim();if(!name)return toast("Informe um nome.");
const ns={user_id:(await sb.auth.getUser()).data.user.id,sound_on:$("#s-snd").checked,volume:+$("#s-vol").value,reminders_on:$("#s-rem").checked,reminder_lead_min:+$("#s-lead").value,reminder_sound:$("#s-rsnd").checked,updated_at:new Date().toISOString()};
const[a,b]=await Promise.all([sb.from("user_settings").upsert(ns),sb.from("profiles").update({display_name:name}).eq("id",ns.user_id)]);
if(a.error||b.error)return fail("Falha ao salvar configurações",a.error||b.error);S={...S,...ns};profile.display_name=name;Sfx.config(S);$("#who").textContent=name;toast("Configurações salvas.","ok")}}
setInterval(()=>{if(!profile||!S.reminders_on||S.reminder_lead_min<0)return;const now=Date.now();
for(const t of tasks){if(t.status!=="pendente"||!t.due_at)continue;const due=new Date(t.due_at).getTime(),at=due-S.reminder_lead_min*6e4,k=t.id+t.due_at+S.reminder_lead_min;
if(now>=at&&now-at<10*6e4&&!fired.has(k)){fired.add(k);const m=`Lembrete: "${t.title}" — prazo ${fmt(t.due_at)}`;toast(m,"err",()=>{location.hash="tarefas"});
if(S.reminder_sound)Sfx.play("remind");if("Notification"in window&&Notification.permission==="granted")new Notification("LEVEL UP",{body:m})}}},20000);
document.addEventListener("DOMContentLoaded",()=>{
$("#af").onsubmit=submitAuth;document.querySelectorAll("[data-m]").forEach(b=>b.onclick=()=>authMode(b.dataset.m));
$("#show").onchange=e=>{$("#a-pass").type=$("#a-pass2").type=e.target.checked?"text":"password"};
$("#logout").onclick=async()=>{await sb.auth.signOut();toast("Você saiu.","ok")};
window.addEventListener("hashchange",()=>profile&&route());
if(!sb){$("#cfg").classList.remove("hidden");$("#auth").classList.add("hidden");return}
sb.auth.onAuthStateChange((ev,s)=>{if(["INITIAL_SESSION","SIGNED_IN","SIGNED_OUT"].includes(ev)){if(ev==="SIGNED_IN"&&profile)return;setTimeout(()=>boot(s),0)}});
});
