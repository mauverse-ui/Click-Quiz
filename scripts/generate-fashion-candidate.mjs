// Offline by default. Explicit --execute plus approved credentials/budget required.
// Input is an owner-exported aggregate report, never raw sessions or answers.
import fs from 'node:fs/promises';
const [reportPath,manifestPath,outputPath,...flags]=process.argv.slice(2);
if(!reportPath||!manifestPath||!outputPath)throw Error('Usage: node scripts/generate-fashion-candidate.mjs report.json manifest.json candidate.json [--execute]');
const report=JSON.parse(await fs.readFile(reportPath,'utf8'));
const manifest=JSON.parse(await fs.readFile(manifestPath,'utf8'));
if(report.version!==manifest.version)throw Error('Report and manifest version mismatch');
if(report.settled_starts<200){console.log('insufficient_sample_no_change');process.exit(0);}
const metrics=(report.questions||[]).map(q=>Object.fromEntries(['window_name','question','question_id','exposures','answers','observed_stops','continuations','completions','sharers','image_failures','mean_image_ready_ms','a_votes','b_votes'].map(k=>[k,q[k]])));
const aggregate={version:report.version,settled_starts:report.settled_starts,completions:report.completions,sharers:report.sharers,questions:metrics};
const candidates=metrics.filter(q=>q.window_name==='recent_50'&&q.exposures>=30).map(q=>{const previous=metrics.find(p=>p.window_name==='earlier'&&p.question_id===q.question_id);return {...q,answer_rate:q.answers/q.exposures,decline:previous?.exposures>=50?previous.answers/previous.exposures-q.answers/q.exposures:null};});
const diagnosis={state:'candidate_review_required',eligible_recent_questions:candidates,limits:'Associations only; inspect position, load, ad adjacency and source/campaign drift. Do not invent statistics.'};
if(!flags.includes('--execute')){await fs.writeFile(outputPath,JSON.stringify(diagnosis,null,2));console.log('Wrote aggregate diagnosis; no model call or release change.');process.exit(0);}
if(process.env.CQ_AI_SPEND_APPROVED!=='true'||!process.env.OPENAI_API_KEY||!process.env.CQ_OPTIMIZER_MODEL)throw Error('AI disabled: supply an approved spend cap/project, OPENAI_API_KEY, CQ_OPTIMIZER_MODEL and CQ_AI_SPEND_APPROVED=true. No request made.');
const schema={type:'object',additionalProperties:false,properties:{hypothesis:{type:'string'},reordered_ids:{type:'array',items:{type:'string'},minItems:10,maxItems:10},copy_changes:{type:'array',maxItems:2,items:{type:'object',additionalProperties:false,properties:{original_id:{type:'string'},title:{type:'string'}},required:['original_id','title']}}},required:['hypothesis','reordered_ids','copy_changes']};
const response=await fetch('https://api.openai.com/v1/responses',{method:'POST',headers:{Authorization:`Bearer ${process.env.OPENAI_API_KEY}`,'Content-Type':'application/json'},signal:AbortSignal.timeout(60000),body:JSON.stringify({model:process.env.CQ_OPTIMIZER_MODEL,store:false,max_output_tokens:1800,input:[{role:'system',content:'Propose one restrained women’s fashion preference-quiz experiment from aggregate evidence. No correct answers, superiority, demographic inference, false crowd claims or causal assertions. Reuse existing reviewed outfit images/options. Prefer patterns supported by cumulative and recent evidence. Change order or up to two question titles, not both. Distinguish question effects from position, load and ad effects. Return a testable hypothesis. Never claim a proposed change is proven.'},{role:'user',content:JSON.stringify({aggregate,diagnosis,manifest})}],text:{format:{type:'json_schema',name:'fashion_candidate',strict:true,schema}}})});
if(!response.ok)throw Error(`Model request failed (${response.status}); no candidate registered`);
const data=await response.json();if(data.status!=='completed')throw Error('Incomplete model output; no release change');
const text=data.output?.flatMap(x=>x.content||[]).filter(x=>x.type==='output_text').map(x=>x.text).join('');
const draft=JSON.parse(text);const ids=manifest.questions.map(q=>q.id);
if(new Set(draft.reordered_ids).size!==10||draft.reordered_ids.some(id=>!ids.includes(id)))throw Error('Invalid candidate question set');
if(draft.copy_changes.length&&draft.reordered_ids.some((id,i)=>id!==ids[i]))throw Error('Only one experimental change class allowed');
const suffix=Date.now().toString(36);const candidate={...manifest,version:`fashion-${suffix}`,questions:draft.reordered_ids.map(id=>structuredClone(manifest.questions.find(q=>q.id===id)))};
for(const change of draft.copy_changes){const q=candidate.questions.find(q=>q.id===change.original_id);if(!q||change.title.length<5||change.title.length>160)throw Error('Invalid copy change');q.title=change.title;q.id=`${q.id}-${suffix}`;}
await fs.writeFile(outputPath,JSON.stringify({manifest:candidate,hypothesis:draft.hypothesis,review_required:true},null,2));
console.log('Wrote validated candidate draft. Not registered, routed or published.');
