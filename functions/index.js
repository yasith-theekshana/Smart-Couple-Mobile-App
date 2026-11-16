'use strict';

const {initializeApp} = require('firebase-admin/app');
const {getFirestore, Timestamp, FieldValue} = require('firebase-admin/firestore');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {randomBytes, createHash} = require('node:crypto');
initializeApp();
const db = getFirestore();
const options = {region: 'us-central1', maxInstances: 5};
const fail = code => { throw new HttpsError('failed-precondition', code, {reason: code}); };
const identity = request => {
  if (!request.auth) throw new HttpsError('unauthenticated', 'Sign in first.');
  return request.auth.uid;
};
const tokenHash = token => {
  if (typeof token !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(token)) fail('invalid-link');
  return createHash('sha256').update(token).digest('hex');
};
const invitationRef = token => db.collection('invitations').doc(tokenHash(token));
const pending = data => {
  if (!data) fail('unavailable-invite');
  if (data.status === 'accepted') fail('already-accepted');
  if (data.status === 'revoked') fail('revoked');
  if (data.status !== 'pending') fail('unavailable-invite');
  if (!(data.expiresAt instanceof Timestamp) || data.expiresAt.toMillis() <= Date.now()) fail('expired');
};
function restricted(data, request) {
  if (data.invitedEmail && (request.auth.token.email?.toLowerCase() !== data.invitedEmail || request.auth.token.email_verified !== true)) {
    fail('email-mismatch');
  }
}
const publicInvitation = d => ({
  coupleId: d.coupleId, createdBy: d.createdBy, spaceName: d.spaceName,
  inviterName: d.inviterName, status: d.status, expiresAt: d.expiresAt.toMillis(),
  acceptedBy: d.acceptedBy ?? null,
});

exports.createCoupleSpace = onCall(options, async request => {
  const uid = identity(request);
  const name = request.data?.name;
  if (typeof name !== 'string' || !name.trim() || name.trim().length > 80) fail('invalid-couple-name');
  const profile = db.doc(`users/${uid}`), space = db.collection('couples').doc();
  return db.runTransaction(async tx => {
    const user = await tx.get(profile);
    if (!user.exists) fail('missing-profile');
    if (user.data().coupleId) return {coupleId: user.data().coupleId};
    tx.create(space, {name: name.trim(), createdBy: uid, memberIds: [uid],
      memberNames: {[uid]: user.data().name}, currency: 'LKR',
      createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
    tx.update(profile, {coupleId: space.id, updatedAt: FieldValue.serverTimestamp()});
    return {coupleId: space.id};
  });
});

exports.createPartnerInvitation = onCall(options, async request => {
  const uid = identity(request), coupleId = request.data?.coupleId;
  if (typeof coupleId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(coupleId)) fail('permission-denied');
  let invitedEmail = request.data?.invitedEmail ?? null;
  if (invitedEmail !== null) {
    if (typeof invitedEmail !== 'string' || invitedEmail.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(invitedEmail.trim())) fail('invalid-email');
    invitedEmail = invitedEmail.trim().toLowerCase();
  }
  const token = randomBytes(32).toString('base64url'), ref = invitationRef(token);
  return db.runTransaction(async tx => {
    const [user, space] = await Promise.all([tx.get(db.doc(`users/${uid}`)), tx.get(db.doc(`couples/${coupleId}`))]);
    const d = space.data();
    if (!user.exists || user.data().coupleId !== coupleId || !d || d.createdBy !== uid || !d.memberIds.includes(uid)) fail('permission-denied');
    if (d.memberIds.length !== 1) fail('full');
    const data = {coupleId, createdBy: uid, inviterName: user.data().name,
      spaceName: d.name, invitedEmail, tokenHash: ref.id, status: 'pending',
      expiresAt: Timestamp.fromMillis(Date.now() + 24 * 60 * 60 * 1000),
      createdAt: FieldValue.serverTimestamp(), acceptedBy: null, acceptedAt: null};
    tx.create(ref, data);
    return {token, ...publicInvitation(data)};
  });
});

exports.getPartnerInvitation = onCall(options, async request => {
  const uid = identity(request), doc = await invitationRef(request.data?.token).get();
  if (!doc.exists) fail('unavailable-invite');
  const data = doc.data();
  // Only minimal, token-authorized preview data leaves the trusted backend.
  if (data.createdBy !== uid) restricted(data, request);
  return publicInvitation(data);
});

exports.revokePartnerInvitation = onCall(options, async request => {
  const uid = identity(request), ref = invitationRef(request.data?.token);
  await db.runTransaction(async tx => {
    const doc = await tx.get(ref);
    if (!doc.exists || doc.data().createdBy !== uid) fail('permission-denied');
    if (doc.data().status === 'revoked') return;
    pending(doc.data());
    tx.update(ref, {status: 'revoked'});
  });
  return {revoked: true};
});

exports.acceptPartnerInvitation = onCall(options, async request => {
  const uid = identity(request), ref = invitationRef(request.data?.token), profile = db.doc(`users/${uid}`);
  return db.runTransaction(async tx => {
    const [invite, user] = await Promise.all([tx.get(ref), tx.get(profile)]);
    const data = invite.data();
    pending(data);
    restricted(data, request);
    if (!user.exists) fail('missing-profile');
    if (data.createdBy === uid) fail('own-invite');
    if (user.data().coupleId !== null) fail('already-coupled');
    const spaceRef = db.doc(`couples/${data.coupleId}`), space = await tx.get(spaceRef);
    const d = space.data();
    if (!d || d.createdBy !== data.createdBy || !Array.isArray(d.memberIds) || !d.memberIds.includes(data.createdBy)) fail('unavailable-invite');
    if (d.memberIds.length >= 2) fail('full');
    if (d.memberIds.length !== 1 || d.memberIds.includes(uid)) fail('already-coupled');
    // Every read precedes every write. A conflict retries all validations.
    tx.update(spaceRef, {memberIds: [...d.memberIds, uid],
      memberNames: {...d.memberNames, [data.createdBy]: d.memberNames?.[data.createdBy] ?? data.inviterName, [uid]: user.data().name},
      updatedAt: FieldValue.serverTimestamp()});
    tx.update(profile, {coupleId: space.id, updatedAt: FieldValue.serverTimestamp()});
    tx.update(ref, {status: 'accepted', acceptedBy: uid, acceptedAt: FieldValue.serverTimestamp()});
    return {coupleId: space.id};
  });
});
