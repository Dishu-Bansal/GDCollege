/**
 * Automatic `_meta` upkeep for student records.
 *
 * Firestore triggers (one per database: production `(default)` and
 * `test-db`) watch `students/{studentId}` and, on every create/update/
 * delete, maintain the single `_meta/students` document:
 *
 *   {
 *     count: <total students>,
 *     countByGroup: {gdCollege: n, mlsn: n, skillIndia: n},
 *     facets: {
 *       gdCollege:  {years: [...], courses: [...]},
 *       mlsn:       {years: [...], courses: [...]},
 *       skillIndia: {years: [...], courses: [...]}
 *     },
 *     updatedAt: <server timestamp>
 *   }
 *
 * That is: exact totals, per-group totals, and the whole-collection chip
 * options (years/courses per group). The app only READS this document
 * (totals, chips) and exact DB counts stay available via aggregate queries
 * as a fallback; every write to it happens here — the app-side
 * `_incrementCount`/`_decrementCount` upkeep was removed to avoid
 * double-counting.
 *
 * Loop safety: the group stamp writes back to the same document with
 * `set(..., {merge: true})`, but only when the stored value actually
 * differs — the re-triggered event sees no diff and stops.
 *
 * One-time backfill of pre-existing documents: run the `backfillStudentGroups`
 * callable once per database from the Firebase console
 * (Functions → backfillStudentGroups → Testing), then it can be deleted.
 */

const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {onDocumentWritten} = require("firebase-functions/v2/firestore");
const {onCall} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");

initializeApp();

// ── Grouping (mirrors studentGroupOfCourse in lib/constants.dart) ──────────
// Keep these two in sync: GD College = B.ED/M.ED/D.P.ED/D.ED,
// MLSN = ANM/GNM, everything else = Skill India.
const GD_COLLEGE_COURSES = new Set(["B.ED", "D.ED", "D.P.ED", "M.ED"]);
const MLSN_COURSES = new Set(["ANM", "GNM"]);

function groupOf(course) {
  const c = String(course == null ? "" : course).trim().toUpperCase();
  if (GD_COLLEGE_COURSES.has(c)) return "gdCollege";
  if (MLSN_COURSES.has(c)) return "mlsn";
  return "skillIndia";
}

function numYear(data) {
  const y = data.yearOfAdmission;
  return typeof y === "number" && y > 0 ? Math.trunc(y) : null;
}

function strCourse(data) {
  return String(data.nameOfCourse == null ? "" : data.nameOfCourse).trim();
}

function groupOfDoc(data) {
  const stored = data.group;
  if (typeof stored === "string" && stored.length > 0) return stored;
  return groupOf(data.nameOfCourse);
}

function metaDoc(db) {
  return db.collection("_meta").doc("students");
}

// ── Facet + counter upkeep ────────────────────────────────────────────────

async function addValues(ref, group, year, course) {
  // NOTE: set(..., {merge: true}) does NOT expand dotted key strings into
  // nested maps (only update() does) — so build real nested objects here,
  // otherwise Firestore stores literal "facets.mlsn.courses" field names.
  const groupUpdate = {};
  if (course.length > 0) {
    groupUpdate.courses = FieldValue.arrayUnion([course]);
  }
  if (year != null) {
    groupUpdate.years = FieldValue.arrayUnion([year]);
  }
  if (Object.keys(groupUpdate).length === 0) return;
  await ref.set(
    {facets: {[group]: groupUpdate}, updatedAt: FieldValue.serverTimestamp()},
    {merge: true},
  );
}

/**
 * Atomically moves the counters. Deltas are `FieldValue.increment`, so
 * concurrent writes never lose counts. `total` defaults to 0 (group moves
 * on update keep the total unchanged).
 */
async function bumpCounts(ref, groupDeltas, totalDelta) {
  // Same dotted-key caveat as above: build real nested objects.
  const groupUpdates = {};
  for (const [group, delta] of Object.entries(groupDeltas)) {
    if (delta !== 0) {
      groupUpdates[group] = FieldValue.increment(delta);
    }
  }
  const updates = {};
  if (Object.keys(groupUpdates).length > 0) {
    updates.countByGroup = groupUpdates;
  }
  if (totalDelta !== 0) {
    updates.count = FieldValue.increment(totalDelta);
  }
  if (Object.keys(updates).length === 0) return;
  updates.updatedAt = FieldValue.serverTimestamp();
  await ref.set(updates, {merge: true});
}

/**
 * Removes a year/course from the group's facet lists, but only when no
 * other document in that group still uses the value (single limit-1
 * checks), keeping chip options exact without full-collection scans.
 */
async function pruneValue(db, ref, group, year, course) {
  // Same dotted-key caveat: build real nested objects.
  const groupRemovals = {};
  if (year != null) {
    const stillUsed = await db
      .collection("students")
      .where("group", "==", group)
      .where("yearOfAdmission", "==", year)
      .limit(1)
      .get();
    if (stillUsed.empty) {
      groupRemovals.years = FieldValue.arrayRemove([year]);
    }
  }
  if (course.length > 0) {
    const stillUsed = await db
      .collection("students")
      .where("group", "==", group)
      .where("nameOfCourse", "==", course)
      .limit(1)
      .get();
    if (stillUsed.empty) {
      groupRemovals.courses = FieldValue.arrayRemove([course]);
    }
  }
  if (Object.keys(groupRemovals).length === 0) return;
  await ref.set(
    {
      facets: {[group]: groupRemovals},
      updatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
}

// ── Shared write handler ────────────────────────────────────────────────────

async function syncStudentDoc(db, beforeSnap, afterSnap) {
  const ref = metaDoc(db);

  // Delete: decrement counters and prune values the removed document was
  // the last user of.
  if (!afterSnap.exists) {
    const before = beforeSnap.data() || {};
    const group = groupOfDoc(before);
    await bumpCounts(ref, {[group]: -1}, -1);
    await pruneValue(
      db,
      ref,
      group,
      numYear(before),
      strCourse(before),
    );
    return;
  }

  const after = afterSnap.data() || {};
  const newGroup = groupOf(after.nameOfCourse);
  const newYear = numYear(after);
  const newCourse = strCourse(after);

  // Stamp the group when missing/stale. Guarded by the diff check, so the
  // re-triggered event performs no further document writes.
  if (after.group !== newGroup) {
    await afterSnap.ref.set({group: newGroup}, {merge: true});
  }

  if (!beforeSnap.exists) {
    // Create: bump counters, then advertise the facet values.
    await bumpCounts(ref, {[newGroup]: 1}, 1);
    await addValues(ref, newGroup, newYear, newCourse);
    return;
  }

  // Update: advertise the new facet values, move the group counter when the
  // group changed, and drop old values nothing else still uses.
  await addValues(ref, newGroup, newYear, newCourse);
  const before = beforeSnap.data() || {};
  const oldGroup = groupOfDoc(before);
  const oldYear = numYear(before);
  const oldCourse = strCourse(before);
  if (oldGroup !== newGroup) {
    await bumpCounts(ref, {[oldGroup]: -1, [newGroup]: 1}, 0);
  }
  if (oldGroup !== newGroup || oldYear !== newYear || oldCourse !== newCourse) {
    await pruneValue(db, ref, oldGroup, oldYear, oldCourse);
  }
}

// ── Triggers: one per database ──────────────────────────────────────────────

exports.syncStudentMeta = onDocumentWritten(
  "students/{studentId}",
  (event) => {
    const db = getFirestore(); // production `(default)` database
    return syncStudentDoc(db, event.data.before, event.data.after);
  },
);

exports.syncStudentMetaTestDb = onDocumentWritten(
  {document: "students/{studentId}", database: "test-db"},
  (event) => {
    return syncStudentDoc(
      getFirestore("test-db"),
      event.data.before,
      event.data.after,
    );
  },
);

// ── One-time backfills (callables, then deletable) ──────────────────────────
// Two fixed-target versions so invocation needs no request data (run with
// `{}`): `backfillStudentGroups` for production, `backfillStudentGroupsTestDb`
// for the test database — console Testing tab or:
//   gcloud functions call backfillStudentGroups --project=g-d-college \
//     --region=us-central1 --data '{}'
// Each stamps `group` on every student doc of its database and (re)builds
// the consolidated `_meta/students` document. Safe to re-run.

async function backfillDatabase(db, database) {
  const yearsByGroup = {};
  const coursesByGroup = {};
    const remember = (group, year, course) => {
      if (year != null) {
        (yearsByGroup[group] = yearsByGroup[group] || new Set()).add(year);
      }
      if (course.length > 0) {
        (coursesByGroup[group] = coursesByGroup[group] || new Set()).add(course);
      }
    };

    let scanned = 0;
    let updated = 0;
    const countByGroup = {gdCollege: 0, mlsn: 0, skillIndia: 0};
    let cursor = null;
    for (;;) {
      let q = db
        .collection("students")
        .orderBy("__name__")
        .limit(500);
      if (cursor != null) q = q.startAfter(cursor);
      const snap = await q.get();
      if (snap.empty) break;

      const batch = db.batch();
      let pending = 0;
      for (const d of snap.docs) {
        const data = d.data() || {};
        const course = strCourse(data);
        const group = groupOf(data.nameOfCourse);
        remember(group, numYear(data), course);
        countByGroup[group] += 1;
        if (data.group !== group) {
          batch.update(d.ref, {group});
          pending += 1;
          updated += 1;
        }
      }
      if (pending > 0) await batch.commit();

      scanned += snap.size;
      cursor = snap.docs[snap.docs.length - 1];
      if (snap.size < 500) break;
    }

    const facets = {};
    for (const name of ["gdCollege", "mlsn", "skillIndia"]) {
      const years = Array.from(yearsByGroup[name] || []).sort((a, b) => b - a);
      const courses = Array.from(coursesByGroup[name] || []).sort();
      facets[name] = {years, courses};
    }
    const count = countByGroup.gdCollege + countByGroup.mlsn + countByGroup.skillIndia;
    // Overwrite (no merge): the backfill computes the complete document, and
    // this also wipes any malformed dotted-literal fields from earlier writes.
    await metaDoc(db).set({
      count,
      countByGroup,
      facets,
      updatedAt: FieldValue.serverTimestamp(),
    });
    logger.info(`backfill(${database}): scanned=${scanned} updated=${updated} count=${count}`);
    return {database, scanned, updated, count, countByGroup};
}

exports.backfillStudentGroups = onCall(
  {timeoutSeconds: 540, memory: "512MiB"},
  async () => backfillDatabase(getFirestore(), "(default)"),
);

exports.backfillStudentGroupsTestDb = onCall(
  {timeoutSeconds: 540, memory: "512MiB"},
  async () => backfillDatabase(getFirestore("test-db"), "test-db"),
);
