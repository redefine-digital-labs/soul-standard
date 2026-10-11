# Minimal Soul contract and compatibility review

Date: 2026-10-11. Review role: independent read-only source and architecture reviewer. Scope: the frozen minimal Standard package, its canonical maintenance declarations, and the confirmed kernel direction. This is an internal AI review, not a qualified external audit or deployment acceptance.

## Conclusion

The frozen kernel is application-independent and substantially follows the confirmed minimal-asset direction. It contains one production module, no Maker/market/channel/community/policy imports, no platform registration, and no required installed application. Its real object input and module witness authenticate provenance at the module/type boundary; its private UID, typed DOF key and linear edit ticket preserve the root/child identities and permanent direct containment under the reviewed code.

I found no confirmed unprivileged theft, forged private namespace, permanent-child withdrawal, or successful incomplete-edit path in this source review. Two important guarantees are narrower than their names can suggest: descriptor schema monotonicity holds only while a descriptor remains installed; type origins and CAS do not establish current-implementation or old-writer rejection. These are actionable contract/declaration decisions, not reasons to add a platform whitelist or business code to Standard. Release identity, effective upgrade authority, and exact consuming contracts remain incomplete in the canonical records. Source review alone cannot close them.

## Exact candidate, method and evidence limits

- Root: /Users/naoer/Documents/Claude/Projects/soulidity-ecosystem/soul-standard.
- Frozen source: evidence/minimal-soul-audit-20261011-r1/frozen-package/sources/soul.move.
- SHA-256: 0574d86b7d40dd42e22774b3bd68d9f5e7705fda2cf805cfe58a31d3e777c2c7; independently recomputed and matched.
- All six frozen package inputs and all seven candidate reference guards independently matched candidate.json. The report is the only requested write; production, frozen sources, dependencies and CURRENT were preserved.
- Framework revision: 2a0becb2fcc6989e492981104af67f62f2c9511a from frozen Move.toml:6 and Move.lock:7–23. Relevant type_name/package/transfer/dynamic_object_field/object sources were read from the matching local Sui cache.
- Read canonical AGENTS.md, MODULE.md, COMPATIBILITY.md, RUNBOOK.md and module.json. The frozen-package directory has no AGENTS.md; the repository instructions apply.
- Read SOUL_STANDARD_KERNEL_CN.md:1–45, worktree PROJECT_MEMORY/CURRENT and its sole named handoff. These preserve the full product objective and the existing pointer; this bounded audit does not close that objective.
- Read all frozen tests and selected actual integration-example source snippets. Those snippets illustrate boundaries and are outside this package's frozen proof. Their prior claimed PASS counts were not treated as fresh proof.
- No CLI, Move tests, compiler, chain transaction, external message or new subagent was run by this reviewer. Proposed tests below are **not_run** in this review. Fresh executable results must be supplied by the coordinator's separately pinned evidence.

Handbook: v1.0, 2026-10-06; sections 1–4, 5, 7, 8.1, 8.3–8.4, 9 and 12 read. Operating model section 8 read. Relevant original responsibility references are DOF-001, C01, J20/J25/J28 and D01 as retained by module.json; existing Owners remain unchanged. current_record_ref and actual acceptance/authority identities are pending. Attach this report to the existing record; it does not create a board, replace an Owner or constitute signing/upgrade authorization.

## Findings and decisions

### CR-01 — A removable descriptor can reset its schema on reinstallation

Classification: verified source behavior; compatibility/invariant ambiguity. Priority: P2 if an accepted contract promises schema monotonicity for the same object across detach/reattach; otherwise an explicit lifecycle boundary, not a security defect. Confidence: high for behavior, conditional for policy violation.

Source: soul.move:159–174, 181–187, 201–214. commit_update checks schema >= d.schema at line 211. uninstall removes d entirely at line 187. install only requires schema > 0 at line 164 and absence of the namespace/name at line 165, then records the caller's schema at line 170. No historical floor/tombstone survives removal.

A valid producer can install a removable T under W/name at schema 2, uninstall it, then reinstall the **same object ID** under the same W/name at schema 1 with the current root revision. The linear ticket and original-ID protections do not apply across this remove/install lifecycle. Root revision continues increasing, so the root snapshot changes and a stale assert_manifest still rejects; this does not silently preserve an old manifest.

Impact: a consumer that remembers a module's highest schema or treats the descriptor number as an irreversible object migration can misclassify the reattached value. The source example independent_ability::ability reattach at standard_examples/ability/sources/ability.move:40–43 hardcodes schema 1; this is evidence of a real reattachment pattern, not a claim that that example has already migrated to schema 2.

False-positive analysis: successful reinstall still requires an actual mutable Soul, the correct same-module witness and T. This does not let an unrelated attacker edit another owner's root or a private application namespace. The current frozen schema-regression test at kernel_tests.move:103–104 exercises commit_update only, and correctly proves that narrower property. A removable installation can reasonably define a new descriptor lifecycle.

Discussion options:

1. State that monotonicity is installation-scoped; require the source to keep/revalidate any lifetime schema floor in T or its authoritative state. This preserves the minimal kernel.
2. If lifetime monotonicity is a confirmed Standard invariant, design a floor keyed by exact namespace/name/object and its retention semantics before implementing it. Tombstones for all withdrawn objects have growth and same-name replacement implications; do not add them merely to satisfy a vague claim.
3. If only particular applications migrate irreversibly, enforce their schema floor at reattach and all old entry points in the source package.

Acceptance tests: schema 2 update to 1 aborts; removable schema 2 uninstall/reinstall as 1 demonstrates the chosen behavior; same object reattach and new object replacement are distinct cases; stale root revision/hash fails after either path. **Not run here.**

### CR-02 — Type witnesses and schema numbers do not prove current writer code

Classification: unresolved upgrade/consumer obligation; P2 release/compatibility gate when current-issuer or old-writer rejection is required. No present unprivileged exploit is established. Confidence: high for the distinction; published reachability remains unverified.

Source: soul.move:89–95, 101–102, 111–126, 159–173, 190–214. same_module compares original package/module identities. Origin, namespace and value_type use defining type IDs. ready requires root schema 1 and no active edit. cas checks the supplied current root revision. A descriptor schema is a number supplied by source code; it is not tied to the witness's implementation release.

Pinned std::type_name source:42–57 explicitly defines a defining ID as the package that first introduced the type, and an original ID as the first package version even for a later-introduced type. Thus an unchanged W/P/T keeps its type identity after function bodies are upgraded. with_defining_ids is **not** the current callable package ID, code digest, UpgradeCap version or latest issuance authority. A newly introduced witness can have a later defining ID, but no general current-version test follows from that fact. same_module intentionally allows a newly added source-module witness to operate with earlier source-module T.

Root schema == 1 is a real fail-closed hook for old code if a future authorized migration changes the root schema and its supported behavior. This frozen package has no such migration, and a compatible upgrade leaving schema 1 does not automatically invalidate old kernel/producer/application entry points. CAS stops stale edits, not an old function that reads the current revision. Monotonic d.schema stops a fixed schema-1 old commit after migration to 2; it does not reject an old routine accepting a supplied schema or a remove/reinstall path. Actual mixed-package calls can fail linkage instead; a linkage failure must not be reported as the intended business/version rejection.

False-positive analysis: the minimal Standard need not have one ecosystem-wide version oracle, producer whitelist or admin registry. Open third-party issuance is intended. Need for revocation of obsolete writers depends on the actual source/application behavior and chosen Standard upgrade. No published package pair/current-state receipt was supplied by the canonical declaration.

Discussion options:

1. Pin/freeze the minimal v1 behavior and disclose the chosen UpgradeCap restrictions or immutability with actual chain evidence.
2. For Standard behavior changes, define a root-schema migration and test the actual obsolete Standard calls against migrated and unmigrated roots.
3. For source-specific current-issuer rules, maintain source-owned version/issuer state and guard issuance, update, reattach and other protected entries there. Rotating a newly introduced typed marker can be part of that design, but exact defining origins and old entries must be verified.

Acceptance tests: real v1/v2 publish/upgrade pair; unchanged and newly added witness types; v1/v2 issuer and mutation calls against existing roots; migrations with preserved origin/IDs; retired writer using current CAS; schema-2 commit and reattach; intentional safe reads/exits. Pin dependency/linkage, function target and primary failure for each case. **Not run here.**

### CR-03 — Effective upgrade control and release/consumer identity are still unknown

Classification: verified declaration gap, release blocker; P2 for release readiness, not a code exploit or failed deployment. Confidence: high.

Source: MODULE.md:6–7, 11–18; COMPATIBILITY.md:3–13; module.json:650–689, 728–731, 857, 911–914, 956–965. compatibility.consumers is empty, release_units and production_targets are empty, candidate_identity is null, and effective authority paths/actual holders remain pending. The manifests identify local source and the Sui dependency, not the chain's original/current package, type origins, Publisher, UpgradeCap holder/policy or consumed release combinations.

The declaration says upgrade_authority_grants_runtime_authority=false and Standard maintainers do not control user assets. Under this exact source, there is no admin operation that directly confiscates an address-owned Soul. However a holder allowed a Compatible upgrade can alter existing function bodies or add authorized code in the module defining Soul; private UID/descriptor fields and permanent-containment checks are then part of the upgrade trust boundary. The pinned sui::package source:76–104, 192–210 and 258–315 distinguishes Compatible/Additive/Dependency-only policy and mutable latest-package/version state. No deployed policy is proved by the pending records.

This does **not** mean an UpgradeCap holder can submit any other wallet's owned Soul as a transaction input. Sui ownership still applies; exposing mutable root custody through a shared/container application can change the reachable impact. Permanent module containment is verified for the frozen code, not proof of permanent package immutability, an asset timelock or a pause mechanism.

SOUL init at soul.move:24–29 claims a real Publisher on initial publish. The pinned sui::package source:139–179 establishes Publisher lineage/module matching; Publisher is distinct from UpgradeCap and publicly transferable. publisher_tests.move:8–21 proves a test environment constructor path, not the actual deployed Publisher ID/owner, policy rules or initial publication. Sui upgrade init does not rerun (handbook 8.4); introducing this init in an already-published lineage is not proof of retroactive Publisher creation. TransferPolicy creation also does not enforce rules on all public_transfer paths.

Action: before Release, fill exact original/current package/type origins, dependency linkage and artifact hashes; actual Publisher and every effective UpgradeCap/policy/custody path; actual consumer ABI/types/schema/behavior/required effects/authority/failure and evidence. Preserve the difference between source backup, artifact construction, release, deploy and product acceptance. Describe upgrade trust separately from transaction ownership. No mandatory freeze, multisig or timelock is prescribed by this review; the decision needs real evidence and original authorization.

Acceptance: read back the exact published artifact, init effects and Publisher; verify Cap original/current package/version/policy and any wrapper/governance recovery path; test actual consumer combinations and frozen-market journeys; verify policy creation vs direct public transfer. **Not run here.**

## Important boundaries that are not kernel defects

### Provenance proves a source module relation, not business legitimacy

soul.move:111–126 requires a nonprimitive same-module W/P and a W datatype named SoulProducer. A matching marker is a designated producer convention; the kernel cannot prove its constructor remains private across every source API or upgrade. Move field privacy prevents unrelated code constructing that exact private marker; source code chooses whether it exposes issuance or the marker. Generic SoulProducer arguments are not excluded because datatype_string returns the base datatype name (pinned type_name.move:130–161); exact accepted producer TypeName must be a consumer contract if this distinction matters.

source is object::id of an actual P reference, not an arbitrary ID parameter. source_version and source_hash are source attestations (positive number and 32-byte length); the kernel does not recompute a source-specific definition hash, check supply, license, payment, freshness or producer governance. P may be owned, immutable, shared or internally borrowed; minted_by is transaction sender, not necessarily creator, source owner or royalty beneficiary. Origin is immutable through this ABI, but the referenced source need not remain live, owned by the buyer or unchanged after issuance. This is appropriately minimal. Consumers needing certified production must use the exact source proof and source behavior, not accept every structurally valid Soul as business-authorized. No global platform approval is necessary.

### The manifest is ordered root/descriptor state, not stable asset identity or owner proof

soul.move:84–87 and 246–255 commits domain, Soul ID, root schema/name/revision/origin and the descriptor vector **in stored order**. install appends and uninstall removes while retaining other order. Equal sets installed in different orders can have different hashes. A transfer keeps the hash/revision; kernel_tests.move:71–77 deliberately tests that. Stable asset identity is the real Soul ID plus immutable provenance/type relationship, not the entire manifest hash.

body_hash is BCS of direct T at soul.move:105–108, 170 and 212. Dynamic field objects are separate storage children: pinned dynamic_object_field.move:257–305 adds/borrows/removes them through a wrapper and child-object ID. Direct BCS cannot establish a complete generic descendant inventory, content availability or external relation state. semantic_hash is supplied by the source except native nesting, which commits child manifest_hash at lines 263 and 278. Recursive native nesting propagates recorded manifests through supported updates, but still does not interpret an arbitrary extension's descendant or external state. The output-extension example:18–20 deliberately adds actual Artifact-derived facts beyond direct Extension BCS; content-controller:19 hashes its direct Extension state and has a different scope. Neither is evidence of a universal recursive inventory guarantee.

Action for consumers: explicitly choose an ordered snapshot vs a canonical unordered semantic commitment; bind a separate expected owner/custodian and any transaction/chain identity when signing a sale or authorization; verify actual inventory and relevant source semantics. Do not change the existing v1 manifest ordering merely because a different comparison is useful. Proposed tests: install-order permutation; ownership transfer with unchanged manifest; two extension objects with equal direct fields but different descendant/external facts; nested update propagates; revision/hash mismatch fails. **Not run here.**

### Actual mutable custody is the authority boundary, and public transfer has no universal hook

Soul has key+store (line 31), so a legitimate value holder can public_transfer, wrap it, freeze it, or share a fresh object via Sui's permitted paths (pinned transfer.move:58–65, 106–130). The type alone does not guarantee that every Soul is always address-owned. Public mutable functions use actual &mut Soul; they do not generally check ctx.sender. An address-owned Soul relies on Sui input ownership; a custodian exposing &mut Soul must impose its own policy. A directly shared Soul makes generic witness-free removable uninstall/unnest at lines 181–187/269–270 publicly reachable with a current revision. That requires deliberate shared/custody creation and is not a bypass of an owned root's owner.

uninstall does not require possession of W; it requires the actual mutable root, exact W/T/name and removable=true. This intentionally gives the holder a generic exit. begin_update requires the exact witness, and permanent=false cannot be introduced through commit_update. A removable module can be taken out; a permanent direct child must return with its original ID under the same root and revision. This is containment, not a guarantee of unlimited usability or source/business exit rights.

The linear Edit has no abilities (lines 70–77); successful completion must consume it via exact-root/exact-object commit. No raw mutable UID or mutable child reference escapes this ABI. Reads during editing cannot certify a manifest. No successful incomplete edit or ID replacement path was found. A permanent module's source can still withhold an update function; permanent containment does not promise a generic business-operation repair path.

Direct public_transfer does not increment revision, rotate grants, call sources, revoke delegates, prove KMS acceptance or move unrelated wallet assets. A Publisher or TransferPolicy does not globally intercept this transfer. The confirmed kernel direction explicitly puts these lifecycle rules with sources and actual transaction entries. Consumers should test A→B→A and distinguish current-holder checks from irreversible revocation; the content-controller example tests this return/restored-domain distinction at sources/tests.move:20–24. Unknown passive modules can remain compatible; a market actually assuming a cleanup/settlement/transfer restriction needs an explicit adapter and evidence.

### Native nested Souls and optional extensions are consistent with atomic identity

nest/unnest preserve distinct parent/child identities and Origins. Native nesting is always removable by the mutable parent custodian and cannot be made permanent through the private NestedSoulWitness constructor. During native edit, child and parent commits require exact IDs; child manifest prevents a live child edit from completing a parent commit prematurely. MAX_MODULES=64 and direct child byte bound=245760 cap local work; deeper application traversal/resource bounds remain each consumer's obligation.

Zero installed modules is valid. External assets/relations and revocable or expiring qualifications do not have to be installed. This kernel offers an optional DOF descriptor format; it does not implement all six candidate optional interoperability standards in SOUL_STANDARD_KERNEL_CN.md:23–30. That is an explicit design boundary, not authority to move optional business/lifecycle rules into Standard or cancel original Ref/Bound/Free, supply, payment, content and exit duties. Actual source-specific rights remain part of the parent product work.

## Required follow-up matrix

| Item | Source-review result | Remaining proof / responsibility |
| --- | --- | --- |
| Minimal Standard ownership | Pass for this frozen source's separation | Source Owner maintains sole authority; no application import required |
| Source/type/witness relation | Pass for structural relation | Consumer/source defines accepted proof and issuance semantics |
| Private namespace/direct identity/edit atomicity | Pass by reviewed ABI and source structure | Fresh Move/foreign compiler/PTB evidence belongs to executable audit |
| Permanent direct containment | Pass under frozen code | Actual upgrade-policy trust and legitimate source exits remain separate |
| Monotonic descriptor schema | Pass for commit, lifecycle decision pending | Source/consumer or Standard Owner chooses detach/reattach contract |
| Old-writer/current-issuer rejection | Not established | Exact release pair, source guards/root migration and real old-entry tests |
| Root/descriptor manifest | Pass for declared BCS snapshot | Consumer defines owner, ordering, descendants and actual inventory |
| Publisher/UpgradeCap/release identity | Pending | Release/Deploy Owner fills real Cap/Publisher/target readback |
| Unknown passive extension / unchanged old market | Pending for frozen candidate | Pin market source/lock/config/artifact and execute original listing/cancel/sale |
| Financial models/EVM/production operation | N/A in this source audit | No funds formula, EVM implementation or production operation in scope |

All proposed changes above are discussion options. No fix, migration, cap restriction, signature, commit, push or deployment is authorized or performed by this report. The coordinator should merge this source review with separately verified fresh tests, preserve failed/unknown cases, and attach remaining conditions to the original record before any release claim.
