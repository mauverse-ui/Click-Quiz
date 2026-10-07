'use strict';
// Update any pre-existing root worker so historical ad code cannot remain active.
if ('serviceWorker' in navigator) navigator.serviceWorker.getRegistrations().then(rs => Promise.all(rs.filter(r => new URL(r.scope).pathname === '/').map(r => r.update()))).catch(() => {});
const app = document.querySelector('#app');
const modal = document.querySelector('#privacy');
const params = new URLSearchParams(location.search);
let VERSION = params.get('v') || 'fashion-v1';
const PREVIEW=params.get('preview')==='1';
if(PREVIEW){const notice=document.createElement('div');notice.className='preview-notice';notice.textContent='Preview · sample data · no votes recorded';document.querySelector('header').after(notice);}
if(params.get('v')==='shopping-v1')location.replace('/shopping/editions/shopping-v1/'+location.search);
const challengeMatch=location.hash.match(/^#c=([a-f0-9-]{36})\.([01]{10})$/);
const friendAnswers=challengeMatch ? [...challengeMatch[2]].map(Number) : null;
const API = 'https://roayyfrgofikkvihimkf.supabase.co/rest/v1';
// Publishable key: grants only the database's explicit anonymous permissions.
const HEADERS = { apikey: 'sb_publishable_x-Zx27BXNq0AVrIXWfe2uw_3cD3CjN0', 'Content-Type': 'application/json' };
let trackingPaused=false;
let quiz, answers = [], index = 0, started = false, consent = false, asked = false;
let attempt = crypto.randomUUID(), referral = crypto.randomUUID(), seq = 0, queue = [], sending = false, startedAt = Date.now();
const sourceRef = /^[a-f0-9-]{36}$/.test(params.get('ref') || '') ? params.get('ref') : null;
const attribution = Object.fromEntries(['utm_source','utm_medium','utm_campaign','utm_content','utm_term'].filter(k => params.has(k)).map(k => [k, params.get(k).slice(0,120)]));
function read(key) { try { return JSON.parse(sessionStorage.getItem(key)); } catch { return null; } }
function save() { if (!consent || trackingPaused) return; try { sessionStorage.setItem('cq-attempt',JSON.stringify({version:VERSION,attempt,referral,answers,index,seq,queue,sourceRef,startedAt,challenge:location.hash,allocation:quiz?.allocation||null})); } catch {} }
function choice(value) { if(PREVIEW)return; consent = value; asked = true; try { sessionStorage.setItem('cq-consent',value ? 'true' : 'false'); if (!value) sessionStorage.removeItem('cq-attempt'); } catch {} }
consent = !PREVIEW && read('cq-consent') === true; asked = PREVIEW || read('cq-consent') !== null;
function restoreAttempt(){
const saved = consent ? read('cq-attempt') : null;
if (saved?.version === VERSION && (saved.sourceRef || null) === sourceRef && saved.challenge === location.hash && Date.now() - saved.startedAt < 86400000 && /^[a-f0-9-]{36}$/.test(saved.attempt) && Array.isArray(saved.answers) && saved.answers.length <= 10 && saved.answers.every(a => a === 0 || a === 1)) {
  if(saved.allocation)quiz.allocation=saved.allocation;startedAt=saved.startedAt;attempt=saved.attempt;referral=saved.referral;answers=saved.answers;index=Math.min(saved.index||0,9);seq=saved.seq||0;queue=Array.isArray(saved.queue)?saved.queue:[];
}
}
const escape = s => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
async function rpc(name, body) {
  const r = await fetch(`${API}/rpc/${name}`,{method:'POST',headers:HEADERS,body:JSON.stringify(body),signal:AbortSignal.timeout(7000),keepalive:true});
  if (!r.ok) throw new Error('Analytics unavailable');
  return r;
}
function voterId(){try{let id=localStorage.getItem('cq-fashion-voter');if(!/^[a-f0-9-]{36}$/.test(id||'')){id=crypto.randomUUID();localStorage.setItem('cq-fashion-voter',id);}return id;}catch{return attempt;}}
function track(type, detail={}) { if (PREVIEW || trackingPaused || !consent || seq >= 60) return; queue.push({seq:seq++,type,...detail});save();void flush(); }
async function flush() {
  if (PREVIEW || !consent || sending || !queue.length) return;
  sending=true;
  try { while (consent && queue.length) {
    const batch=queue.slice(0,20); const batchAttempt=attempt;
    await rpc('cq_record_fashion_events',{p_attempt:attempt,p_version:VERSION,p_referral:referral,p_source_ref:sourceRef,p_attribution:attribution,p_events:batch,p_experiment:quiz?.allocation||null});
    if(batch.some(e=>e.type==='quiz_completed')){await rpc('cq_fashion_vote',{p_voter:voterId(),p_attempt:batchAttempt});}
    if (attempt===batchAttempt) { queue.splice(0,batch.length);save(); }
  } } catch { /* Keep a bounded retry queue for consenting players. Gameplay remains available. */ }
  finally { sending=false; }
}
window.addEventListener('online',flush);
setInterval(flush,15000);
document.addEventListener('visibilitychange',()=>{if(started&&answers.length<10)track(document.visibilityState==='hidden'?'page_hidden':'quiz_resumed',{question:index});if(document.visibilityState==='hidden')void flush();});
function adSlot(){return '<aside class="ad-slot" aria-label="Advertisement placeholder"><span class="ad-label">ADVERTISEMENT · PREVIEW</span><div class="ad-frame"><span class="ad-mark" aria-hidden="true">▧</span><strong>Banner space</strong><span>300 × 250</span><small>Preview only · ads aren’t active</small></div></aside>';}
function focusMain(){app.focus({preventScroll:true});window.scrollTo({top:0,behavior:'instant'});}
function begin(){
  started=true;
  if (!answers.length) { trackingPaused=false;track('quiz_started'); if(sourceRef)track('referred_arrival'); }else if(consent&&!trackingPaused)track('quiz_resumed',{question:index});
  if(answers.length===10)result();else renderQuestion(true);
  if(!asked)modal.showModal();
}
function photo(q,a){return `<span class="outfit ${a?'right':''}"><img src="${q.image}" alt="${escape(q.options[a].detail)}" loading="eager"></span>`;}
function renderQuestion(show=false){
 const q=quiz.questions[index],answered=answers[index]!==undefined;
 app.innerHTML=`<section><div class="progress-label"><span>THE STYLE EDIT</span><span>${String(index+1).padStart(2,'0')} / 10</span></div><div class="progress" role="progressbar" aria-label="Quiz progress" aria-valuemin="0" aria-valuemax="10" aria-valuenow="${answers.length}"><span style="width:${answers.length*10}%"></span></div><h2>${escape(q.title)}</h2><p class="prompt">Which would you wear? Tap your favourite.</p><div class="options">${q.options.map((o,a)=>`<button class="option ${answered&&answers[index]===a?'selected':''}" data-answer="${a}" aria-pressed="${answers[index]===a}" ${answered?'disabled':''}>${photo(q,a)}<strong><span class="letter">${a?'B':'A'}</span>${escape(o.label)}</strong></button>`).join('')}</div><div aria-live="polite">${answered?`<p class="selection-note">${escape(q.options[answers[index]].label)}. Your pick.</p><button class="primary" id="next">${index===9?'See my style edit':'Next look'} →</button>`:'<p class="fine">No right or wrong. Go with what feels like you.</p>'}</div>${[2,5].includes(index)?adSlot():''}</section>`;
 app.querySelectorAll('[data-answer]').forEach(b=>b.onclick=()=>answer(Number(b.dataset.answer)));
 document.querySelector('#next')?.addEventListener('click',()=>{if(index===9)result();else{index++;save();renderQuestion(true);}});
 if(show){track('question_shown',{question:index});focusMain();const shownIndex=index,readyStart=performance.now();const imgs=[...app.querySelectorAll('.outfit img')];Promise.all(imgs.map(img=>img.complete?Promise.resolve():new Promise(resolve=>{img.onload=resolve;img.onerror=resolve;}))).then(()=>{if(index===shownIndex&&started){const ok=imgs.every(img=>img.naturalWidth>0);track(ok?'question_ready':'image_failed',{question:shownIndex,duration_ms:Math.round(performance.now()-readyStart)});}});} 
 if(index<9){const img=new Image();img.src=quiz.questions[index+1].image;}
}
function answer(a){if(answers[index]!==undefined)return;answers[index]=a;track('question_answered',{question:index,answer:a});save();renderQuestion();document.querySelector('#next').focus({preventScroll:true});if(answers.length===10){track('quiz_completed',{answers:[...answers]});}}
function result(){
 const matches=friendAnswers?answers.filter((a,i)=>a===friendAnswers[i]).length:null;
 app.innerHTML=`<section class="result"><p class="eyebrow">TEN CHOICES. ALL YOURS.</p>${matches!==null?`<div class="match-number">${matches*10}<span>%</span></div><h1>Your style match.</h1><p class="lead">You and your friend chose the same look<br>on ${matches} of 10 questions.</p><p class="fine">Based on the selections in their shared link.</p>`:'<h1>Your taste.<br><em>Your style edit.</em></h1><p class="lead">You picked the looks. Now find out<br>who sees style the way you do.</p>'}<div class="result-box"><h3>Would your friend pick the same?</h3><p>Your challenge link shares your ten selections.<br>Anyone with the link can compare after playing.</p><button class="primary" id="share">Share my style challenge ↗</button><button class="secondary" id="copy">Copy my challenge link</button><p id="share-status" class="fine" role="status">Send it in Instagram, a group chat, or anywhere you like.</p><input id="share-fallback" class="share-fallback" aria-label="Challenge link to copy" readonly hidden></div><div class="result-box" id="crowd"><h3>You & the other players</h3><p>Loading this edition’s player choices…</p></div>${adSlot()}<div class="review"><h2>Your ten picks</h2>${quiz.questions.map((q,i)=>`<div class="review-row">${photo(q,answers[i])}<div><strong>${i+1}. ${escape(q.options[answers[i]].label)}</strong><p>${friendAnswers?(answers[i]===friendAnswers[i]?'You both chose this look.':'Your friend chose '+escape(q.options[friendAnswers[i]].label)+'.'):escape(q.options[answers[i]].detail)}</p></div></div>`).join('')}</div><details class="trend-edit"><summary>The autumn edit · why these looks?</summary><p>Our October 2026 edit plays with clean tailoring, richer textures and expressive details. These are outfit ideas, not rules.</p><p><a href="https://www.vogue.com/article/fall-winter-2026-fashion-trends" target="_blank" rel="noopener noreferrer">Vogue, 28 September 2026</a> highlights dark florals, sculptural proportions and updated tailoring in its autumn runway report.</p><p><a href="https://www.whowhatwear.com/fashion/shopping/what-to-buy-in-october-2026" target="_blank" rel="noopener noreferrer">Who What Wear, October 2026</a> includes purple knitwear, brocade and asymmetric skirts in its current shopping edit.</p><p><a href="https://www.whowhatwear.com/fashion/trends/unexpected-autumn-trends-2026" target="_blank" rel="noopener noreferrer">Who What Wear, 2 October 2026</a> flags embellished trainers as an emerging runway-led idea. That is a forecast, not evidence that everyone wears them.</p><p>All outfit visuals are original AI-created illustrations of styling ideas. They are not photographs of these publications’ products.</p></details><button class="secondary" id="replay">Choose again</button><p class="fine">Same ten choices · Your edition stays fixed</p></section>`;
 document.querySelector('#share').onclick=share;document.querySelector('#copy').onclick=copyLink;
 document.querySelector('#replay').onclick=()=>{answers=[];index=0;challengeCode=null;startedAt=Date.now();attempt=crypto.randomUUID();referral=crypto.randomUUID();seq=0;queue=[];save();begin();};save();focusMain();void showCrowd();
}
let challengeCode=null;
function shareUrl(){if(!challengeCode)challengeCode=crypto.randomUUID();const url=new URL('/shopping/',location.origin);url.searchParams.set('v',VERSION);if(PREVIEW)url.searchParams.set('preview','1');url.searchParams.set('ref',referral);url.hash='c='+challengeCode+'.'+answers.join('');return url.href;}
async function share(){track('share_opened');if(!navigator.share)return copyLink();try{await navigator.share({title:'Style Match · Click Quiz',text:'Would we wear the same thing? Pick your looks and see our style match.',url:shareUrl()});track('share_completed');document.querySelector('#share-status').textContent='Challenge shared. Your friend can compare after choosing.';}catch(e){if(e.name==='AbortError'){track('share_cancelled');return;}await copyLink();}}
async function copyLink(){const field=document.querySelector('#share-fallback');field.hidden=false;field.value=shareUrl();try{await navigator.clipboard.writeText(shareUrl());track('link_copied');document.querySelector('#share-status').textContent='Link copied. Paste it into your friend’s chat.';}catch{field.focus();field.select();document.querySelector('#share-status').textContent='Press and hold the link to copy it.';track('copy_fallback_shown');}}
async function showCrowd(){
 const box=document.querySelector('#crowd');if(!box)return;
 try{
  const data=PREVIEW?{n:100,a:[64,38,57,61,43,72,46,34,58,50]}:await (await rpc('cq_fashion_crowd',{p_version:VERSION})).json();
  if(data.n<20){box.innerHTML='<h3>A fresh edit. A growing crowd.</h3><p>Not enough player votes yet. The crowd comparison appears after 20 completed, opted-in votes.</p><p class="fine">Your friend match works right now — with or without analytics.</p>';return;}
  let match=0,ties=0;data.a.forEach((n,i)=>{if(n*2===data.n)ties++;else if(answers[i]===(n*2>data.n?0:1))match++;});
  box.innerHTML=`<h3>You & the other players</h3><p>You picked the majority choice on <strong>${match} of 10</strong> looks.${ties?' '+ties+(ties===1?' look was tied.':' looks were tied.'):''}</p><p class="fine">${PREVIEW?'Sample distribution for design review.':data.n+' opted-in completed votes in this edition.'} One retained vote per browser ID, within 90 days; not a representative population or verified unique people.</p><details><summary>See the vote splits</summary><ol class="crowd-list">${quiz.questions.map((q,i)=>`<li>${i+1}. ${escape(q.options[0].label)} ${Math.round(data.a[i]/data.n*100)}% / ${escape(q.options[1].label)} ${Math.round((data.n-data.a[i])/data.n*100)}%</li>`).join('')}</ol></details>`;

 }catch{box.innerHTML='<h3>Your friend match is ready.</h3><p>Player comparison is temporarily unavailable. Your choices and challenge link still work.</p>';}
}
document.querySelector('#privacy-open').onclick=()=>{if(PREVIEW){document.querySelector('#privacy-status').textContent='Preview mode: no analytics or votes are recorded.';document.querySelector('#allow').disabled=true;}modal.showModal();};
document.querySelector('#decline').onclick=()=>{choice(false);queue=[];modal.close();};
document.querySelector('#allow').onclick=()=>{
 const was=consent;choice(true);modal.close();
 if(!was&&!PREVIEW){startedAt=Date.now();attempt=crypto.randomUUID();seq=0;queue=[];trackingPaused=started&&answers.length>0;if(!trackingPaused){track('consent_granted');if(started){track('quiz_started');if(sourceRef)track('referred_arrival');track('question_shown',{question:index});}}}
};
async function load(){
 if(params.get('v')==='shopping-v1')return;
 try{
  const requested=params.get('v');
  if(requested&&!/^[a-z0-9-]{1,80}$/.test(requested))throw Error('edition');
  try{const r=await rpc('cq_resolve_fashion',{p_requested:requested,p_bucket:crypto.getRandomValues(new Uint32Array(1))[0]%100});quiz=await r.json();}
  catch{const v=requested||'fashion-v1';const r=await fetch(`/shopping/editions/${v}/manifest.json`);if(!r.ok)throw Error('edition');quiz=await r.json();}
  if(!quiz||quiz.kind!=='preferences'||quiz.questions.length!==10||quiz.comparison!=='identical-positions-v1'||(requested&&requested!==quiz.version))throw Error('edition');
  VERSION=quiz.version;restoreAttempt();
  const fixed=new URL(location.href);fixed.searchParams.set('v',VERSION);history.replaceState(null,'',fixed);
  const b=document.querySelector('#start');b.disabled=false;b.textContent=answers.length?'Continue my quiz →':'Find my style match →';b.onclick=begin;
  if(friendAnswers){const p=document.createElement('p');p.className='challenge-note';p.textContent='A friend sent you their style challenge. Pick your looks to see your match.';app.prepend(p);}else if(location.hash){document.querySelector('#load-status').textContent='This challenge link is incomplete. You can still play and share your own.';}
  void flush();
 }catch{app.innerHTML='<section><h1>This edition couldn’t load.</h1><p>Shared challenges keep their original questions. Check your connection and reload, or start the current edit.</p><a href="/shopping/">Play the current edit →</a></section>';}
}
void load();
