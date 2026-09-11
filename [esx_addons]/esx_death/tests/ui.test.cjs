// Run: node --test tests/ui.test.cjs
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const vm = require('node:vm');
const app = readFileSync(require('node:path').join(__dirname, '../web/app.js'), 'utf8');
function setup() {
  let now = 0, sequence = 0;
  const frames = new Map(), requests = [], nodes = new Map();
  class Element {
    constructor() { this.handlers = {}; this.style = { setProperty(k,v) { this[k]=v; } }; this.hidden = true; this.disabled = false; this.textContent = ''; }
    addEventListener(name, fn) { (this.handlers[name] ||= []).push(fn); }
    fire(name, data = {}) { for (const fn of this.handlers[name] || []) fn({ preventDefault() {}, ...data }); }
    setAttribute(name, value) { this[name] = value; }
    replaceChildren(...children) { this.textContent = children.map(x => x.textContent).join(''); }
    setPointerCapture() {}
  }
  const get = id => { if (!nodes.has(id)) nodes.set(id,new Element()); return nodes.get(id); };
  const window = new Element(), document = new Element();
  Object.assign(document, {getElementById:get, querySelector:get, documentElement:new Element(),
    createElement:()=>new Element(), createTextNode:text=>({textContent:text})});
  const ctx = {window,document,location:{search:'?preview'},URLSearchParams, GetParentResourceName:()=> 'esx_death',
    fetch:async(url,options)=>{requests.push({url,...options});return {json:async()=>({ok:true})};},
    requestAnimationFrame:fn=>{const id=++sequence;frames.set(id,fn);return id;}, cancelAnimationFrame:id=>frames.delete(id),
    performance:{now:()=>now}, setInterval:()=>{}, clearInterval:()=>{}};
  vm.runInNewContext(app,ctx);
  const tick = ms => {now+=ms;const callbacks=[...frames.values()];frames.clear();for(const fn of callbacks)fn(now);};
  const message = (action,data) => window.fire('message',{data:{action,data}});
  const render = data => message('state',{remaining:660,total:660,earlyRemaining:0,holdDuration:1500,...data});
  return {get,window,requests,tick,message,render};
}
test('NUI stays hidden until a state message; preview cannot activate inside FiveM',()=>{
  const {get,requests}=setup();assert.equal(get('death-screen').hidden,true);assert.equal(requests.length,1);assert.match(requests[0].url,/\/ready$/);
});
test('countdown clamps negatives, formats minutes, and locks early respawn',()=>{
  const s=setup();s.render({remaining:61,earlyRemaining:5});assert.equal(s.get('countdown').textContent,'01:01');assert.ok(s.get('respawn').disabled);
  s.render({remaining:-20,earlyRemaining:0});assert.equal(s.get('countdown').textContent,'00:00');assert.ok(!s.get('respawn').disabled);
});
test('short holds cancel and a completed hold sends exactly one respawn request',()=>{
  const s=setup();s.render();s.window.fire('keydown',{code:'KeyE'});s.tick(1000);s.window.fire('keyup',{code:'KeyE'});s.tick(1000);
  assert.equal(s.requests.length,1);s.window.fire('keydown',{code:'KeyE'});s.tick(1500);s.tick(2000);
  assert.equal(s.requests.filter(r=>r.url.endsWith('/respawn')).length,1);
});
test('blur and hide cancel holds; hidden interface cannot request actions',()=>{
  const s=setup();s.render();s.window.fire('keydown',{code:'KeyE'});s.window.fire('blur');s.tick(2000);assert.equal(s.requests.length,1);
  s.window.fire('keydown',{code:'KeyE'});s.message('hide');s.tick(2000);s.window.fire('keydown',{code:'KeyG'});assert.equal(s.requests.length,1);assert.ok(s.get('death-screen').hidden);
});
test('distress cooldown disables repeated requests and pending respawn blocks actions',()=>{
  const s=setup();s.render({distressRemaining:60});s.window.fire('keydown',{code:'KeyG'});assert.equal(s.requests.length,1);
  s.render({distressRemaining:0});s.window.fire('keydown',{code:'KeyG'});assert.equal(s.requests.length,2);
  s.render({pending:true});assert.ok(s.get('respawn').disabled && s.get('distress').disabled);
});
test('dynamic content stays text and invalid brand CSS is ignored',()=>{
  const s=setup();s.render({location:'<img onerror=attack()>',brand:{color:'url(https://invalid)',bright:'#ffb435'}});
  assert.equal(s.get('location').textContent,'<img onerror=attack()>');s.message('feedback',{bad:true});assert.equal(s.get('feedback').textContent,'');
});
test('death reason renders below actions and clears on hide',()=>{
  const s=setup();s.render({deathReason:'Matado por John Doe'});
  assert.equal(s.get('death-reason').textContent,'Matado por John Doe');
  s.render({deathReason:undefined});assert.equal(s.get('death-reason').textContent,'');
  s.render({deathReason:'Matado por un jugador'});s.message('hide');assert.equal(s.get('death-reason').textContent,'');
});
