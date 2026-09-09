const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const runtime = fs.readFileSync(path.join(__dirname, '../website/public/analytics.js'), 'utf8').replace(/const id = '[^']*';/, "const id = 'G-QATEST1';");
const key = 'profiledock.analytics-consent.v1';
function fixture({choice, at=Date.now(), hostname='kunilingvistador.github.io', broken=false}={}) {
  class Element {
    constructor(tag) { this.tag=tag; this.children=[]; this.events={}; this.hidden=false; }
    append(...nodes) { this.children.push(...nodes); }
    appendChild(node) { this.append(node); }
    setAttribute() {}
    addEventListener(name, callback) { this.events[name]=callback; }
    click() { this.events.click?.({target:this}); }
    focus() {}
    dispatchEvent(event) { this.events[event.type]?.(event); }
    closest() { return this.tag==='a' ? this : null; }
  }
  const data=new Map(); if (choice) data.set(key,JSON.stringify({choice,at}));
  const document = new Element('document');
  document.documentElement={lang:'en'}; document.head=new Element('head'); document.body=new Element('body');
  document.createElement=tag=>new Element(tag); document.title='ProfileDock'; document.referrer='https://www.google.com/search?q=private';
  let cookie='pd_ga=abc; pd_ga_QATEST1=def; unrelated=stay'; const cleared=[];
  Object.defineProperty(document,'cookie',{get:()=>cookie,set:v=>cleared.push(v)});
  let reloads=0;
  const location={hostname,protocol:'https:',pathname:'/ProfileDock/en/',href:`https://${hostname}/ProfileDock/en/?email=private#secret`,reload:()=>reloads++};
  const window=new Element('window');
  const storage={getItem:k=>{if(broken)throw Error('blocked');return data.get(k)||null;},setItem:(k,v)=>{if(broken)throw Error('blocked');data.set(k,v);}};
  vm.runInNewContext(runtime,{window,document,location,localStorage:storage,URL,Date,Element,CustomEvent:class { constructor(type,init){this.type=type;this.detail=init.detail;} }});
  const toggle={click:()=>document.events['profiledock:analytics-toggle']()};
  const commands=()=>Array.from(window.dataLayer||[],x=>Array.from(x));
  return {window,document,data,toggle,commands,cleared,reloads:()=>reloads};
}
test('default startup needs no interaction and creates no banner or floating button',()=>{
 for(const options of [{},{choice:'granted'}]) {
  const f=fixture(options);assert.equal(f.document.head.children.length,1);assert.equal(f.document.body.children.length,0);
 }
});
test('saved refusals including older versions stay off; unreadable storage fails closed',()=>{
 for(const options of [{choice:'denied'},{choice:'denied',at:1},{broken:true}]) {
  const f=fixture(options);assert.equal(f.document.head.children.length,0);assert.equal(f.commands().length,0);
 }
});
test('default startup sends one sanitized view; a saved refusal can be explicitly reversed',()=>{
 const f=fixture();
 const off=fixture({choice:'denied'});off.toggle.click();assert.equal(off.document.head.children.length,1);off.window.events.storage({key});assert.equal(off.document.head.children.length,1);
 assert.equal(f.document.head.children.length,1);
 const events=f.commands().filter(x=>x[0]==='event');assert.equal(events.length,1);assert.equal(events[0][1],'page_view');
 assert.equal(events[0][2].page_location,'https://kunilingvistador.github.io/ProfileDock/en/');assert.equal(events[0][2].page_referrer,'https://www.google.com/');
 const config=f.commands().find(x=>x[0]==='config')[2];assert.equal(config.send_page_view,false);assert.equal(config.allow_google_signals,false);assert.equal(config.allow_ad_personalization_signals,false);assert.equal(config.cookie_path,'/ProfileDock/');
 assert(!JSON.stringify(f.commands()).includes('private'));
});
test('revoking stops dispatch, clears only project cookies and reloads the loaded document',()=>{
 const f=fixture({choice:'granted'});const count=f.commands().length;f.toggle.click();
 assert.equal(f.window['ga-disable-G-QATEST1'],true);assert.equal(f.commands().length,count);assert.equal(f.reloads(),1);
 assert(f.cleared.every(x=>x.startsWith('pd_ga')));assert.equal(f.cleared.length,2);
});
test('cross-tab withdrawal stops a previously loaded tag; local preview never sends traffic',()=>{
 const f=fixture({choice:'granted'});f.data.set(key,JSON.stringify({choice:'denied',at:Date.now()}));f.window.events.storage({key});assert.equal(f.reloads(),1);assert.equal(f.window['ga-disable-G-QATEST1'],true);
 const local=fixture({choice:'granted',hostname:'localhost'});assert.equal(local.document.head.children.length,0);assert.equal(local.commands().length,0);
});
test('only release links emit a sanitized download click, and withdrawal stops clicks',()=>{
 const f=fixture({choice:'granted'});
 const click=href=>{const link=f.document.createElement('a');link.href=href;f.document.events.click({target:link});};
 click('https://github.com/kunilingvistador/ProfileDock/issues');
 click('https://github.com/kunilingvistador/ProfileDock/releases-fake');
 click('https://example.com/kunilingvistador/ProfileDock/releases');
 assert.equal(f.commands().filter(x=>x[0]==='event').length,1);
 click('https://github.com/kunilingvistador/ProfileDock/releases/tag/v0.1.6-beta?private=value#secret');
 const events=f.commands().filter(x=>x[1]==='download_click');assert.equal(events.length,1);
 assert.equal(events[0][2].destination,'github_releases');assert(!JSON.stringify(events).includes('private'));assert(!JSON.stringify(events).includes('secret'));
 f.toggle.click();click('https://github.com/kunilingvistador/ProfileDock/releases');
 assert.equal(f.commands().filter(x=>x[1]==='download_click').length,1);
});
