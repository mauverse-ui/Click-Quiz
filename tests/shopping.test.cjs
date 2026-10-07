const {test}=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');
const prefix=fs.existsSync('build/shopping')?'build/':'';
const quiz=JSON.parse(fs.readFileSync(prefix+'shopping/shopping-v1.json'));
// Independent integer-cent/unit calculations, not the stored answer key.
const expected=[180/4<375/7.5?0:1,800+400<1100?0:1,1000-(400+200+300)>=100?0:1,2*400<900?0:1,4000*.75<3500-700?0:1,2*200<450?0:1,1800>=2000?0:1,300<500/2?0:1,700<400+500?0:1,400<0?0:1];
test('ten unique, complete challenges with independently calculated official answers',()=>{assert.equal(quiz.questions.length,10);assert.equal(new Set(quiz.questions.map(q=>q.id)).size,10);quiz.questions.forEach((q,i)=>{assert.equal(q.answer,expected[i],q.id);assert.equal(q.options.length,2);assert.ok(q.explanation.length>30);});});
test('scoring handles perfect, zero, and mixed results',()=>{const score=a=>a.reduce((s,x,i)=>s+Number(x===quiz.questions[i].answer),0);assert.equal(score(expected),10);assert.equal(score(expected.map(x=>1-x)),0);assert.equal(score(expected.map((x,i)=>i<6?x:1-x)),6);});
test('shopping page has no ad SDKs, external fonts, crowd stats, or account gate',()=>{const html=fs.readFileSync(prefix+'shopping/editions/shopping-v1/index.html','utf8');assert.doesNotMatch(html,/monetag|al5sm|5gvci|googleapis|percentile|IQ score/);assert.match(html,/No account needed/);});
