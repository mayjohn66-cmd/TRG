// 실제 브라우저(Chromium) 두 개로 WebRTC 로비 연결을 검증한다.
// 사용법: node run_web_lobby_e2e.mjs <웹 빌드 폴더(http로 서빙 중인 주소)> <playwright-core 위치> <chromium 실행 파일>
import { createRequire } from "node:module";
const [, , baseUrl, pwPath, chromePath] = process.argv;
const require = createRequire(import.meta.url);
const { chromium } = require(pwPath);

const browser = await chromium.launch({
  executablePath: chromePath,
  headless: true,
  args: ["--no-sandbox", "--disable-features=WebRtcHideLocalIpsWithMdns", "--allow-loopback-in-peer-connection", "--use-gl=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
});
const fail = async (message) => { console.error("E2E_FAIL: " + message); await browser.close(); process.exit(1); };
const host = await (await browser.newContext()).newPage();
const guest = await (await browser.newContext()).newPage();
for (const [name, page] of [["host", host], ["guest", guest]]) {
  page.on("console", (m) => { if (process.env.E2E_VERBOSE) console.log(`[${name}] ${m.text()}`); });
  page.on("pageerror", (e) => console.log(`[${name}] pageerror ${e}`));
}
await host.goto(`${baseUrl}/index.html?role=host`);
await guest.goto(`${baseUrl}/index.html?role=guest`);
await host.waitForFunction(() => window.__ready === true, null, { timeout: 90000 }).catch(() => fail("방장 씬이 준비되지 않음"));
await guest.waitForFunction(() => window.__ready === true, null, { timeout: 90000 }).catch(() => fail("참가자 씬이 준비되지 않음"));
await host.evaluate(() => window.__makeInvite(2));
await host.waitForFunction(() => typeof window.__invite === "string", null, { timeout: 20000 }).catch(async () => fail("초대 코드가 만들어지지 않음 " + (await host.evaluate(() => window.__error))));
const invite = await host.evaluate(() => window.__invite);
console.log("invite length", invite.length);
await guest.evaluate((code) => window.__join(code), invite);
await guest.waitForFunction(() => typeof window.__answer === "string", null, { timeout: 20000 }).catch(async () => fail("응답 코드가 만들어지지 않음 " + (await guest.evaluate(() => window.__error))));
const answer = await guest.evaluate(() => window.__answer);
console.log("answer length", answer.length);
await host.evaluate((code) => window.__submitAnswer(2, code), answer);
await guest.waitForFunction(() => window.__joined === true, null, { timeout: 30000 }).catch(async () => fail("참가자가 방장과 연결되지 않음 " + (await guest.evaluate(() => window.__error))));
await host.waitForFunction(() => { try { const r = JSON.parse(window.__roster); return r[1][0] === 2; } catch (e) { return false; } }, null, { timeout: 15000 }).catch(async () => fail("방장 명단에 참가자가 없음 " + (await host.evaluate(() => window.__roster))));
const hostRoster = JSON.parse(await host.evaluate(() => window.__roster));
console.log("host roster", JSON.stringify(hostRoster));
if (hostRoster[1][1] !== "친구") await fail("참가자 닉네임이 방장에게 전달되지 않음");
await guest.waitForFunction(() => { try { const r = JSON.parse(window.__roster); return r[0][1] === "방장" && r[1][1] === "친구"; } catch (e) { return false; } }, null, { timeout: 15000 }).catch(async () => fail("참가자가 명단을 받지 못함 " + (await guest.evaluate(() => window.__roster))));
console.log("guest roster", await guest.evaluate(() => window.__roster), "mySeat", await guest.evaluate(() => window.__mySeat));
// 참가자 연결 끊기 -> 방장 명단에서 자리가 비어야 한다
await guest.close();
await host.waitForFunction(() => { try { const r = JSON.parse(window.__roster); return r[1][0] === 0; } catch (e) { return false; } }, null, { timeout: 30000 }).catch(async () => fail("참가자가 나가도 방장 명단이 그대로 " + (await host.evaluate(() => window.__roster))));
console.log("E2E_OK");
await browser.close();
