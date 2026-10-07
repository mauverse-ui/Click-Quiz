'use strict';
// Update any pre-existing root worker so historical ad code cannot remain active.
if ('serviceWorker' in navigator) navigator.serviceWorker.getRegistrations().then(rs => Promise.all(rs.filter(r => new URL(r.scope).pathname === '/').map(r => r.update()))).catch(() => {});
const app = document.querySelector('#app');
const modal = document.querySelector('#privacy');
const params = new URLSearchParams(location.search);
const VERSION = 'shopping-v1';
const API = 'https://roayyfrgofikkvihimkf.supabase.co/rest/v1';
// Publishable key: grants only the database's explicit anonymous permissions.
const HEADERS = { apikey: 'sb_publishable_x-Zx27BXNq0AVrIXWfe2uw_3cD3CjN0', 'Content-Type': 'application/json' };
let quiz, answers = [], index = 0, started = false, consent = false, asked = false;
let attempt = crypto.randomUUID(), referral = crypto.randomUUID(), seq = 0, queue = [], sending = false, startedAt = Date.now();
const sourceRef = /^[a-f0-9-]{36}$/.test(params.get('ref') || '') ? params.get('ref') : null;
const attribution = Object.fromEntries(['utm_source','utm_medium','utm_campaign','utm_content','utm_term'].filter(k => params.has(k)).map(k => [k, params.get(k).slice(0,120)]));
function read(key) { try { return JSON.parse(sessionStorage.getItem(key)); } catch { return null; } }
function save() { if (!consent) return; try { sessionStorage.setItem('cq-attempt',JSON.stringify({version:VERSION,attempt,referral,answers,index,seq,queue,sourceRef,startedAt})); } catch {} }
function choice(value) { consent = value; asked = true; try { sessionStorage.setItem('cq-consent',value ? 'true' : 'false'); if (!value) sessionStorage.removeItem('cq-attempt'); } catch {} }
consent = read('cq-consent') === true; asked = read('cq-consent') !== null;
const saved = consent ? read('cq-attempt') : null;
if (saved?.version === VERSION && (saved.sourceRef || null) === sourceRef && Date.now() - saved.startedAt < 86400000 && /^[a-f0-9-]{36}$/.test(saved.attempt) && Array.isArray(saved.answers) && saved.answers.length <= 10 && saved.answers.every(a => a === 0 || a === 1)) {
  startedAt=saved.startedAt;attempt=saved.attempt;referral=saved.referral;answers=saved.answers;index=Math.min(saved.index||0,9);seq=saved.seq||0;queue=Array.isArray(saved.queue)?saved.queue:[];
}
const escape = s => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
async function rpc(name, body) {
  const r = await fetch(`${API}/rpc/${name}`,{method:'POST',headers:HEADERS,body:JSON.stringify(body),signal:AbortSignal.timeout(7000),keepalive:true});
  if (!r.ok) throw new Error('Analytics unavailable');
  return r;
}
function track(type, detail={}) { if (!consent || seq >= 60) return; queue.push({seq:seq++,type,...detail});save();void flush(); }
async function flush() {
  if (!consent || sending || !queue.length) return;
  sending=true;
  try { while (consent && queue.length) {
    const batch=queue.slice(0,20); const batchAttempt=attempt;
    await rpc('cq_record_events',{p_attempt:attempt,p_version:VERSION,p_referral:referral,p_source_ref:sourceRef,p_attribution:attribution,p_events:batch});
    if (attempt===batchAttempt) { queue.splice(0,batch.length);save(); }
  } } catch { /* Keep a bounded retry queue for consenting players. Gameplay remains available. */ }
  finally { sending=false; }
}
window.addEventListener('online',flush);
setInterval(flush,15000);
document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='hidden')void flush();});
function adSlot(){return '<aside class="ad-slot" aria-label="Advertisement placeholder"><span class="ad-label">ADVERTISEMENT · PREVIEW</span><div class="ad-frame"><span class="ad-mark" aria-hidden="true">▧</span><strong>Banner space</strong><span>300 × 250</span><small>Preview only · ads aren’t active</small></div></aside>';}
function focusMain(){app.focus({preventScroll:true});window.scrollTo({top:0,behavior:'instant'});}
function begin(){
  started=true;
  if (!answers.length) { track('quiz_started'); if(sourceRef)track('referred_arrival'); }
  if(answers.length===10)result();else renderQuestion(true);
  if(!asked)modal.showModal();
}
function renderQuestion(show=false){
  const q=quiz.questions[index]; const answered=answers[index]!==undefined;
  app.innerHTML=`<section><div class="progress-label"><span>CHALLENGE ${index+1} OF 10</span><span>${index+1 <= 3 ? 'Trust your eye.' : index+1 <= 7 ? 'Look a little closer.' : 'You’re nearly there.'}</span></div><div class="progress" role="progressbar" aria-label="Quiz progress" aria-valuemin="0" aria-valuemax="10" aria-valuenow="${answers.length}"><span style="width:${answers.length*10}%"></span></div><div class="question-icon" aria-hidden="true">${q.icon}</div><h2>${escape(q.title)}</h2><p class="prompt">${escape(q.prompt)}</p><div class="options">${q.options.map((o,i)=>`<button class="option ${answered?(i===q.answer?'correct':i===answers[index]?'wrong':''):''}" data-answer="${i}" ${answered?'disabled':''}><span class="letter">${answered&&i===q.answer?'✓':i===0?'A':'B'}</span><span><strong>${escape(o.label)}</strong><small>${escape(o.detail)}</small><span class="badge">${escape(o.badge)}</span></span></button>`).join('')}</div><div id="feedback" aria-live="polite">${answered?`<div class="feedback"><h3>${answers[index]===q.answer?'Good eye. You got it.':'A little twist there.'}</h3><p>${escape(q.explanation)}</p></div><button class="primary next" id="next">${index===9?'See my score':'Next challenge'} →</button>`:''}</div>${!answered?'<p class="fine">Tap the smarter choice. Prices include tax.</p>':''}${[2,5].includes(index)?adSlot():''}</section>`;
  app.querySelectorAll('[data-answer]').forEach(b=>b.addEventListener('click',()=>answer(Number(b.dataset.answer))));
  document.querySelector('#next')?.addEventListener('click',()=>{ if(index===9)result();else{index++;save();renderQuestion(true);} });
  if(show){track('question_shown',{question:index});focusMain();}
}
function answer(a){
  if(answers[index]!==undefined)return;
  answers[index]=a; track('question_answered',{question:index,answer:a});save();
  renderQuestion();
  document.querySelector('#next').focus({preventScroll:true});
  if(answers.length===10)track('quiz_completed',{answers:[...answers]});
}
function result(){
  const score=answers.reduce((n,a,i)=>n+Number(a===quiz.questions[i].answer),0);
  const title=score===10?'Nothing slipped past you.':score>=7?'You’ve got a sharp shopping eye.':score>=4?'Some smart buys. A few surprises.':'The tiny print had a few tricks.';
  app.innerHTML=`<section class="result"><div class="eyebrow">RECEIPT’S IN. HERE’S YOUR SCORE.</div><div class="result-seal"><div class="score">${score}<span>/10</span></div></div><h1>${title}</h1><p class="lead">Ten little decisions, a few useful lessons.<br>Who’s the sharpest shopper in your group?</p><button class="primary" id="share">Challenge a friend ↗</button><button class="secondary" id="copy">Copy challenge link</button><p id="share-status" class="fine" role="status"></p><input id="share-fallback" class="share-fallback" aria-label="Challenge link to copy" readonly hidden><button class="secondary" id="replay">Play this quiz again</button><p class="fine">Same ten challenges · Shopping edition 1</p>${adSlot()}<div class="review"><h2>Your shopping receipt</h2>${quiz.questions.map((q,i)=>`<details><summary>${answers[i]===q.answer?'✓':'○'} ${i+1}. ${escape(q.title)}</summary><p>Your pick: ${escape(q.options[answers[i]].label)}<br>Correct pick: ${escape(q.options[q.answer].label)}</p><p>${escape(q.explanation)}</p></details>`).join('')}</div></section>`;
  document.querySelector('#share').onclick=()=>share(score);
  document.querySelector('#copy').onclick=()=>copyLink(score);
  document.querySelector('#replay').onclick=()=>{answers=[];index=0;startedAt=Date.now();attempt=crypto.randomUUID();referral=crypto.randomUUID();seq=0;queue=[];save();begin();};
  save();focusMain();
}
function shareUrl(){const url=new URL('/shopping/',location.origin);url.searchParams.set('v',VERSION);url.searchParams.set('ref',referral);return url.href;}
async function share(score){
  track('share_opened');
  if(!navigator.share)return copyLink(score);
  try { await navigator.share({title:'Shopping instincts · Click Quiz',text:`I got ${score}/10 on the shopping quiz. Can you beat me?`,url:shareUrl()});track('share_completed');document.querySelector('#share-status').textContent='Challenge shared. Let the shopping showdown begin.'; }
  catch(e){if(e.name==='AbortError'){track('share_cancelled');return;}await copyLink(score);}
}
async function copyLink(){
  const visibleLink=document.querySelector('#share-fallback');visibleLink.hidden=false;visibleLink.value=shareUrl();
  document.querySelector('#share-status').textContent='Your challenge link is ready below.';
  try{await navigator.clipboard.writeText(shareUrl());track('link_copied');document.querySelector('#share-status').textContent='Link copied. Send it to your sharpest shopper.';}
  catch{const field=document.querySelector('#share-fallback');field.hidden=false;field.value=shareUrl();field.focus();field.select();document.querySelector('#share-status').textContent='Press and hold the link to copy it.';track('copy_fallback_shown');}
}
document.querySelector('#privacy-open').onclick=()=>modal.showModal();
document.querySelector('#decline').onclick=()=>{choice(false);queue=[];modal.close();};
document.querySelector('#allow').onclick=()=>{
  const was=consent;choice(true);modal.close();
  if(!was){startedAt=Date.now();attempt=crypto.randomUUID();seq=0;queue=[];track('consent_granted');if(started){track('quiz_started');if(sourceRef)track('referred_arrival');for(let i=0;i<answers.length;i++){track('question_shown',{question:i});track('question_answered',{question:i,answer:answers[i]});}if(answers.length===10)track('quiz_completed',{answers:[...answers]});else track('question_shown',{question:index});}}
};
async function load(){
  if(params.has('v')&&params.get('v')!==VERSION){app.innerHTML='<section><h1>This edition isn’t available.</h1><p>Challenge links keep the original questions. You can start the current shopping edition below.</p><a href="/shopping/">Play the current edition →</a></section>';return;}
  try{
    const r=await fetch('/shopping/shopping-v1.json');if(!r.ok)throw Error();quiz=await r.json();
    if(quiz.version!==VERSION||quiz.questions.length!==10)throw Error();
    const b=document.querySelector('#start');b.disabled=false;b.textContent=answers.length?'Continue my quiz →':'Test my instincts →';b.onclick=begin;
    void flush();
  }catch{document.querySelector('#load-status').textContent='The quiz couldn’t load. Check your connection and reload to try again.';}
}
void load();
