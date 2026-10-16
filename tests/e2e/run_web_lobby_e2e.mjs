// 실제 브라우저(Chromium) 3개로 방 코드 자동 입장(릴레이 + WebRTC)을 검증한다: 방장 1 + 참가자 2(동시 입장).
// 사용법: node run_web_lobby_e2e.mjs <웹 빌드 주소> <playwright-core 위치> <chromium 실행 파일> <릴레이 주소>
import { createRequire } from "node:module";
const [, , baseUrl, pwPath, chromePath, relay] = process.argv;
const require = createRequire(import.meta.url);
const { chromium } = require(pwPath);

const browser = await chromium.launch({
  executablePath: chromePath,
  headless: true,
  args: ["--no-sandbox", "--disable-features=WebRtcHideLocalIpsWithMdns", "--allow-loopback-in-peer-connection", "--use-gl=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
});
const fail = async (message) => { console.error("E2E_FAIL: " + message); await browser.close(); process.exit(1); };
const open = async (name, role) => {
  const page = await (await browser.newContext()).newPage();
  page.on("console", (m) => { if (process.env.E2E_VERBOSE) console.log(`[${name}] ${m.text()}`); });
  page.on("pageerror", (e) => console.log(`[${name}] pageerror ${e}`));
  await page.goto(`${baseUrl}/index.html?role=${role}&relay=${encodeURIComponent(relay)}`);
  await page.waitForFunction(() => window.__ready === true, null, { timeout: 90000 }).catch(() => fail(`${name} 씬이 준비되지 않음`));
  return page;
};
const host = await open("host", "host");
const guestA = await open("guestA", "guest");
const guestB = await open("guestB", "guest");
const seatsOf = (roster) => roster.map((entry) => entry[0]);

// 1) 방장이 만든 5자리 방 코드
await host.waitForFunction(() => typeof window.__roomCode === "string", null, { timeout: 20000 }).catch(() => fail("방 코드가 만들어지지 않음"));
const roomCode = await host.evaluate(() => window.__roomCode);
console.log("room code", roomCode);
if (!/^[2-9A-HJKMNP-Z]{5}$/.test(roomCode)) await fail("방 코드 형식이 올바르지 않음: " + roomCode);

// 2) 잘못된 방 코드는 안내만 하고 실패한다
await guestA.evaluate(() => window.__joinRoom("친구A", "ZZZZZ"));
await guestA.waitForFunction(() => typeof window.__joinFailed === "string", null, { timeout: 20000 }).catch(() => fail("없는 방 코드가 실패로 처리되지 않음"));
console.log("wrong code ->", await guestA.evaluate(() => window.__joinFailed));
await guestA.evaluate(() => { window.__joinFailed = undefined; });

// 3) 방 코드만으로 두 명이 동시에 입장 (자리 선점 경쟁 포함). 방장이 초대를 올릴 시간을 주고 재시도한다
const joinWithRetry = async (page, nickname) => {
  for (let attempt = 0; attempt < 6; attempt++) {
    await page.evaluate(([name, code]) => { window.__joinFailed = undefined; window.__joinRoom(name, code); }, [nickname, roomCode]);
    const outcome = await page.waitForFunction(() => window.__joined === true ? "joined" : (typeof window.__joinFailed === "string" ? "failed" : false), null, { timeout: 60000 }).then((h) => h.jsonValue()).catch(() => "timeout");
    if (outcome === "joined") return true;
    console.log(`${nickname} attempt ${attempt + 1}:`, outcome, await page.evaluate(() => window.__joinFailed));
    await new Promise((r) => setTimeout(r, 1500));
  }
  return false;
};
const [okA, okB] = await Promise.all([joinWithRetry(guestA, "친구A"), joinWithRetry(guestB, "친구B")]);
if (!okA || !okB) await fail(`방 코드 자동 입장 실패 A=${okA} B=${okB}`);

// 4) 방장 명단에 두 사람이 서로 다른 자리로 들어와 있다
await host.waitForFunction(() => { try { const r = JSON.parse(window.__roster); return r.filter((e) => e[0] === 2).length === 3; } catch (e) { return false; } }, null, { timeout: 20000 }).catch(async () => fail("방장 명단에 참가자 둘이 없음 " + (await host.evaluate(() => window.__roster))));
const hostRoster = JSON.parse(await host.evaluate(() => window.__roster));
console.log("host roster", JSON.stringify(hostRoster));
const names = hostRoster.filter((e) => e[0] === 2 && e[1] !== "방장").map((e) => e[1]).sort();
if (names.join() !== "친구A,친구B") await fail("참가자 닉네임이 방장에게 전달되지 않음: " + names);
const seatA = await guestA.evaluate(() => window.__mySeat);
const seatB = await guestB.evaluate(() => window.__mySeat);
console.log("seats", seatA, seatB);
if (seatA === seatB || seatA < 2 || seatB < 2) await fail("두 참가자가 같은 자리를 받음");
await guestA.waitForFunction(() => { try { return JSON.parse(window.__roster).filter((e) => e[0] === 2).length === 3; } catch (e) { return false; } }, null, { timeout: 15000 }).catch(async () => fail("참가자가 명단을 받지 못함 " + (await guestA.evaluate(() => window.__roster))));

// 5) 남은 자리를 AI 봇으로 채우면 그 초대는 닫힌다 (세 번째 참가자는 들어올 수 없다)
const guestC = await open("guestC", "guest");
const openSeat = hostRoster.findIndex((e) => e[0] === 1) + 1;
if (openSeat < 2) await fail("남은 빈 자리를 찾지 못함 " + JSON.stringify(hostRoster));
await host.evaluate((seat) => window.__fillBot(seat), openSeat);
await host.waitForFunction((seat) => { try { return JSON.parse(window.__roster)[seat - 1][0] === 3; } catch (e) { return false; } }, openSeat, { timeout: 15000 }).catch(() => fail("봇 채우기가 반영되지 않음"));
await new Promise((r) => setTimeout(r, 1500));
await guestC.evaluate((code) => window.__joinRoom("친구C", code), roomCode);
const outcomeC = await guestC.waitForFunction(() => window.__joined === true ? "joined" : (typeof window.__joinFailed === "string" ? "failed" : false), null, { timeout: 60000 }).then((h) => h.jsonValue()).catch(() => "timeout");
console.log("guestC ->", outcomeC, await guestC.evaluate(() => window.__joinFailed));
if (outcomeC !== "failed") await fail("가득 찬 방에 세 번째 참가자가 들어옴/멈춤: " + outcomeC);

// 6) 참가자가 나가면 방장 명단에서 자리가 비고 곧 새 초대로 다시 열린다
await guestA.close();
await host.waitForFunction((seat) => { try { const r = JSON.parse(window.__roster); return r[seat - 1][0] !== 2; } catch (e) { return false; } }, seatA, { timeout: 30000 }).catch(async () => fail("참가자가 나가도 방장 명단이 그대로 " + (await host.evaluate(() => window.__roster))));
console.log("E2E_OK");
await browser.close();
