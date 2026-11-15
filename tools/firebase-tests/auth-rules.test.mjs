import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { initializeApp, deleteApp } from 'firebase/app';
import { getAuth, connectAuthEmulator, createUserWithEmailAndPassword, signInWithEmailAndPassword, signOut, sendPasswordResetEmail } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator, doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs, serverTimestamp, Timestamp, runTransaction, writeBatch, arrayUnion } from 'firebase/firestore';
let env;
const projectId = 'demo-smart-couple';
const profile = (overrides = {}) => ({name:'Alice',email:'alice@example.com',photoUrl:null,coupleId:null,createdAt:serverTimestamp(),updatedAt:serverTimestamp(),...overrides});
const own = () => env.authenticatedContext('alice',{email:'alice@example.com'}).firestore();
before(async () => { env = await initializeTestEnvironment({projectId,firestore:{rules:readFileSync(new URL('../../firestore.rules',import.meta.url),'utf8').replace(/^\uFEFF/,'')}}); });
beforeEach(async () => env.clearFirestore());
after(async () => env?.cleanup());
test('owner creates and reads profile; strangers and list queries are denied', async () => {
 const db=own(); await assertSucceeds(setDoc(doc(db,'users/alice'),profile()));
 await assertSucceeds(getDoc(doc(db,'users/alice')));
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'users/alice')));
 const bob=env.authenticatedContext('bob',{email:'bob@example.com'}).firestore();
 await assertFails(getDoc(doc(bob,'users/alice')));
 await assertFails(updateDoc(doc(bob,'users/alice'),{name:'Bob',updatedAt:serverTimestamp()}));
 await assertFails(getDocs(collection(db,'users')));
});
test('profile field types, server timestamps, email ownership and allowed keys are enforced', async () => {
 for (const data of [profile({name:9}),profile({email:'someone@example.com'}),profile({password:'secret'}),profile({coupleId:'forged'}),profile({photoUrl:123}),profile({createdAt:Timestamp.fromMillis(1)}),profile({updatedAt:Timestamp.fromMillis(1)})]) { await assertFails(setDoc(doc(own(),'users/alice'),data)); }
});
test('only name, photoUrl and updatedAt can change; membership and identity stay protected', async () => {
 const db=own(), ref=doc(db,'users/alice'); await setDoc(ref,profile());
 await assertSucceeds(updateDoc(ref,{name:'Alice Updated',photoUrl:'https://example.com/photo.jpg',updatedAt:serverTimestamp()}));
 for(const change of [{coupleId:'forged'},{email:'other@example.com'},{createdAt:serverTimestamp()},{extra:true},{name:4}]) { await assertFails(updateDoc(ref,{...change,updatedAt:serverTimestamp()})); }
 await assertFails(deleteDoc(ref));
 // Trusted future membership updates must not be cleared by client profile edits.
 await env.withSecurityRulesDisabled(async ctx=>updateDoc(doc(ctx.firestore(),'users/alice'),{coupleId:'couple-a'}));
 await assertSucceeds(updateDoc(ref,{name:'Alice',updatedAt:serverTimestamp()}));
 await assertFails(updateDoc(ref,{coupleId:null,updatedAt:serverTimestamp()}));
});
test('Auth registration, idempotent Firestore profile, logout, login, duplicate email, reset', async () => {
 const app=initializeApp({apiKey:'fake-api-key',appId:'test-app',projectId},'auth-rules-smoke');
 const auth=getAuth(app); connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});
 const db=getFirestore(app); connectFirestoreEmulator(db,'127.0.0.1',8080);
 const email=`smoke-${Date.now()}@example.com`, password='Secure123!';
 try {
  const {user}=await createUserWithEmailAndPassword(auth,email,password);
  const ref=doc(db,'users',user.uid);
  const create=()=>runTransaction(db,async tx=>{const snap=await tx.get(ref);if(!snap.exists()){tx.set(ref,profile({email}));}});
  await create(); const first=(await getDoc(ref)).data(); assert.equal(first.coupleId,null); assert.ok(first.createdAt instanceof Timestamp);
  await create(); assert.equal((await getDoc(ref)).data().createdAt.toMillis(),first.createdAt.toMillis());
  await signOut(auth); assert.equal(auth.currentUser,null);
  await assert.rejects(signInWithEmailAndPassword(auth,email,'Wrong123!'));
  await signInWithEmailAndPassword(auth,email,password); assert.equal(auth.currentUser.uid,user.uid);
  assert.equal((await getDoc(ref)).data().name,'Alice');
  await assert.rejects(createUserWithEmailAndPassword(auth,email,password),e=>e.code==='auth/email-already-in-use');
  await sendPasswordResetEmail(auth,email);
 } finally { await signOut(auth); await deleteApp(app); }
});

// Couple creation must be one atomic, self-owned initial membership operation.
test('creating a space atomically links only its creator and is readable only by members', async () => {
 const db=own(); await setDoc(doc(db,'users/alice'),profile());
 await runTransaction(db,async tx=>{
  const user=await tx.get(doc(db,'users/alice')); assert.equal(user.data().coupleId,null);
  tx.set(doc(db,'couples/space-a'),{name:'Our world',createdBy:'alice',memberIds:['alice'],createdAt:serverTimestamp(),updatedAt:serverTimestamp()});
  tx.update(doc(db,'users/alice'),{coupleId:'space-a',updatedAt:serverTimestamp()});
 });
 await assertSucceeds(getDoc(doc(db,'couples/space-a')));
 assert.equal((await getDoc(doc(db,'users/alice'))).data().coupleId,'space-a');
 await assertFails(getDoc(doc(env.authenticatedContext('bob',{email:'bob@example.com'}).firestore(),'couples/space-a')));
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'couples/space-a')));
 await assertFails(getDocs(collection(db,'couples')));
 await assertFails(updateDoc(doc(db,'couples/space-a'),{memberIds:['alice','bob']}));
});
test('reject orphan spaces, profile-only linking, forged owners, extra members and switching membership', async () => {
 const db=own(); await setDoc(doc(db,'users/alice'),profile());
 const space=(extra={})=>({name:'Our world',createdBy:'alice',memberIds:['alice'],createdAt:serverTimestamp(),updatedAt:serverTimestamp(),...extra});
 await assertFails(setDoc(doc(db,'couples/orphan'),space()));
 await assertFails(updateDoc(doc(db,'users/alice'),{coupleId:'missing',updatedAt:serverTimestamp()}));
 for(const invalid of [{createdBy:'bob'},{memberIds:['alice','bob']},{name:''},{name:4},{extra:true}]) {
  await assertFails(runTransaction(db,async tx=>{
   await tx.get(doc(db,'users/alice'));
   tx.set(doc(db,'couples/invalid'),space(invalid));
   tx.update(doc(db,'users/alice'),{coupleId:'invalid',updatedAt:serverTimestamp()});
  }));
 }
 assert.equal((await getDoc(doc(db,'users/alice'))).data().coupleId,null);
 await env.withSecurityRulesDisabled(async ctx=>{
  await setDoc(doc(ctx.firestore(),'couples/existing'),space());
 });
 await assertFails(updateDoc(doc(db,'users/alice'),{coupleId:'existing',updatedAt:serverTimestamp()}));
 await runTransaction(db,async tx=>{
  await tx.get(doc(db,'users/alice'));tx.set(doc(db,'couples/first'),space());tx.update(doc(db,'users/alice'),{coupleId:'first',updatedAt:serverTimestamp()});
 });
 await assertFails(runTransaction(db,async tx=>{
  await tx.get(doc(db,'users/alice'));tx.set(doc(db,'couples/second'),space());tx.update(doc(db,'users/alice'),{coupleId:'second',updatedAt:serverTimestamp()});
 }));
 await assertFails(updateDoc(doc(db,'users/alice'),{coupleId:null,updatedAt:serverTimestamp()}));
});

async function invitationFixture(){
 const alice=own(),bob=env.authenticatedContext('bob',{email:'bob@example.com'}).firestore();
 await setDoc(doc(alice,'users/alice'),profile());
 await setDoc(doc(bob,'users/bob'),profile({name:'Bob',email:'bob@example.com'}));
 await runTransaction(alice,async tx=>{await tx.get(doc(alice,'users/alice'));tx.set(doc(alice,'couples/invite-space'),{name:'Our world',createdBy:'alice',memberIds:['alice'],createdAt:serverTimestamp(),updatedAt:serverTimestamp()});tx.update(doc(alice,'users/alice'),{coupleId:'invite-space',updatedAt:serverTimestamp()});});
 const make=(extra={})=>({coupleId:'invite-space',createdBy:'alice',spaceName:'Our world',status:'pending',createdAt:serverTimestamp(),expiresAt:Timestamp.fromMillis(Date.now()+3600000),acceptedBy:null,acceptedAt:null,...extra});
 return {alice,bob,make};
}
async function acceptInvite(db,uid,token,extra={}){
 const batch=writeBatch(db);
 batch.update(doc(db,'couples/invite-space'),{memberIds:arrayUnion(uid),lastAcceptedInviteId:token,updatedAt:serverTimestamp(),...extra});
 batch.update(doc(db,'users',uid),{coupleId:'invite-space',updatedAt:serverTimestamp()});
 batch.update(doc(db,'invitations',token),{status:'accepted',acceptedBy:uid,acceptedAt:serverTimestamp()});
 return batch.commit();
}
test('valid one-use invitation joins exactly two members, with private space access',async()=>{
 const {alice,bob,make}=await invitationFixture(),token='A'.repeat(43),second='B'.repeat(43);
 await assertSucceeds(setDoc(doc(alice,'invitations',token),make()));await setDoc(doc(alice,'invitations',second),make());
 await assertSucceeds(getDoc(doc(bob,'invitations',token)));
 await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'invitations',token)));
 await assertFails(getDocs(collection(bob,'invitations')));
 await assertSucceeds(acceptInvite(bob,'bob',token));
 assert.deepEqual((await getDoc(doc(alice,'couples/invite-space'))).data().memberIds,['alice','bob']);
 await assertSucceeds(getDoc(doc(bob,'couples/invite-space')));
 await assertFails(getDoc(doc(bob,'users/alice')));
 await assertFails(acceptInvite(bob,'bob',token));
 const charlie=env.authenticatedContext('charlie',{email:'charlie@example.com'}).firestore();await setDoc(doc(charlie,'users/charlie'),profile({email:'charlie@example.com'}));
 await assertFails(acceptInvite(charlie,'charlie',second));
 assert.equal((await getDoc(doc(charlie,'users/charlie'))).data().coupleId,null);
});
test('expired and revoked links cannot be accepted',async()=>{
 const {alice,bob,make}=await invitationFixture(),expired='C'.repeat(43),revoked='D'.repeat(43);
 await assertFails(setDoc(doc(alice,'invitations',expired),make({expiresAt:Timestamp.fromMillis(Date.now()-10000)})));
 await env.withSecurityRulesDisabled(async ctx=>setDoc(doc(ctx.firestore(),'invitations',expired),make({expiresAt:Timestamp.fromMillis(Date.now()-10000)})));
 await assertFails(acceptInvite(bob,'bob',expired));
 await setDoc(doc(alice,'invitations',revoked),make());await assertSucceeds(updateDoc(doc(alice,'invitations',revoked),{status:'revoked'}));
 await assertFails(acceptInvite(bob,'bob',revoked));
 assert.equal((await getDoc(doc(bob,'users/bob'))).data().coupleId,null);
});
test('reject forged invitations, partial accepts, own links, and space tampering',async()=>{
 const {alice,bob,make}=await invitationFixture(),token='E'.repeat(43);
 await assertFails(setDoc(doc(bob,'invitations',token),make({createdBy:'bob'})));
 await assertFails(setDoc(doc(alice,'invitations','guessable'),make()));
 await assertFails(setDoc(doc(alice,'invitations',token),make({expiresAt:Timestamp.fromMillis(Date.now()+48*3600000)})));
 await setDoc(doc(alice,'invitations',token),make());
 await assertFails(updateDoc(doc(bob,'invitations',token),{status:'accepted',acceptedBy:'bob',acceptedAt:serverTimestamp()}));
 await assertFails(updateDoc(doc(bob,'invitations',token),{status:'revoked'}));
 await assertFails(acceptInvite(alice,'alice',token));
 await assertFails(acceptInvite(bob,'bob',token,{name:'Tampered'}));
 await assertFails(acceptInvite(bob,'bob',token,{memberIds:['bob']}));
 await assertSucceeds(acceptInvite(bob,'bob',token));
});
test('already-linked users cannot accept a different couple invitation',async()=>{
 const {alice,bob,make}=await invitationFixture(),token='F'.repeat(43);
 await setDoc(doc(alice,'invitations',token),make());
 await runTransaction(bob,async tx=>{await tx.get(doc(bob,'users/bob'));tx.set(doc(bob,'couples/bob-space'),{name:'Other world',createdBy:'bob',memberIds:['bob'],createdAt:serverTimestamp(),updatedAt:serverTimestamp()});tx.update(doc(bob,'users/bob'),{coupleId:'bob-space',updatedAt:serverTimestamp()});});
 await assertFails(acceptInvite(bob,'bob',token));
 assert.equal((await getDoc(doc(bob,'users/bob'))).data().coupleId,'bob-space');
});
