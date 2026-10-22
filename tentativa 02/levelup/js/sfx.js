// Sons gerados no navegador (Web Audio). Só tocam após interação do usuário.
window.Sfx=(()=>{let ctx,on=true,vol=.6,last={};
const P={ok:[[660,.08],[880,.12]],xp:[[520,.06],[780,.1]],level:[[440,.1],[554,.1],[660,.1],[880,.25]],error:[[200,.2]],remind:[[880,.1],[880,.1],[1100,.2]]};
return{config(o){on=o.sound_on;vol=+o.volume},
play(n,force){if(!on&&!force)return;const t=Date.now();if(last[n]&&t-last[n]<300)return;last[n]=t;
try{ctx=ctx||new(window.AudioContext||window.webkitAudioContext)();let at=ctx.currentTime;
for(const[f,d]of P[n]||[]){const o=ctx.createOscillator(),g=ctx.createGain();o.type="square";o.frequency.value=f;g.gain.setValueAtTime(vol*.15,at);g.gain.exponentialRampToValueAtTime(.0001,at+d);o.connect(g).connect(ctx.destination);o.start(at);o.stop(at+d);at+=d}}catch(e){}}}})();
