import {test, after} from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
import {initializeApp, deleteApp} from 'firebase/app';
import {getAuth, connectAuthEmulator, createUserWithEmailAndPassword} from 'firebase/auth';
import {getFirestore, connectFirestoreEmulator, doc, setDoc, getDoc, onSnapshot, serverTimestamp} from 'firebase/firestore';
const require = createRequire(new URL('../../functions/package.json', import.meta.url));
const {initializeApp: adminApp} = require('firebase-admin/app');
const {getFirestore: adminFirestore, Timestamp} = require('firebase-admin/firestore');
const projectId = 'demo-smart-couple';
if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) throw Error('Run only through emulators:exec');
const admin = adminFirestore(adminApp({projectId}));
const apps = [];
after(async () => { await Promise.all(apps.map(deleteApp)); await admin.terminate(); });
async function account(name) {
  const suffix = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
  const app = initializeApp({projectId, apiKey: 'fake-api-key', appId: 'test'}, suffix);
  apps.push(app);
  const auth = getAuth(app); connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings:true});
  const db = getFirestore(app); connectFirestoreEmulator(db, '127.0.0.1', 8080);
  const {user} = await createUserWithEmailAndPassword(auth, `${suffix}@example.com`, 'Secure123!');
  await setDoc(doc(db, 'users', user.uid), {name, email:user.email, photoUrl:null, coupleId:null, createdAt:serverTimestamp(), updatedAt:serverTimestamp()});
  return {user, db};
}
async function call(who, name, data = {}) {
  const headers = {'Content-Type':'application/json'};
  if (who) headers.Authorization = `Bearer ${await who.user.getIdToken(true)}`;
  const response = await fetch(`http://127.0.0.1:5001/${projectId}/us-central1/${name}`, {method:'POST', headers, body:JSON.stringify({data})});
  const body = await response.json();
  if (body.error) throw Object.assign(new Error(body.error.message), {reason:body.error.details?.reason, status:body.error.status});
  assert.equal(response.status, 200);
  return body.result;
}
const rejects = (promise, reason) => assert.rejects(promise, e => e.reason === reason);
const ref = invite => admin.doc(`invitations/${createHash('sha256').update(invite.token).digest('hex')}`);
async function setup() {
  const a = await account('Partner A');
  const {coupleId} = await call(a, 'createCoupleSpace', {name:'Our world'});
  const invite = await call(a, 'createPartnerInvitation', {coupleId});
  return {a, coupleId, invite};
}

test('trusted backend joins independent accounts, streams membership, protects tokens and rejects replay', async () => {
  const {a, coupleId, invite} = await setup();
  const stored = (await ref(invite).get()).data();
  assert.equal(stored.tokenHash, ref(invite).id);
  assert.ok(stored.createdAt instanceof Timestamp);
  assert.equal(JSON.stringify(stored).includes(invite.token), false);
  assert.equal((await admin.doc(`invitations/${invite.token}`).get()).exists, false);
  // Link exists before B registers; registration creates no second workspace.
  const b = await account('Partner B');
  assert.equal((await getDoc(doc(b.db, 'users', b.user.uid))).data().coupleId, null);
  const preview = await call(b, 'getPartnerInvitation', {token:invite.token});
  assert.equal(preview.inviterName, 'Partner A');
  assert.equal(preview.tokenHash, undefined);
  let unsubscribe;
  const updated = new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(Error('Realtime update timed out')), 15000);
    unsubscribe = onSnapshot(doc(a.db, 'couples', coupleId), snap => {
      if (snap.data()?.memberIds.length === 2) {clearTimeout(timer); resolve(snap.data());}
    }, reject);
  });
  const result = await call(b, 'acceptPartnerInvitation', {token:invite.token, uid:a.user.uid});
  assert.equal(result.coupleId, coupleId); // Forged UID was ignored.
  const data = await updated; unsubscribe();
  assert.deepEqual(data.memberIds, [a.user.uid, b.user.uid]);
  assert.equal(data.memberNames[b.user.uid], 'Partner B');
  for (const who of [a,b]) {
    assert.equal((await getDoc(doc(who.db, 'users', who.user.uid))).data().coupleId, coupleId);
    assert.equal((await getDoc(doc(who.db, 'couples', coupleId))).exists(), true);
  }
  const accepted = (await ref(invite).get()).data();
  assert.equal(accepted.status, 'accepted');
  assert.equal(accepted.acceptedBy, b.user.uid);
  assert.ok(accepted.acceptedAt instanceof Timestamp);
  await rejects(call(b, 'acceptPartnerInvitation', {token:invite.token}), 'already-accepted');
});

test('expired, revoked, own, invalid and unauthenticated invitations fail without membership writes', async () => {
  const {a, invite, coupleId} = await setup(), b = await account('B');
  await assert.rejects(call(null, 'acceptPartnerInvitation', {token:invite.token}), e => e.status === 'UNAUTHENTICATED');
  await rejects(call(b,'acceptPartnerInvitation',{token:'invalid'}),'invalid-link');
  await rejects(call(a,'acceptPartnerInvitation',{token:invite.token}),'own-invite');
  await ref(invite).update({expiresAt:Timestamp.fromMillis(Date.now()-1000)});
  await rejects(call(b,'acceptPartnerInvitation',{token:invite.token}),'expired');
  const revoked = await call(a,'createPartnerInvitation',{coupleId});
  await rejects(call(b,'revokePartnerInvitation',{token:revoked.token}),'permission-denied');
  await call(a,'revokePartnerInvitation',{token:revoked.token});
  await rejects(call(b,'acceptPartnerInvitation',{token:revoked.token}),'revoked');
  assert.equal((await admin.doc(`users/${b.user.uid}`).get()).data().coupleId,null);
});

test('concurrent acceptance admits only one partner and a full couple rejects third users', async () => {
  const {a, invite, coupleId} = await setup();
  const second = await call(a,'createPartnerInvitation',{coupleId});
  const b = await account('B'), c = await account('C');
  const results = await Promise.allSettled([
    call(b,'acceptPartnerInvitation',{token:invite.token}),
    call(c,'acceptPartnerInvitation',{token:second.token}),
  ]);
  assert.equal(results.filter(r => r.status === 'fulfilled').length,1);
  assert.equal(results.find(r => r.status === 'rejected').reason.reason,'full');
  const d = (await admin.doc(`couples/${coupleId}`).get()).data();
  assert.equal(d.memberIds.length,2);
  await rejects(call(a,'createPartnerInvitation',{coupleId}),'full');
  const loser = results[0].status === 'rejected' ? b : c;
  assert.equal((await admin.doc(`users/${loser.user.uid}`).get()).data().coupleId,null);
});

test('one user cannot join two spaces under concurrent requests', async () => {
  const first = await setup(), second = await setup(), b = await account('B');
  const results = await Promise.allSettled([first,second].map(s => call(b,'acceptPartnerInvitation',{token:s.invite.token})));
  assert.equal(results.filter(r => r.status === 'fulfilled').length,1);
  assert.equal(results.find(r => r.status === 'rejected').reason.reason,'already-coupled');
});

test('email-restricted links require matching verified Firebase email', async () => {
  const {a,coupleId} = await setup(), b = await account('B'), c = await account('C');
  const invite = await call(a,'createPartnerInvitation',{coupleId,invitedEmail:b.user.email.toUpperCase()});
  await rejects(call(c,'acceptPartnerInvitation',{token:invite.token}),'email-mismatch');
  await rejects(call(b,'acceptPartnerInvitation',{token:invite.token}),'email-mismatch');
  const {getAuth: adminAuth} = require('firebase-admin/auth');
  await adminAuth().updateUser(b.user.uid,{emailVerified:true});
  assert.equal((await call(b,'acceptPartnerInvitation',{token:invite.token})).coupleId,coupleId);
});

test('concurrent workspace creation reuses one space and an outsider cannot invite', async () => {
  const a = await account('A'), outsider = await account('Outsider');
  const results = await Promise.all([1,2].map(() => call(a,'createCoupleSpace',{name:'One space'})));
  assert.equal(results[0].coupleId,results[1].coupleId);
  await rejects(call(outsider,'createPartnerInvitation',{coupleId:results[0].coupleId}),'permission-denied');
});
