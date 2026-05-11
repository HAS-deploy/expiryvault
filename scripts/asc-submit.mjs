#!/usr/bin/env node
// Create v1.0.4, set whatsNew, attach build, submit reviewSubmission, verify state.
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const KEY_ID = "48ZWN983JL";
const ISSUER_ID = "730b7d86-5366-48ee-b04f-41a5dc0783cb";
const KEY_PATH = path.join(os.homedir(), ".appstoreconnect/private_keys/AuthKey_48ZWN983JL.p8");
const APP_ID = "6762533353";
const VERSION_STRING = "1.0.4";
const BUILD_ID = process.argv[2];
const WHATS_NEW = "Bug fixes and reliability improvements.";

if (!BUILD_ID) { console.error("usage: asc-submit.mjs <buildId>"); process.exit(1); }

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
function die(m) { console.error(`[asc-submit] ${m}`); process.exit(1); }

(async () => {
  // 1. Find or create app version 1.0.4
  const versions = await asc("GET", `/v1/apps/${APP_ID}/appStoreVersions?limit=20`);
  let version = (versions.json.data || []).find(v => v.attributes.versionString === VERSION_STRING);
  if (!version) {
    console.log(`creating appStoreVersion ${VERSION_STRING}...`);
    const c = await asc("POST", "/v1/appStoreVersions", {
      data: {
        type: "appStoreVersions",
        attributes: { platform: "IOS", versionString: VERSION_STRING },
        relationships: {
          app: { data: { type: "apps", id: APP_ID } },
          build: { data: { type: "builds", id: BUILD_ID } },
        },
      },
    });
    if (c.status !== 201) die(`create version: ${c.status} ${JSON.stringify(c.json).slice(0,800)}`);
    version = c.json.data;
    console.log(`  created version id=${version.id} state=${version.attributes.appStoreState}`);
  } else {
    console.log(`version exists: id=${version.id} state=${version.attributes.appStoreState}`);
    if (!["PREPARE_FOR_SUBMISSION","DEVELOPER_REJECTED","REJECTED","METADATA_REJECTED"].includes(version.attributes.appStoreState)) {
      die(`version is ${version.attributes.appStoreState}, cannot edit`);
    }
    // Attach build to existing version
    const buildRel = await asc("PATCH", `/v1/appStoreVersions/${version.id}/relationships/build`, {
      data: { type: "builds", id: BUILD_ID },
    });
    if (buildRel.status >= 300) die(`attach build: ${buildRel.status} ${JSON.stringify(buildRel.json).slice(0,500)}`);
    console.log(`  build ${BUILD_ID} attached`);
  }

  // 2. Set whatsNew on default localization (en-US)
  const locs = await asc("GET", `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=50`);
  const enUs = (locs.json.data || []).find(l => l.attributes.locale === "en-US")
    || (locs.json.data || [])[0];
  if (!enUs) die("no localization found");
  console.log(`whatsNew localization: ${enUs.id} (${enUs.attributes.locale})`);
  const wn = await asc("PATCH", `/v1/appStoreVersionLocalizations/${enUs.id}`, {
    data: { type: "appStoreVersionLocalizations", id: enUs.id,
            attributes: { whatsNew: WHATS_NEW } },
  });
  if (wn.status >= 300) die(`set whatsNew: ${wn.status} ${JSON.stringify(wn.json).slice(0,500)}`);
  console.log(`  whatsNew set: "${WHATS_NEW}"`);

  // 3. Verify build is attached
  const buildCheck = await asc("GET", `/v1/appStoreVersions/${version.id}/relationships/build`);
  if (buildCheck.json?.data?.id !== BUILD_ID) die(`build not attached: got ${buildCheck.json?.data?.id}`);
  console.log(`build attached: ${BUILD_ID}`);

  // 4. Find or create reviewSubmission
  const existing = await asc("GET",
    `/v1/reviewSubmissions?filter[app]=${APP_ID}&filter[state]=READY_FOR_REVIEW,WAITING_FOR_REVIEW,IN_REVIEW`);
  let rsId;
  const rs = (existing.json.data || [])[0];
  if (rs) {
    if (["WAITING_FOR_REVIEW", "IN_REVIEW"].includes(rs.attributes.state)) {
      console.log(`reviewSubmission already submitted: ${rs.id} state=${rs.attributes.state}`);
      console.log(JSON.stringify({reviewSubmissionId: rs.id, state: rs.attributes.state, versionId: version.id}));
      process.exit(0);
    }
    rsId = rs.id;
    console.log(`reviewSubmission: reuse id=${rsId} state=${rs.attributes.state}`);
  } else {
    const c = await asc("POST", "/v1/reviewSubmissions", {
      data: { type: "reviewSubmissions", attributes: { platform: "IOS" },
              relationships: { app: { data: { type: "apps", id: APP_ID } } } },
    });
    if (c.status !== 201) die(`create reviewSubmission: ${c.status} ${JSON.stringify(c.json).slice(0,500)}`);
    rsId = c.json.data.id;
    console.log(`reviewSubmission: created id=${rsId}`);
  }

  // 5. Clear old items + add this version
  const items = await asc("GET", `/v1/reviewSubmissions/${rsId}/items?limit=20`);
  for (const it of items.json.data || []) {
    await asc("DELETE", `/v1/reviewSubmissionItems/${it.id}`);
    console.log(`  cleared old item ${it.id}`);
  }
  const addV = await asc("POST", "/v1/reviewSubmissionItems", {
    data: { type: "reviewSubmissionItems", relationships: {
      reviewSubmission: { data: { type: "reviewSubmissions", id: rsId } },
      appStoreVersion: { data: { type: "appStoreVersions", id: version.id } },
    } },
  });
  if (addV.status !== 201) die(`add version: ${addV.status} ${JSON.stringify(addV.json).slice(0,800)}`);
  console.log(`  added: appStoreVersion ${version.id}`);

  // 6. Submit
  const submit = await asc("PATCH", `/v1/reviewSubmissions/${rsId}`, {
    data: { type: "reviewSubmissions", id: rsId, attributes: { submitted: true } },
  });
  if (submit.status !== 200) die(`PATCH submit: ${submit.status} ${JSON.stringify(submit.json).slice(0,800)}`);
  console.log(`submitted reviewSubmission ${rsId}`);

  // 7. Verify final state
  const final = await asc("GET", `/v1/reviewSubmissions/${rsId}`);
  const fState = final.json?.data?.attributes?.state;
  console.log(`final state: ${fState}`);
  console.log(JSON.stringify({reviewSubmissionId: rsId, state: fState, versionId: version.id, buildId: BUILD_ID}));
})().catch(e => { console.error(e.stack || e); process.exit(1); });
