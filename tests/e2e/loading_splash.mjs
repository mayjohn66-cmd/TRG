// Render the real export shell with a stub engine, exercising its actual boot callbacks.
// node tests/e2e/loading_splash.mjs <playwright module> <chromium executable> <capture dir>
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import fs from 'node:fs/promises';
import http from 'node:http';
import assert from 'node:assert/strict';
const require = createRequire(import.meta.url);
const { chromium } = require(process.argv[2] || 'playwright');
const web = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../web');
const capture = process.argv[4];
if (capture) await fs.mkdir(capture, { recursive: true });
const stub = `class Engine {
 static getMissingFeatures(){return location.search.includes('missing') ? ['WebGL 2'] : [];}
 startGame(options){window.loadingCallbacks=options; return new Promise((resolve,reject)=>{window.finishLoading=resolve;window.failLoading=reject;});}
}`;
const shell = (await fs.readFile(path.join(web, 'shell.html'),'utf8'))
 .replace('$GODOT_HEAD_INCLUDE','').replace('$GODOT_URL','engine-stub.js')
 .replace('$GODOT_CONFIG','{}').replace('$GODOT_THREADS_ENABLED','false');
const server = http.createServer(async (req,res)=>{
 const name = new URL(req.url,'http://localhost').pathname;
 if (name === '/') {res.setHeader('Content-Type','text/html; charset=utf-8');res.end(shell);return;}
 if (name === '/engine-stub.js') {res.setHeader('Content-Type','text/javascript');res.end(stub);return;}
 if (!['/title-logo.png','/loading-pawn.png','/icon.png'].includes(name)){res.writeHead(404);res.end();return;}
 try {res.setHeader('Content-Type','image/png');res.end(await fs.readFile(path.join(web,name.slice(1))));}
 catch {res.writeHead(404);res.end();}
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
let browser;
try {
 browser = await chromium.launch({headless:true,...(process.argv[3] ? {executablePath:process.argv[3]} : {})});
 const url = `http://127.0.0.1:${server.address().port}/`;
 for (const viewport of [{width:1366,height:768},{width:664,height:526},{width:844,height:390},{width:667,height:375}]) {
  const page = await browser.newPage({viewport});
  const errors=[];page.on('pageerror',error=>errors.push(error.message));
  await page.goto(url);await page.waitForFunction(()=>window.loadingCallbacks);
  assert.equal(await page.locator('#percent').innerText(),'준비 중…');
  assert.equal(await page.locator('#bar').getAttribute('aria-valuenow'),null);
  for (const value of [0,1,61,99,100]) {
   await page.evaluate(value=>window.loadingCallbacks.onProgress(value,100),value);
   await page.waitForTimeout(300);
   assert.equal(await page.locator('#percent').innerText(),`${value}%`);
   assert.equal(await page.locator('#bar').getAttribute('aria-valuenow'),String(value));
   const bar=await page.locator('#bar').boundingBox();const marker=await page.locator('#bar-marker').boundingBox();
   assert(marker.x>=bar.x-3 && marker.x+marker.width<=bar.x+bar.width+3,'pawn stays within rail ends');
  }
  await page.evaluate(()=>window.loadingCallbacks.onProgress(61,100));
  await page.waitForTimeout(300);
  for (const selector of ['.title-logo','#bar-marker','.loading-caption','#tip']) {
   const box=await page.locator(selector).boundingBox();
   assert(box.x>=0 && box.y>=0 && box.x+box.width<=viewport.width+1 && box.y+box.height<=viewport.height+1,`${selector} fits ${viewport.width}x${viewport.height}`);
  }
  assert(await page.locator('#bar-marker img').evaluate(img=>img.complete && img.naturalWidth>0));
  assert(await page.locator('.title-logo').evaluate(img=>img.complete && img.naturalWidth>0));
  if (capture) await page.screenshot({path:path.join(capture,`Loading_Bar_${viewport.width}x${viewport.height}.png`),animations:'disabled'});
  await page.evaluate(()=>window.loadingCallbacks.onProgress(0,0));
  assert.equal(await page.locator('#bar').getAttribute('aria-valuenow'),null);
  assert(await page.locator('#bar').evaluate(el=>el.classList.contains('is-indeterminate')));
  await page.emulateMedia({reducedMotion:'reduce'});
  assert.equal(await page.locator('#bar-fill').evaluate(el=>getComputedStyle(el).animationName),'none');
  await page.evaluate(()=>window.finishLoading());
  await page.waitForTimeout(650);
  assert.equal(await page.locator('#splash').evaluate(el=>getComputedStyle(el).display),'none');
  assert.deepEqual(errors,[]);
  await page.close();
 }
 const page=await browser.newPage({viewport:{width:1366,height:768}});
 await page.goto(url);await page.evaluate(()=>window.failLoading('test connection failure'));
 await page.waitForSelector('#bar.has-error');
 assert((await page.locator('#notice').innerText()).includes('test connection failure'));
 assert.equal(await page.locator('#percent').innerText(),'확인 필요');
 await page.evaluate(()=>window.loadingCallbacks.onProgress(99,100));
 assert.equal(await page.locator('#percent').innerText(),'확인 필요','late progress cannot revive a failed load');
 await page.goto(url+'?missing');await page.waitForSelector('#bar.has-error');
 assert((await page.locator('#notice').innerText()).includes('WebGL 2'));
 console.log('LOADING_SPLASH_OK: actual progress callbacks, 4 viewport sizes, unknown/0/1/61/99/100, reduced motion, completion and errors');
} finally {
 if (browser) await browser.close();
 await new Promise(resolve=>server.close(resolve));
}
