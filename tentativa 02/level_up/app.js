"use strict";
const C = window.LEVELUP_CONFIG, $ = s => document.querySelector(s);
const DEF = { sound: true, volume: 0.5, remind: 15, quietStart: "", quietEnd: "", browserNotif: false };
const XP_LEVEL = 100; // 100 XP por nível. O XP em si só é concedido pelo banco (função complete_task).
let sb, user, profile, tasks = [], eng = [], view = "dashboard", editId = null, filter = "all", timer, quiz = null;
const fired = new Set();
const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const cfg = () => ({ ...DEF, ...(profile?.settings || {}) });
const fmt = d => new Date(d).toLocaleString("pt-BR", { dateStyle: "short", timeStyle: "short" });

/* ---------- notificações e som (centralizados) ---------- */
let actx, lastMsg = "", lastAt = 0;
function beep(f = 660, d = .12) {
  const s = cfg(); if (!s.sound) return;
  try { actx = actx || new AudioContext(); const o = actx.createOscillator(), g = actx.createGain();
    o.frequency.value = f; g.gain.value = s.volume * .3; o.connect(g); g.connect(actx.destination); o.start(); o.stop(actx.currentTime + d); } catch (e) {}
}
function toast(msg, kind = "ok") {
  if (msg === lastMsg && Date.now() - lastAt < 2000) return; lastMsg = msg; lastAt = Date.now();
  const t = document.createElement("div"); t.className = "toast " + kind; t.textContent = msg; $("#toasts").append(t);
  beep(kind === "ok" ? 700 : 200, .15); setTimeout(() => t.remove(), 4500);
}
const fail = (what, e) => toast(`${what}: ${e?.message || e}`, "err");

/* ---------- autenticação ---------- */
function init() {
  if (!C.SUPABASE_ANON_KEY) { $("#app").innerHTML = `<div class="card center"><h1>LEVEL UP</h1><p>Falta a chave pública do Supabase. Abra <b>config.js</b> e cole a chave "anon public" em SUPABASE_ANON_KEY.</p></div>`; return; }
  sb = supabase.createClient(C.SUPABASE_URL, C.SUPABASE_ANON_KEY);
  sb.auth.onAuthStateChange((ev, s) => {
    if (ev === "SIGNED_IN" && user && s?.user?.id === user.id) return;
    if (["INITIAL_SESSION", "SIGNED_IN", "SIGNED_OUT"].includes(ev)) setTimeout(() => boot(s?.user), 0);
  });
}
async function boot(u) {
  user = u || null; clearInterval(timer);
  if (!user) { profile = null; tasks = []; eng = []; return renderAuth(); }
  await load(); render(); timer = setInterval(checkReminders, 30000); checkReminders();
}
function renderAuth() {
  $("#app").innerHTML = `<div class="card center"><h1>LEVEL UP</h1>
  <label for="em">E-mail</label><input id="em" type="email" autocomplete="email">
  <label for="pw">Senha (mín. 6 caracteres)</label><input id="pw" type="password" autocomplete="current-password">
  <p><button data-act="login">Entrar</button> <button class="ghost" data-act="signup">Criar conta</button></p></div>`;
}
async function authDo(kind) {
  const email = $("#em").value.trim(), password = $("#pw").value;
  if (!email || password.length < 6) return toast("Informe e-mail e senha com pelo menos 6 caracteres.", "err");
  const { data, error } = kind === "login" ? await sb.auth.signInWithPassword({ email, password }) : await sb.auth.signUp({ email, password });
  if (error) return fail(kind === "login" ? "Falha ao entrar" : "Falha ao criar conta", error);
  if (kind === "signup" && !data.session) toast("Conta criada. Confirme o e-mail para entrar.");
}

/* ---------- dados ---------- */
async function load() {
  const p = await sb.from("lu_profiles").select("*").eq("id", user.id).maybeSingle();
  if (p.error) return fail("Erro ao carregar perfil (o SQL foi executado?)", p.error);
  if (!p.data) { const ins = await sb.from("lu_profiles").insert({ id: user.id, display_name: user.email.split("@")[0] }).select().single();
    if (ins.error) return fail("Erro ao criar perfil", ins.error); profile = ins.data; } else profile = p.data;
  const [t, e] = await Promise.all([
    sb.from("lu_tasks").select("*").order("created_at", { ascending: false }),
    sb.from("lu_english_log").select("*").order("created_at", { ascending: false }).limit(500)]);
  if (t.error) fail("Erro ao carregar tarefas", t.error); else tasks = t.data;
  if (e.error) fail("Erro ao carregar histórico de inglês", e.error); else eng = e.data;
}
const level = () => Math.floor((profile?.xp || 0) / XP_LEVEL) + 1;

/* ---------- telas ---------- */
const NAV = [["dashboard", "Início"], ["tasks", "Tarefas"], ["english", "Inglês"], ["evolution", "Minha Evolução"], ["settings", "Configurações"]];
function render() {
  if (!profile) return;
  const views = { dashboard: vDash, tasks: vTasks, english: vEnglish, evolution: vEvo, settings: vSettings };
  $("#app").innerHTML = `<div class="shell"><nav><h1>LEVEL UP</h1>${NAV.map(([k, n]) => `<button class="${k === view ? "on" : ""}" data-nav="${k}">${n}</button>`).join("")}
  <button class="ghost" data-act="logout" style="margin-top:auto">Sair</button></nav><main>${views[view]()}</main></div>`;
}
const xpBar = () => { const x = profile.xp % XP_LEVEL; return `<div class="bar"><i style="width:${x}%"></i></div><span class="mut">${x}/${XP_LEVEL} XP para o nível ${level() + 1}</span>`; };
function vDash() {
  const pend = tasks.filter(t => t.status !== "done"), next = pend.filter(t => t.due_at).sort((a, b) => new Date(a.due_at) - new Date(b.due_at)).slice(0, 4);
  return `<h2>Olá, ${esc(profile.display_name || "jogador")}</h2>
  <div class="card"><span class="big">Nível ${level()}</span> <span class="mut">${profile.xp} XP no total</span>${xpBar()}</div>
  <div class="grid"><div class="card"><span class="big">${pend.length}</span><div class="mut">tarefas pendentes</div><button class="ghost" data-nav="tasks">Abrir tarefas</button></div>
  <div class="card"><span class="big">${tasks.length - pend.length}</span><div class="mut">tarefas concluídas</div><button class="ghost" data-nav="evolution">Ver evolução</button></div>
  <div class="card"><span class="big">${eng.length}</span><div class="mut">exercícios de inglês feitos</div><button class="ghost" data-nav="english">Praticar inglês</button></div></div>
  <div class="card"><h3>Próximos prazos</h3>${next.length ? next.map(t => `<div class="row"><span>${esc(t.title)}</span><span class="${new Date(t.due_at) < new Date() ? "late" : "mut"}">${fmt(t.due_at)}</span></div>`).join("") : `<p class="mut">Nenhum prazo definido. Crie uma tarefa com data limite na aba Tarefas.</p>`}</div>`;
}
function vTasks() {
  const e = tasks.find(t => t.id === editId) || {}, list = tasks.filter(t => filter === "all" || (filter === "done") === (t.status === "done"));
  const due = e.due_at ? new Date(new Date(e.due_at) - new Date(e.due_at).getTimezoneOffset() * 6e4).toISOString().slice(0, 16) : "";
  const sel = (v, o) => o.map(x => `<option ${x === v ? "selected" : ""}>${x}</option>`).join("");
  return `<h2>Tarefas</h2><form class="card" id="tf"><h3>${editId ? "Editar tarefa" : "Nova tarefa"}</h3>
  <label>Título</label><input name="title" required maxlength="120" value="${esc(e.title)}">
  <div class="grid"><div><label>Categoria</label><select name="category">${sel(e.category, ["estudo", "inglês", "exercício", "trabalho", "pessoal"])}</select></div>
  <div><label>Prioridade (XP: baixa 10, média 20, alta 30)</label><select name="priority">${sel(e.priority || "media", ["baixa", "media", "alta"])}</select></div>
  <div><label>Prazo</label><input type="datetime-local" name="due" value="${due}"></div>
  <div><label>Tempo estimado (min)</label><input type="number" name="est" min="0" max="1440" value="${e.est_min ?? ""}"></div></div>
  <p><button>${editId ? "Salvar alterações" : "Criar tarefa"}</button> ${editId ? `<button type="button" class="ghost" data-act="cancel">Cancelar</button>` : ""}</p></form>
  <div class="card"><label>Filtro</label><select id="flt"><option value="all">Todas</option><option value="open" ${filter === "open" ? "selected" : ""}>Pendentes</option><option value="done" ${filter === "done" ? "selected" : ""}>Concluídas</option></select>
  ${list.length ? list.map(t => `<div class="row ${t.status === "done" ? "done" : ""}"><span><b>${esc(t.title)}</b><br><span class="mut">${esc(t.category)} · ${esc(t.priority)}${t.due_at ? " · " + fmt(t.due_at) : ""}${t.est_min ? " · " + t.est_min + " min" : ""}</span></span>
  <span>${t.status !== "done" ? `<button data-act="done" data-id="${t.id}">Concluir</button> <button class="ghost" data-act="edit" data-id="${t.id}">Editar</button> ` : ""}<button class="ghost" data-act="del" data-id="${t.id}">Excluir</button></span></div>`).join("") : `<p class="mut">Nada por aqui. Crie sua primeira tarefa acima.</p>`}</div>`;
}
const BANK = [
  { t: "mc", q: "Choose the correct word: She ___ to school every day.", o: ["go", "goes", "going"], a: 1, x: "Com he/she/it, o verbo no presente ganha -s: goes." },
  { t: "mc", q: "What does \"borrow\" mean?", o: ["emprestar (pegar emprestado)", "comprar", "devolver"], a: 0, x: "Borrow = pegar emprestado. Emprestar a alguém é \"lend\"." },
  { t: "fill", q: "Complete: I have ___ apple. (a / an)", a: "an", x: "Usa-se \"an\" antes de som de vogal: an apple." },
  { t: "fill", q: "Translate to English: \"casa\"", a: "house", alt: ["home"], x: "House ou home são aceitos." },
  { t: "mc", q: "Past tense of \"buy\":", o: ["buyed", "bought", "boughten"], a: 1, x: "Buy é irregular: buy, bought, bought." },
  { t: "fill", q: "Complete: They ___ playing now. (is / are)", a: "are", x: "They combina com \"are\"." }];
function vEnglish() {
  const ok = eng.filter(e => e.correct).length, week = eng.filter(e => Date.now() - new Date(e.created_at) < 6048e5).length;
  if (!quiz) quiz = { i: Math.floor(Math.random() * BANK.length), res: null };
  const b = BANK[quiz.i], r = quiz.res;
  const body = b.t === "mc" ? b.o.map((o, i) => `<button class="opt ${r ? (i === b.a ? "good" : i === r.pick ? "bad" : "") : ""}" data-act="ans" data-v="${i}" ${r ? "disabled" : ""}>${esc(o)}</button>`).join("")
    : `<input id="fa" ${r ? "disabled" : ""} autocomplete="off" value="${esc(r?.pick || "")}"> ${r ? "" : `<button data-act="ans">Responder</button>`}`;
  return `<h2>Inglês</h2><div class="grid"><div class="card"><span class="big">${eng.length ? Math.round(ok / eng.length * 100) + "%" : "–"}</span><div class="mut">de acertos (${eng.length} respostas)</div></div>
  <div class="card"><span class="big">${week}/10</span><div class="mut">exercícios nos últimos 7 dias (meta semanal)</div></div></div>
  <div class="card"><h3>${esc(b.q)}</h3>${body}${r ? `<p><b>${r.ok ? "Correto!" : "Resposta correta: " + esc(b.t === "mc" ? b.o[b.a] : b.a)}</b><br>${esc(b.x)}</p><button data-act="nextq">Próxima</button>` : ""}</div>`;
}
function vEvo() {
  const days = [...Array(7)].map((_, i) => { const d = new Date(); d.setHours(0, 0, 0, 0); d.setDate(d.getDate() - 6 + i); return d; });
  const cnt = days.map(d => tasks.filter(t => t.completed_at && new Date(t.completed_at) >= d && new Date(t.completed_at) < new Date(+d + 864e5)).length), mx = Math.max(1, ...cnt);
  const done = tasks.filter(t => t.status === "done").length, ok = eng.filter(e => e.correct).length;
  const empty = !done && !eng.length;
  return `<h2>Minha Evolução</h2><div class="card"><span class="big">Nível ${level()}</span> <span class="mut">${profile.xp} XP</span>${xpBar()}</div>
  <div class="grid"><div class="card"><span class="big">${done}</span><div class="mut">tarefas concluídas</div></div><div class="card"><span class="big">${eng.length ? ok + "/" + eng.length : "–"}</span><div class="mut">acertos em inglês</div></div></div>
  <div class="card"><h3>Tarefas concluídas nos últimos 7 dias</h3><div class="cols">${cnt.map(c => `<div style="height:${c / mx * 100}%" title="${c}"></div>`).join("")}</div>
  <div class="cols" style="height:auto">${days.map(d => `<span class="mut" style="flex:1;text-align:center">${d.toLocaleDateString("pt-BR", { weekday: "short" })}</span>`).join("")}</div>
  ${empty ? `<p class="mut">Ainda sem histórico. Conclua uma tarefa ou responda exercícios de inglês para começar.</p>` : ""}</div>`;
}
function vSettings() {
  const s = cfg(), perm = "Notification" in window ? Notification.permission : "indisponível";
  return `<h2>Configurações</h2><form class="card" id="sf"><label>Nome de exibição</label><input name="name" maxlength="40" value="${esc(profile.display_name)}">
  <label><input type="checkbox" name="sound" style="width:auto" ${s.sound ? "checked" : ""}> Sons ligados</label>
  <label>Volume</label><input type="range" name="volume" min="0" max="1" step="0.05" value="${s.volume}">
  <label>Lembrete de prazo</label><select name="remind">${[[0, "No horário do prazo"], [5, "5 minutos antes"], [10, "10 minutos antes"], [15, "15 minutos antes"], [30, "30 minutos antes"], [60, "1 hora antes"], [1440, "1 dia antes"], [-1, "Sem lembretes"]].map(([v, n]) => `<option value="${v}" ${+s.remind === v ? "selected" : ""}>${n}</option>`).join("")}</select>
  <div class="grid"><div><label>Silêncio a partir de</label><input type="time" name="qs" value="${s.quietStart}"></div><div><label>Silêncio até</label><input type="time" name="qe" value="${s.quietEnd}"></div></div>
  <p class="mut">Notificações do navegador: ${perm}. ${perm === "default" ? `<button type="button" class="ghost" data-act="perm">Permitir</button>` : ""}<br>Lembretes só funcionam com o app aberto.</p>
  <p><button>Salvar configurações</button></p></form>`;
}

/* ---------- lembretes (app aberto) ---------- */
function quiet() {
  const s = cfg(); if (!s.quietStart || !s.quietEnd) return false;
  const n = new Date(), m = n.getHours() * 60 + n.getMinutes(), f = x => +x.slice(0, 2) * 60 + +x.slice(3, 5), a = f(s.quietStart), b = f(s.quietEnd);
  return a <= b ? m >= a && m < b : m >= a || m < b;
}
function checkReminders() {
  const s = cfg(); if (+s.remind < 0 || quiet()) return;
  tasks.filter(t => t.status !== "done" && t.due_at && !fired.has(t.id)).forEach(t => {
    const at = new Date(t.due_at) - s.remind * 6e4;
    if (Date.now() >= at && Date.now() < +new Date(t.due_at) + 36e5) {
      fired.add(t.id); toast(`Prazo: "${t.title}" — ${fmt(t.due_at)}`, "err");
      if (s.browserNotif && "Notification" in window && Notification.permission === "granted") new Notification("LEVEL UP", { body: t.title });
    }
  });
}

/* ---------- ações ---------- */
async function act(a, el) {
  const id = el.dataset.id;
  if (a === "login" || a === "signup") return authDo(a);
  if (a === "logout") { const { error } = await sb.auth.signOut(); if (error) fail("Falha ao sair", error); return; }
  if (a === "edit") { editId = id; return render(); }
  if (a === "cancel") { editId = null; return render(); }
  if (a === "del") { if (!confirm("Excluir esta tarefa?")) return;
    const { error } = await sb.from("lu_tasks").delete().eq("id", id); if (error) return fail("Falha ao excluir", error);
    tasks = tasks.filter(t => t.id !== id); toast("Tarefa excluída."); return render(); }
  if (a === "done") { const { data, error } = await sb.rpc("complete_task", { t: id }); if (error) return fail("Falha ao concluir", error);
    await load(); render(); toast(data > 0 ? `Tarefa concluída! +${data} XP` : "Tarefa já estava concluída."); if (data > 0) beep(880, .2); return; }
  if (a === "nextq") { quiz = null; return render(); }
  if (a === "ans") { const b = BANK[quiz.i]; let pick, ok;
    if (b.t === "mc") { pick = +el.dataset.v; ok = pick === b.a; } else { pick = $("#fa").value.trim(); if (!pick) return toast("Digite uma resposta.", "err"); ok = [b.a, ...(b.alt || [])].includes(pick.toLowerCase()); }
    const { data, error } = await sb.from("lu_english_log").insert({ question: b.q, correct: ok }).select().single(); if (error) return fail("Falha ao registrar resposta", error);
    eng.unshift(data); quiz.res = { ok, pick }; render(); return toast(ok ? "Acertou!" : "Errou. Veja a explicação.", ok ? "ok" : "err"); }
  if (a === "perm") { const p = await Notification.requestPermission(); const cur = cfg(); await saveSettings({ ...cur, browserNotif: p === "granted" }, profile.display_name); }
}
async function saveSettings(settings, name) {
  const { data, error } = await sb.from("lu_profiles").update({ settings, display_name: name }).eq("id", user.id).select().single();
  if (error) return fail("Falha ao salvar configurações", error);
  profile = data; fired.clear(); render(); toast("Configurações salvas.");
}
document.addEventListener("click", e => {
  const n = e.target.closest("[data-nav]"); if (n) { view = n.dataset.nav; editId = null; if (view !== "english") quiz = null; return render(); }
  const b = e.target.closest("[data-act]"); if (b) act(b.dataset.act, b).catch(x => fail("Erro inesperado", x));
});
document.addEventListener("change", e => { if (e.target.id === "flt") { filter = e.target.value; render(); } });
document.addEventListener("submit", async e => {
  e.preventDefault(); const f = new FormData(e.target);
  if (e.target.id === "tf") {
    const row = { title: f.get("title").trim(), category: f.get("category"), priority: f.get("priority"), due_at: f.get("due") ? new Date(f.get("due")).toISOString() : null, est_min: f.get("est") ? +f.get("est") : null };
    if (!row.title) return toast("Informe um título.", "err");
    const q = editId ? sb.from("lu_tasks").update(row).eq("id", editId) : sb.from("lu_tasks").insert({ ...row, user_id: user.id });
    const { error } = await q; if (error) return fail("Falha ao salvar tarefa", error);
    const was = editId; editId = null; await load(); render(); toast(was ? "Tarefa atualizada." : "Tarefa criada.");
  }
  if (e.target.id === "sf") {
    const name = f.get("name").trim() || profile.display_name;
    await saveSettings({ ...cfg(), sound: f.get("sound") === "on", volume: +f.get("volume"), remind: +f.get("remind"), quietStart: f.get("qs") || "", quietEnd: f.get("qe") || "" }, name);
  }
});
init();
