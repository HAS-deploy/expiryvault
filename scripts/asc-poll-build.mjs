#!/usr/bin/env node
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const KEY_ID = "48ZWN983JL";
const ISSUER_ID = "730b7d86-5366-48ee-b04f-41a5dc0783cb";
const KEY_PATH = path.join(os.homedir(), ".appstoreconnect/private_keys/AuthKey_48ZWN983JL.p8");
const APP_ID = "6762533353";
const TARGET_VERSION = process.argv[2] || "6";
const MAX_MIN = 30;

function b64url(b) { return Buffer.from(b).toString("base64url"); }
function tok() {
  const n = Math.floor(Date.now()/1000);
  const u = b64url(JSON.stringify({alg:"ES256",kid:KEY_ID,typ:"JWT"})) + "." + b64url(JSON.stringify({iss:ISSUER_ID,iat:n,exp:n+1200,aud:"appstoreconnect-v1"}));
  return u + "." + b64url(crypto.sign("sha256", Buffer.from(u), {key: fs.readFileSync(KEY_PATH), dsaEncoding:"ieee-p1363"}));
}
async function asc(method, url, body) {
  const r = await fetch("https://api.appstoreconnect.apple.com" + url, {
    method, headers: { authorization: "Bearer " + tok(), "content-type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  const t = await r.text();
  return { status: r.status, json: t ? JSON.parse(t) : null };
}

(async () => {
  const start = Date.now();
  while (Date.now() - start < MAX_MIN * 60 * 1000) {
    const r = await asc("GET", `/v1/builds?filter[app]=${APP_ID}&sort=-uploadedDate&limit=5`);
    const list = r.json?.data || [];
    const matches = list.map(b => `v=${b.attributes.version} state=${b.attributes.processingState}`).join(" | ");
    console.log(`[${new Date().toISOString()}] builds: ${matches || "(none)"}`);
    const target = list.find(b => b.attributes.version === TARGET_VERSION);
    if (target && target.attributes.processingState === "VALID") {
      console.log(`READY id=${target.id} version=${target.attributes.version} state=VALID`);
      console.log(JSON.stringify({buildId: target.id, version: target.attributes.version}));
      process.exit(0);
    }
    if (target && target.attributes.processingState === "INVALID") {
      console.error(`INVALID build id=${target.id}`);
      process.exit(2);
    }
    await new Promise(r => setTimeout(r, 60000));
  }
  console.error("timeout waiting for build");
  process.exit(3);
})().catch(e => { console.error(e.stack || e); process.exit(1); });
