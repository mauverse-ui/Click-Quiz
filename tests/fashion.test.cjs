const test=require('node:test');const assert=require('node:assert/strict');const fs=require('node:fs');
const prefix=fs.existsSync('build/shopping')?'build/':'';
const quiz=JSON.parse(fs.readFileSync(prefix+'shopping/fashion-v1.json'));
test('ten stable visual preferences, no correctness score',()=>{assert.equal(quiz.questions.length,10);for(const q of quiz.questions){assert.equal(q.options.length,2);assert.ok(!('answer'in q));assert.ok(fs.existsSync(prefix+q.image.replace(/^\//,'')));}assert.equal(new Set(quiz.questions.map(q=>q.id)).size,10);});
test('legacy version and preview safeguards remain present',()=>{const js=fs.readFileSync(prefix+'shopping/app.js','utf8');assert.match(js,/PREVIEW \|\| !consent/);assert.match(js,/if\(PREVIEW\)url.searchParams.set\('preview','1'\)/);assert.match(js,/data.n<20/);assert.ok(fs.existsSync(prefix+'shopping/editions/shopping-v1/index.html'));});

test('published edition contents and assets remain byte-for-byte frozen',()=>{const crypto=require('node:crypto');for(const [path,sha] of Object.entries(JSON.parse(fs.readFileSync('tests/frozen-editions.json')))){assert.equal(crypto.createHash('sha256').update(fs.readFileSync(prefix+path)).digest('hex'),sha,path);}});
