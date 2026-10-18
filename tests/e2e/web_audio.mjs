// Exercise the real Sfx.gd in an exported fixture; headless Godot skips playback.
// node web_audio.mjs <fixture build dir> <playwright module> <Chrome exe> [--expect-silence]
import {createRequire} from 'node:module';
import fs from 'node:fs/promises';
import path from 'node:path';
import http from 'node:http';
import assert from 'node:assert/strict';
const require=createRequire(import.meta.url);
const {chromium}=require(process.argv[3]||'playwright');
const root=path.resolve(process.argv[2]);
const server=http.createServer(async(req,res)=>{
 const name=new URL(req.url,'http://localhost').pathname;
 const target=path.resolve(root,'.'+(name==='/'?'/index.html':name));
 if(!target.startsWith(root+path.sep)){res.writeHead(403);res.end();return;}
 try{
  const types={'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.pck':'application/octet-stream'};
  res.setHeader('Content-Type',types[path.extname(target)]||'application/octet-stream');
  res.end(await fs.readFile(target));
 }catch{res.writeHead(404);res.end();}
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
let browser;
try{
 browser=await chromium.launch({executablePath:process.argv[4],headless:true,args:['--enable-unsafe-swiftshader','--autoplay-policy=user-gesture-required']});
 const page=await browser.newPage({viewport:{width:640,height:360}});
 const errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 page.on('console',m=>{if(m.type()==='error'&&!m.text().includes('404'))errors.push(m.text());});
 await page.addInitScript(()=>{
  window.audioMeter={peak:0,contexts:[]};
  const Original=window.AudioContext;
  window.AudioContext=new Proxy(Original,{construct(target,args){
   const ctx=Reflect.construct(target,args);audioMeter.contexts.push(ctx);
   const analyser=ctx.createAnalyser();analyser.fftSize=256;
   const data=new Float32Array(256);
   const connect=AudioNode.prototype.connect;
   AudioNode.prototype.connect=function(...args){
    if(args[0]===ctx.destination)connect.call(this,analyser);
    return connect.apply(this,args);
   };
   setInterval(()=>{analyser.getFloatTimeDomainData(data);for(const v of data)audioMeter.peak=Math.max(audioMeter.peak,Math.abs(v));},5);
   return ctx;
  }});
 });
 await page.goto(`http://127.0.0.1:${server.address().port}/`);
 await page.waitForFunction(()=>window.audioFixtureReady,{},{timeout:30000});
 await page.mouse.click(320,180);
 const command=async value=>{await page.evaluate(v=>window.audioCommand(v),value);await page.waitForTimeout(120);};
 await command('file'); // first host creation is deferred by one frame
 await page.waitForTimeout(350);
 const measure=async event=>{
  await page.evaluate(()=>{audioMeter.peak=0;});
  for(let i=0;i<3;i++)await command(event);
  return page.evaluate(()=>audioMeter.peak);
 };
 const file=await measure('file');const synth=await measure('synth');
 console.log('WEB_AUDIO_PEAKS',JSON.stringify({file,synth}));
 if(process.argv.includes('--expect-silence')){
  assert.equal(file,0,'baseline imported sound is disconnected');
  assert.equal(synth,0,'baseline generated sound is disconnected');
 }else{
  assert(file>0.0001,'imported OGG reaches browser destination');
  assert(synth>0.0001,'generated PCM reaches browser destination');
  await command('mute');await page.waitForTimeout(400);
  assert.equal(await measure('file'),0,'mute suppresses output');
  await command('unmute');assert(await measure('file')>0.0001,'unmute restores output');
  await command('quiet');const quiet=await measure('file');
  await command('loud');const loud=await measure('file');
  assert(quiet>0&&loud>quiet*4,'volume changes affect output');
  for(let i=0;i<5;i++)await command('repeat');
  assert(await measure('synth')>0.0001,'repeated settings keep routing intact');
  const state=await page.evaluate(()=>window.audioFixtureState);
  assert.deepEqual(state,{muted:false,volume:0.8,buses:3,master:'Master',sfx:1,bgm:2});
  console.log('WEB_AUDIO_OK: OGG, generated PCM, mute/unmute, volume, repeated bus setup');
 }
 assert.deepEqual(errors,[]);
}finally{
 if(browser)await browser.close();
 await new Promise(resolve=>server.close(resolve));
}
