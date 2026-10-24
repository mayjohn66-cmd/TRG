// File: tests/web/cache_guard_test.mjs
// Role: web/shell.html의 trg-cache-guard 스크립트(캐시 버스팅 + 옛 캐시 청소)를 가짜 브라우저 객체로 돌려 검사한다.
//       실행: node tests/web/cache_guard_test.mjs   (배포 워크플로가 웹 내보내기 전에 돌린다)
import { readFileSync } from "node:fs";
import vm from "node:vm";

const shell = readFileSync(new URL("../../web/shell.html", import.meta.url), "utf8");
const match = shell.match(/<script id="trg-cache-guard">([\s\S]*?)<\/script>/);
if (!match) throw new Error("shell.html에 trg-cache-guard 스크립트가 없다");
const source = match[1];

let failures = 0;
function check(condition, message) {
  if (!condition) {
    failures += 1;
    console.error("CACHE_GUARD_FAIL: " + message);
  }
}

function fakeWindow({ buildId, version, stored }) {
  const storage = new Map(Object.entries(stored));
  const deleted = [];
  const unregistered = [];
  const fetched = [];
  const modules = [];
  class FakeWorklet {}
  FakeWorklet.prototype.addModule = function (url) { modules.push(url); return Promise.resolve(); };
  const window = {
    location: { href: "https://trickcal-board.vercel.app/", origin: "https://trickcal-board.vercel.app" },
    localStorage: {
      getItem: (key) => (storage.has(key) ? storage.get(key) : null),
      setItem: (key, value) => storage.set(key, String(value)),
    },
    caches: {
      keys: () => Promise.resolve(["godot-v1", "old-pwa"]),
      delete: (key) => { deleted.push(key); return Promise.resolve(true); },
    },
    navigator: {
      serviceWorker: {
        getRegistrations: () => Promise.resolve([{ unregister: () => { unregistered.push(1); return Promise.resolve(true); } }]),
      },
    },
    fetch: (input) => { fetched.push(String(input)); return Promise.resolve({ ok: true }); },
    AudioWorklet: FakeWorklet,
    URL,
    setTimeout,
    Promise,
  };
  const code = source.replace("__TRG_BUILD_ID__", buildId).replace("__TRG_VERSION__", version);
  vm.runInNewContext(code, { window, URL, setTimeout, Promise });
  return { window, storage, deleted, unregistered, fetched, modules };
}

// 1) 새 버전: 엔진 파일 주소에 ?v=, 옛 캐시·서비스 워커 정리, 개인 설정은 그대로
{
  const page = fakeWindow({ buildId: "abc1234", version: "0.9.0+abc1234", stored: { trg_cached_version: "0.9.0+0000000", nickname: "말랑", lang: "ja", volume: "0.4" } });
  const guard = page.window.trgCacheGuard;
  check(guard.stamped, "토큰을 채우면 동작한다");
  check(guard.bust("index.wasm") === "https://trickcal-board.vercel.app/index.wasm?v=abc1234", "index.wasm에 ?v=커밋: " + guard.bust("index.wasm"));
  check(guard.bust("index.pck").endsWith("/index.pck?v=abc1234"), "index.pck에 ?v=커밋");
  check(guard.bust("index.audio.worklet.js").endsWith("index.audio.worklet.js?v=abc1234"), "오디오 워클릿에 ?v=커밋");
  check(guard.bust("avatars/erpin.pck?v=0.9.0%2Babc1234") === "avatars/erpin.pck?v=0.9.0%2Babc1234", "이미 쿼리가 있는 아바타 묶음은 그대로");
  check(guard.bust("https://cdn.example.com/x.wasm") === "https://cdn.example.com/x.wasm", "다른 사이트 주소는 그대로");
  check(guard.bust("og-image.png") === "og-image.png", "엔진 파일이 아니면 그대로");
  page.window.fetch("index.pck");
  check(page.fetched[0].endsWith("/index.pck?v=abc1234"), "fetch로 받는 엔진 파일에 버전이 붙는다: " + page.fetched[0]);
  new page.window.AudioWorklet().addModule("index.audio.position.worklet.js");
  check(page.modules[0].endsWith("index.audio.position.worklet.js?v=abc1234"), "addModule에도 버전이 붙는다");
  const cleaned = await guard.clean();
  check(cleaned === true, "새 버전이면 청소한다");
  check(page.deleted.join(",") === "godot-v1,old-pwa", "Cache Storage를 모두 지운다: " + page.deleted.join(","));
  check(page.unregistered.length === 1, "옛 서비스 워커를 해제한다");
  check(page.storage.get("trg_cached_version") === "0.9.0+abc1234", "청소 뒤 현재 버전을 저장한다");
  check(page.storage.get("nickname") === "말랑" && page.storage.get("lang") === "ja" && page.storage.get("volume") === "0.4", "닉네임·언어·볼륨은 그대로");
  // 2) 같은 버전으로 다시 열면 청소하지 않는다
  page.deleted.length = 0;
  check((await guard.clean()) === false && page.deleted.length === 0, "같은 버전이면 그대로 부팅한다");
}

// 3) 로컬 내보내기(토큰을 안 채움): 아무것도 바꾸지 않는다
{
  const page = fakeWindow({ buildId: "__TRG_BUILD_ID__", version: "__TRG_VERSION__", stored: { trg_cached_version: "old" } });
  const guard = page.window.trgCacheGuard;
  check(!guard.stamped, "토큰이 남아 있으면 꺼진다");
  check(guard.bust("index.wasm") === "index.wasm", "로컬에서는 주소를 바꾸지 않는다");
  check((await guard.clean()) === false && page.deleted.length === 0, "로컬에서는 캐시를 지우지 않는다");
}

// 4) 부팅: 엔진이 시작돼도 게임이 첫 화면(셰이더 미리 컴파일)을 마칠 때까지 스플래시를 남기고, 6초 안전장치를 둔다
check(shell.includes("window.trgBootReady = function ()") && shell.includes("if (gameReady) { hideSplash(); } else { setTimeout(hideSplash, 6000); }"), "스플래시는 게임 신호(trgBootReady, 엔진 시작 전에 와도 기억) 또는 6초 뒤에 걷힌다");
check(/function hideSplash\(\) \{\s*if \(splash\.classList\.contains\('hidden'\)\) return;/.test(shell), "스플래시 걷기는 두 번 불려도 한 번만");

if (failures > 0) {
  process.exit(1);
}
console.log("CACHE_GUARD_OK");
