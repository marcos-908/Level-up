const active = new Map();
export function notify(title, message, type='info', dedupeKey='') {
  const region=document.querySelector('#toast-region'); if(!region) return;
  const key=dedupeKey||`${type}:${title}:${message}`; if(active.has(key)) return;
  const node=document.createElement('div'); node.className=`toast ${type}`; node.setAttribute('role',type==='error'?'alert':'status');
  const icon=document.createElement('span');icon.className='toast-icon';icon.textContent=type==='success'?'✓':type==='error'?'!':'✦';
  const content=document.createElement('div');content.className='toast-content';const heading=document.createElement('b');heading.textContent=title;const body=document.createElement('p');body.textContent=message;content.append(heading,body);
  const close=document.createElement('button');close.className='toast-close';close.type='button';close.setAttribute('aria-label','Fechar notificação');close.textContent='×';
  const remove=()=>{if(!node.isConnected)return;node.classList.add('leaving');setTimeout(()=>node.remove(),220);active.delete(key)};close.addEventListener('click',remove);node.append(icon,content,close);region.append(node);active.set(key,node);setTimeout(remove,5500);
}
export function errorMessage(error, fallback='Não foi possível concluir a operação.') {
 const m=String(error?.message||error||''); const l=m.toLowerCase();
 if(l.includes('failed to fetch')||l.includes('network')) return 'Falha de conexão. Verifique a internet e tente novamente.';
 if(l.includes('invalid login credentials')) return 'E-mail ou senha incorretos.';
 if(l.includes('email not confirmed')) return 'Confirme seu e-mail antes de entrar.';
 if(l.includes('already registered')||l.includes('user already registered')) return 'Este e-mail já possui uma conta.';
 if(l.includes('password')&&(l.includes('least')||l.includes('short'))) return 'A senha precisa ter pelo menos 8 caracteres.';
 if(l.includes('rate limit')||l.includes('too many requests')) return 'Muitas tentativas em pouco tempo. Aguarde e tente novamente.';
 if(l.includes('row-level security')||l.includes('permission denied')) return 'O banco bloqueou a operação por segurança. Confira se executou o SQL de configuração.';
 return fallback+(m?` Detalhe: ${m}`:'');
}
