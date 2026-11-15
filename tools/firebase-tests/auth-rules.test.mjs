import { readFileSync } from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { initializeApp, deleteApp } from 'firebase/app';
import { getAuth, connectAuthEmulator, createUserWithEmailAndPassword, signInWithEmailAndPassword, signOut, sendPasswordResetEmail } from 'firebase/auth';
import { getFirestore, connectFirestoreEmulator, doc, getDoc, setDoc, updateDoc, deleteDoc, collection, getDocs, serverTimestamp, Timestamp, runTransaction } from 'firebase/firestore';
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
