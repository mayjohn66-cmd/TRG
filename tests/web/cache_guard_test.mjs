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

function fakeWindow({ buildId, version, stored, hashes = null, href = "https://trickcal-board.vercel.app/" }) {
  const storage = new Map(Object.entries(stored));
  const deleted = [];
  const unregistered = [];
  const fetched = [];
  const modules = [];
  const persisted = [];
  class FakeWorklet {}
  FakeWorklet.prototype.addModule = function (url) { modules.push(url); return Promise.resolve(); };
  const window = {
    location: { href, origin: new URL(href).origin },
    localStorage: {
      getItem: (key) => (storage.has(key) ? storage.get(key) : null),
      setItem: (key, value) => storage.set(key, String(value)),
    },
    caches: {
      keys: () => Promise.resolve(["godot-v1", "old-pwa"]),
      delete: (key) => { deleted.push(key); return Promise.resolve(true); },
    },
    navigator: {
      storage: { persist: () => { persisted.push(1); return Promise.resolve(true); } },
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
  let code = source.replace("__TRG_BUILD_ID__", buildId).replace("__TRG_VERSION__", version);
  if (hashes !== null) code = code.replace("__TRG_FILE_HASHES__", JSON.stringify(hashes));
  vm.runInNewContext(code, { window, URL, setTimeout, Promise });
  return { window, storage, deleted, unregistered, fetched, modules, persisted };
}

// 1) 새 버전: 엔진 파일 주소에 ?v=, 옛 캐시·서비스 워커 정리, 개인 설정은 그대로
{
  const save = JSON.stringify({ v: 1, player_tag: "K7PQ", nickname: "말랑", cleared_laws: ["LAW_04"] });
  const page = fakeWindow({ buildId: "abc1234", version: "0.9.0+abc1234", stored: { trg_cached_version: "0.9.0+0000000", nickname: "말랑", lang: "ja", volume: "0.4", trg_player_save_v1: save } });
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
  check(page.storage.get("trg_player_save_v1") === save, "영구 기록(trg_player_save_v1)은 새 버전 청소 뒤에도 그대로");
  check(page.persisted.length >= 1, "브라우저에 보존 저장소를 요청한다 (공간 정리 때 지워지지 않게)");
  check(!/localStorage\.clear\s*\(/.test(shell), "청소 스크립트는 localStorage.clear()를 부르지 않는다");
  // 2) 같은 버전으로 다시 열면 청소하지 않는다
  page.deleted.length = 0;
  check((await guard.clean()) === false && page.deleted.length === 0, "같은 버전이면 그대로 부팅한다");
}

// 1b) 내용 해시 표: 표에 있는 파일은 ?v=해시 (게임이 붙인 ?v=버전도 바꾼다), 없는 파일은 예전처럼 ?v=커밋
{
  const hashes = { "index.wasm": "aaaa11112222", "index.pck": "bbbb22223333", "index.audio.worklet.js": "cccc33334444", "avatars/erpin.pck": "dddd44445555" };
  const page = fakeWindow({ buildId: "abc1234", version: "0.9.0+abc1234", stored: {}, hashes });
  const guard = page.window.trgCacheGuard;
  check(guard.bust("index.wasm") === "https://trickcal-board.vercel.app/index.wasm?v=aaaa11112222", "index.wasm에 ?v=내용 해시: " + guard.bust("index.wasm"));
  check(guard.bust("index.pck").endsWith("/index.pck?v=bbbb22223333"), "index.pck에 ?v=내용 해시");
  check(guard.bust("index.audio.worklet.js").endsWith("/index.audio.worklet.js?v=cccc33334444"), "오디오 워클릿에 ?v=내용 해시");
  check(guard.bust("index.audio.position.worklet.js").endsWith("/index.audio.position.worklet.js?v=abc1234"), "표에 없는 엔진 파일은 ?v=커밋");
  check(guard.bust("https://trickcal-board.vercel.app/avatars/erpin.pck?v=0.9.0%2Babc1234") === "https://trickcal-board.vercel.app/avatars/erpin.pck?v=dddd44445555", "게임이 ?v=버전을 붙인 아바타 묶음도 내용 해시로 바꾼다: " + guard.bust("https://trickcal-board.vercel.app/avatars/erpin.pck?v=0.9.0%2Babc1234"));
  check(guard.bust("avatars/other.pck?v=0.9.0%2Babc1234") === "avatars/other.pck?v=0.9.0%2Babc1234", "표에 없고 쿼리가 있는 묶음은 그대로");
  page.window.fetch("index.wasm");
  check(page.fetched[0].endsWith("/index.wasm?v=aaaa11112222"), "fetch로 받는 엔진 파일에 내용 해시가 붙는다: " + page.fetched[0]);
  // 다음 배포(커밋·버전이 달라도) 내용이 같으면 주소가 같다 = 브라우저 캐시를 그대로 쓴다
  const next = fakeWindow({ buildId: "def5678", version: "0.9.0+def5678", stored: {}, hashes });
  check(next.window.trgCacheGuard.bust("index.wasm") === guard.bust("index.wasm"), "내용이 같은 index.wasm은 배포가 바뀌어도 같은 주소");
  // GitHub Pages 하위 경로(/TRG/)에서도 페이지 폴더 기준으로 찾는다
  const sub = fakeWindow({ buildId: "abc1234", version: "0.9.0+abc1234", stored: {}, hashes, href: "https://example.github.io/TRG/index.html" });
  check(sub.window.trgCacheGuard.bust("index.wasm") === "https://example.github.io/TRG/index.wasm?v=aaaa11112222", "하위 경로 페이지에서도 해시: " + sub.window.trgCacheGuard.bust("index.wasm"));
  check(sub.window.trgCacheGuard.bust("avatars/erpin.pck?v=1") === "https://example.github.io/TRG/avatars/erpin.pck?v=dddd44445555", "하위 경로의 아바타 묶음도 해시");
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
check(shell.includes('<script src="$GODOT_URL?v=__TRG_HASH_INDEX_JS__"></script>'), "index.js는 내용 해시로 받는다");
check(shell.includes("JSON.parse('__TRG_FILE_HASHES__')"), "해시 표 자리(__TRG_FILE_HASHES__)가 작은따옴표 문자열 안에 있다");
check(shell.includes("window.trgBootReady = function ()") && shell.includes("if (gameReady) { hideSplash(); } else { setTimeout(hideSplash, 6000); }"), "스플래시는 게임 신호(trgBootReady, 엔진 시작 전에 와도 기억) 또는 6초 뒤에 걷힌다");
check(/function hideSplash\(\) \{\s*if \(splash\.classList\.contains\('hidden'\)\) return;/.test(shell), "스플래시 걷기는 두 번 불려도 한 번만");

if (failures > 0) {
  process.exit(1);
}
console.log("CACHE_GUARD_OK");
