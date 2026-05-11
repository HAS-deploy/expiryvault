#!/usr/bin/env node
// Fetch live description from the most-recent live appStoreVersion.
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const KEY_ID = "48ZWN983JL";
const ISSUER_ID = "730b7d86-5366-48ee-b04f-41a5dc0783cb";
const KEY_PATH = path.join(os.homedir(), ".appstoreconnect/private_keys/AuthKey_48ZWN983JL.p8");
const APP_ID = "6762533353";

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
  const versions = await asc("GET", `/v1/apps/${APP_ID}/appStoreVersions?limit=20`);
  const list = versions.json?.data || [];
  console.log("versions:");
  for (const v of list) console.log(`  id=${v.id} ver=${v.attributes.versionString} state=${v.attributes.appStoreState}`);
  // Use most-recent live version (READY_FOR_SALE or PENDING_APPLE_RELEASE)
  const live = list.find(v => ["READY_FOR_SALE","PENDING_APPLE_RELEASE","PROCESSING_FOR_APP_STORE"].includes(v.attributes.appStoreState))
            || list[0];
  if (!live) { console.error("no version found"); process.exit(1); }
  console.log(`\nusing version: ${live.id} (${live.attributes.versionString} / ${live.attributes.appStoreState})`);
  const locs = await asc("GET", `/v1/appStoreVersions/${live.id}/appStoreVersionLocalizations?limit=50`);
  const enUs = (locs.json.data || []).find(l => l.attributes.locale === "en-US") || (locs.json.data || [])[0];
  if (!enUs) { console.error("no localization"); process.exit(1); }
  console.log(`localization: ${enUs.id} (${enUs.attributes.locale})`);
  const desc = enUs.attributes.description || "";
  console.log("\n----- DESCRIPTION START -----");
  console.log(desc);
  console.log("----- DESCRIPTION END -----\n");
  console.log(`contains 'privacy-policy.html': ${desc.includes("privacy-policy.html")}`);
  console.log(`contains 'privacy.html': ${desc.includes("privacy.html")}`);
})().catch(e => { console.error(e.stack || e); process.exit(1); });
