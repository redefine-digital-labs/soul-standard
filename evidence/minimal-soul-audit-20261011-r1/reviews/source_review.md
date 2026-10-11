# Independent source review — minimal Soul standard

Date: 2026-10-11. Reviewer: bounded independent source-review agent; not the implementation executor. This is internal source analysis, not an external audit, deployed-authority assessment, or release approval.

## Exact scope and verification boundary

- Frozen input: `frozen-package/sources/soul.move`, 280 lines, 11,430 bytes. Read-only SHA-256 recomputation matched `0574d86b7d40dd42e22774b3bd68d9f5e7705fda2cf805cfe58a31d3e777c2c7`.
- Also inspected frozen `Move.toml`, `Move.lock`, `kernel_tests.move`, `publisher_tests.move`; repository AGENTS, MODULE, COMPATIBILITY, RUNBOOK and module.json; the current calibration's first 45 lines; project handbook v1.0 sections 1–4, 7, 8.3–8.4, 9 and 12.
- Dependency semantic checks used the local **pinned** primary framework source at Sui revision `2a0becb2fcc6989e492981104af67f62f2c9511a`: `std::type_name`, `sui::transfer`, and `sui::dynamic_object_field`. No dependency files were changed.
- No Move CLI, VM, compiler, on-chain call, publishing, signing, or external messaging was performed by this reviewer. No finding below is labelled reproduced by this reviewer. Existing test source was read; its execution status is not inferred.
- Only this report was written. Frozen/production sources, dependencies, CURRENT and owners were not changed. Parent executor owns the original record's stage/evidence attachment.

Calibration: the core is generic identity/origin plus optional extension consistency. Maker issuance rules, external capability validity, fees, markets, governance and business lifecycle rules are not required to live inside it. Default Soul is an address-private asset; a shared or custodied container requires separately specified authority and exit semantics.

## Assessment

No unconditional theft, object substitution, unfinished edit persistence, native nesting cycle, or namespace collision affecting a correctly controlled address-owned Soul was established in this source review. Two concrete source behaviors need explicit treatment: direct sharing removes the ownership boundary relied on by mutators; public core metadata can be used as a generic witness to permanently wrap a Soul outside the canonical native nesting namespace. The former has high potential impact **if shared Souls are admitted**. The latter is a confirmed alternate construction whose defect status depends on whether the product promises exit for all whole-Soul composition or only the canonical namespace. Neither should be reported as theft from a normal address-owned Soul.

## SR-01 — A directly shared Soul exposes removable children to any transaction sender

**Evidence class:** confirmed source fact and pinned-framework inference; not reproduced here. **Impact:** high if a producer or adapter directly shares a Soul containing valuable removable children. **Default-private status:** conditional hazard, not an owned-object authorization bypass. **Confidence:** high.

**Exact source:** Soul is `key + store` at line 31; `new` returns a value at lines 111–129; generic uninstall is lines 181–187; native unnest is lines 269–270. All modifying operations derive authority from obtaining `&mut Soul`; there is no holder capability or sender check in these paths. The pinned `sui::transfer` source lines 124–130 permits `public_share_object<T: key + store>` for an object created in the current transaction. Its lines 113–128 describe irreversible, generally accessible sharing and the new-object restriction.

**Trigger and realistic actor:** an issuance/adapter transaction creates a parent Soul, installs removable content or nests a child Soul, then calls `public_share_object(parent)`. A later unrelated address obtains the shared root as a mutable input, reads the current revision and descriptor, calls `uninstall<W,T>` or `unnest`, then `public_transfer`s the returned child to itself. These withdrawal functions require no witness value. The attacker can also use its own module/witness to occupy shared-root capacity with permanent modules and advance its revision, causing contention or capacity denial.

**Impact:** removable attached objects can be appropriated; native child Souls can be appropriated with their descendants. The root itself remains shared. A holder policy in a wrapper or UI does not constrain a directly callable shared Soul mutator.

**Scope limitation:** an unrelated actor cannot obtain `&mut Soul` for another address's existing owned object merely by knowing its ID or revision. The pinned framework also prevents simply sharing an old address-owned root in a later transaction. The dangerous initial share is performed by an actor already controlling issuance/new value custody.

**Minimal direction:** make the supported ownership-state contract explicit and require producer/consumer checks rejecting directly shared Souls when private-asset authority is required. A custodian can keep a Soul owned beneath a wrapper and expose guarded wrapper operations. If direct shared Soul support is required, define and verify a real authority mechanism for every mutator/exit; adding business administration to all private Souls is not implied. Add a separate attacker-sender scenario demonstrating the accepted or rejected shared-state behavior.

## SR-02 — Public Origin metadata permits noncanonical, permanent whole-Soul wrapping

**Evidence class:** confirmed source fact; defect/severity is a design discussion pending the intended exit invariant. Not reproduced here. **Potential impact:** medium if consumers assume that every Soul-inside-Soul relationship has the native unconditional exit guarantee. **Confidence:** high for acceptance of the construction; medium for product-defect interpretation.

**Exact source:** `Origin` has copy/drop/store at lines 43–50 and is publicly returned by `origin` at line 220. `same_module<W,T>` tests only original package/module at lines 89–95. Generic `install` at lines 159–173 has no `T = Soul` reservation and accepts caller-selected name/removability/semantic hash. Permanent uninstall aborts at line 184; commit preserves the existing descriptor's removable flag at lines 210–214. Native construction/exit is lines 258–280.

**Concrete source trace, not an executed PoC:** the caller owns `parent` and `child`, gets `let w = soul::origin(&child)`, then calls `soul::install<Origin, Soul>(&mut parent, w, b"other", child, 1, false, hash32, revision)`. `Origin` and `Soul` are both from the standard's `soul` module, so the same-module test succeeds. The resulting descriptor is under namespace `Origin`, not `NestedSoulWitness`, and is permanent. `unnest(parent, child_id, revision)` cannot find it; `uninstall<Origin,Soul>` rejects it; begin/commit can temporarily extract it but the hot potato forces its same-ID return to the same parent. There is no existing public source path to change removability.

**Realistic actor and impact:** an owner or a third-party composition builder authorized to use the parent's mutable value constructs this alternative relationship. A later parent buyer cannot detach the original child through the current kernel API. Software that enumerates only `nested`'s canonical namespace can also miss this custody relationship, although general descriptors expose the actual value type and removable flag. The alternate namespace does not forge a child Soul's identity or origin.

**False-positive guard:** the comment at lines 258–259 narrowly says that no application can turn **this namespace** into a permanent lock. That narrow guarantee holds: external code cannot construct `NestedSoulWitness`, and `nest` always sets removable=true. This finding does not prove alteration of that canonical descriptor. It challenges a broader assertion that the generic installation path cannot permanently hold a whole Soul. The optional-container calibration allows disclosed locking relationships, so whether this path should be forbidden requires a precise product decision.

**Minimal direction:** if whole-Soul custody must exclusively use canonical removable nesting, reserve `T=Soul` in generic install/update to the intended kernel witness/path. If noncanonical Soul custody is deliberate, document its separate locking semantics, expose it in discovery/acceptance rules, and scope the exit promise to the canonical namespace. Add the `Origin`-as-witness case as a conformance vector. This change belongs to the generic root/type boundary, not a Maker implementation.

## SR-D01 — Generic body hashes do not commit child dynamic fields or referenced external state

**Evidence class:** confirmed source fact; design/consumer discussion. **Severity:** no unconditional kernel vulnerability established. **Confidence:** high.

**Exact source:** `child_hash<T>` is SHA3-256 of `bcs::to_bytes(value)` at lines 105–109. Install/update store that digest at lines 169–170 and 211–212; supplied semantic hashes receive only a 32-byte-length check at lines 164 and 205. Manifest hashes descriptor records at lines 246–252.

**Trigger and actor:** an extension's object `T` holds its own dynamic fields, object references, or links to mutable shared data. BCS serializes `T`'s inline Move value; it does not walk storage under its UID or retrieve the linked objects. During a legitimate begin/commit update the source can change descendant DOFs while returning the same inline `T` bytes and the same supplied semantic hash. A mutable external referenced object can change independently without any Soul revision change at all.

**Impact:** a consumer treating `body_hash` or `manifest_hash` as a proof of all application behavior, current capability validity, balances, license state or external content would overstate the commitment. The kernel cannot validate arbitrary business semantics by accepting a hash.

**False-positive guard:** root revision still advances on every kernel commit, so a normal update through this path does change the root manifest even when the body hash is unchanged. Arbitrary installed children are not exposed as `&mut T` or `&mut UID` by this kernel. For canonical native Soul nesting, child descriptors and child manifests carry recursive snapshots, and updates require restoring each edited ancestor; this is stronger than the generic arbitrary-object BCS boundary. The remaining linked-state semantics belong to the source.

**Minimal direction:** document `body_hash` as an inline-object BCS commitment and `semantic_hash` as a source attestation with a declared schema/coverage. Sources that promise subtree or external content commitments must compute and verify those themselves; actual consumers must verify the source's current authorization/lifecycle/funds state. Do not claim discovery equals authorization. A generic source with a dynamic child and a mutable external reference would be a useful coverage test.

## SR-D02 — Origin proves input/type identity, not source-authorized business truth

**Evidence class:** confirmed source fact; already substantially acknowledged by source comments. **Severity:** no unconditional kernel vulnerability established. **Confidence:** high.

**Exact source:** `new` checks same original module, exact datatype name `SoulProducer`, hash length and positive declared version at lines 115–120, then records actual type identities/object ID plus supplied version/hash and `ctx.sender()` at lines 123–126. Comments at lines 41–42 explicitly classify version/hash as module attestation. `same_module` deliberately compares only outer package/module; generic type parameters remain in the recorded full TypeName.

**Trigger and actor:** an autonomous producer exposes its SoulProducer marker or its issuance wrapper to users, accepts a shared/frozen source, gives the wrong source instance, declares arbitrary version/hash, mints several Souls from one source, or deletes the source after minting. The kernel cannot infer source ownership, authorship, issuance quota, license, content identity or continuing existence from the supplied input.

**Impact:** an integrator that treats provenance metadata as automatic copyright/permission/supply proof can accept invalid business claims. This is a producer/consumer verification failure; it does not let an attacker invent another package's marker type or source type with the same runtime identity.

**Minimal direction:** preserve source autonomy and specify the actual source proof/issuance entry point, marker-construction policy, version/hash meaning, object-instance binding and consumer checks. Record `minted_by` as transaction sender, not as proven author/current holder. Do not add a platform-wide whitelist or Maker business rules to the minimal core solely to address this discussion.

## SR-D03 — Manifest/CAS does not bind current ownership or transfer generation

**Evidence class:** confirmed source fact and intended behavior visible in existing test source; design/consumer discussion. **Severity:** no unconditional kernel authorization defect established. **Confidence:** high.

**Exact source:** Manifest fields at lines 84–87 and 246–250 include root identity/revision/provenance/modules, not owner or ownership generation. `Changed`/revision increments at lines 151–156 cover kernel install/uninstall/update only. `Soul` has store at line 31, enabling ordinary external public transfer. Frozen kernel test lines 73–75 intentionally computes a hash before transfer and asserts the same revision/hash after the buyer receives the root.

**Trigger and actor:** a source or app issues a credential/signature keyed only to Soul ID, revision or manifest hash, then the Soul is transferred. The old commitment stays valid, so a verifier that mistakes it for a holder or transfer-generation proof may preserve stale seller eligibility or misassign rights to a buyer.

**Impact:** stale authorization is possible in an incorrectly designed consumer. Current address ownership still protects access to an owned `&mut Soul`, so an old owner cannot continue kernel mutation merely by retaining the old manifest.

**Minimal direction:** state that the manifest is an asset-state snapshot. Each source must declare whether its capability follows stable Soul identity, current holder, issuer-managed authorization generation or actual custody, and verify that rule at use/transfer/exit. Do not infer that all externally referenced assets or credentials travel with the root.

## SR-D04 — Permanent installation consumes a finite root budget; some valid roots exceed optional child capacity

**Evidence class:** confirmed source fact; design/availability discussion. **Severity:** no unrelated actor DoS against a normal private Soul established. **Confidence:** high for limits, medium for practical protocol boundary without runtime measurement.

**Exact source:** limits are 64 descriptors and 245,760 serialized child bytes at lines 21–22; permanent withdrawal rejects at line 184; root name has no smaller kernel limit, explicitly explained at lines 103–104; new accepts that string at lines 111–122. Updates hash before re-add at line 212. Native nest hashes/installs the child at lines 263–264.

**Trigger and actor:** an authorized installer fills 64 permanent slots or installs a child whose future inline evolution exceeds the child byte limit. If the target execution protocol permits a root larger than 245,760 serialized bytes but within its object limit, that valid root cannot be installed/nested by this optional path. Runtime object size/gas limits, including exact envelope overhead, remain to be measured.

**Impact:** capacity cannot be reclaimed by removing a permanent descriptor; later extensions can fail. An update that exceeds the child bound aborts atomically, retaining the original installed value. Native child exit uses direct uninstall and does not recompute the child's body hash, so an excessive desired update does not establish permanent native exit lock.

**Minimal direction:** declare per-root capacity/removability and optional composition-size limits in the supported contract and test the 64th/65th, byte boundary and update-failure/exit paths. Treat permanent-slot installation as a concrete custody/capacity choice visible to the owner/buyer; this does not imply forcing every future capability into the root.

## Invariants and challenged false positives

1. **Owned-object authority:** no mutable root UID, mutable child reference, mutable Soul field setter or unrestricted child access is exported. A private owned root's mutable reference remains protected by Sui object input/custodian authority.
2. **Creation authenticity boundary:** non-module/primitive witnesses fail before TypeName address/module operations; a witness with a different module fails; public generic metadata cannot bypass `new`'s exact `SoulProducer` datatype-name test. Producer business attestation remains source responsibility.
3. **Namespace/type isolation:** DOF keys are `ModuleKey<W>` with private fields, stored descriptors use the same exact namespace type and label, duplicate install is checked, and index checks exact value type. Same textual names across packages/modules/types do not collide.
4. **Upgrade identity stability:** in the pinned stdlib, `with_defining_ids` returns the package that **first introduced** a type (type_name.move lines 42–50); it is not a mutable latest package ID. `with_original_ids` allows same original module identity across versions. No automatic namespace drift on every upgrade was found.
5. **Edit linearity:** Edit has no abilities at lines 72–77, constructor/destructor are inside the module, and commit consumes it. Source ID, child ID and revision binding are checked at lines 206–211. Under ordinary Move/PTB linearity, an unfinished Edit cannot be dropped, stored or survive a successful transaction. Tests/bytecode-negative evidence should establish this at the target toolchain, rather than assuming a test count proves it.
6. **Commit integrity:** edits block normal root mutation and manifest certification via ready; commit requires the same root and object, cannot downgrade descriptor schema, recomputes body hash, restores the DOF and only then clears editing/increments revision. Removability cannot be upgraded from permanent to removable through commit.
7. **No installed generic mutation escape:** `borrow_module` returns `&T`, not `&mut T`; no parent UID is available to callers. Linked external mutable state is outside this invariant, as discussed above.
8. **Native nesting identity/exit:** native nest uses the actual child ID as key, derives semantic hash from the child's ready manifest and sets removable=true. Native nested updates retain both child and parent identity and refresh parent commitment. Direct native unnest does not recursively traverse or hash descendants; arbitrarily deep composition therefore does not by itself prove permanent exit denial. Ordinary Move object linearity prevents materializing a self/ancestor cycle; the explicit self-ID check also rejects the immediate case.
9. **Atomic failed paths:** stale revisions, duplicate installs, failed hash/size/schema/identity checks and failed edit completion do not leave a successful partially removed child or persisted editing flag. No separate cancellation path is needed to repair an aborted transaction.
10. **Bounded discovery arithmetic:** module scans cap at 64 entries; page validates offset before subtraction and only adds limit when limit is less than the bounded remaining count. No u64 offset+limit overflow path was found.
11. **No platform runtime administrator in this source:** init issues a standard package Publisher for package-origin integrations. It does not grant permission to mutate arbitrary private Soul roots, install business rules, or control source-module funds. Creating TransferPolicy<Soul> does not make ordinary public transfers automatically enforce that policy.

## Coverage limits and remaining evidence

The frozen suite contains 24 kernel test definitions and 2 Publisher test definitions. It covers ordinary provenance, install/update/exit, namespace/type isolation, transfer, permanent exit rejection, stale revisions, duplicate install, hot-edit visibility, replacement/other-parent identity rejection, schema regression, paging and three-level native composition. This reviewer did not execute them.

Missing source-level test vectors include directly shared attacker withdrawal/capacity occupation; Origin-as-witness permanent Soul construction; exposed-versus-private producer markers and wrong marker datatype; source hash/version attestation semantics; generic child-owned DOF/external shared-state hash scope; unfinished/forged Edit bytecode negatives; exact capacity/byte limits and rollback/exit; migration/upgrade consumer combinations; and the actual published ownership/UpgradeCap configuration. Some are source/adapter conformance checks rather than requirements to expand the minimal core.

Repository module.json presently declares empty release units/production targets/actual consumers and pending acceptance/authority mappings. That is a deployment evidence gap, not proof of a source exploit and not proof that the ecosystem has zero dependencies or immutable/admin-free deployment. Existing declared build evidence does not establish source cutover, on-chain authorization, actual consumer compatibility or external audit approval.

This report's conclusions remain pinned to the exact source hash. Any remediation must produce a new candidate and reverify affected invariants; no implementation changes are part of this review.
