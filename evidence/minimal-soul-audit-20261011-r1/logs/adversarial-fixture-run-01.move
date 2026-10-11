#[test_only]
module soulidity_standard::audit_adversarial;

use std::bcs;
use std::string;
use sui::dynamic_object_field as dof;
use sui::test_scenario;
use soulidity_standard::soul::{Self, Soul};

// All constructors and the required exact marker name are local to this fixture.
public struct SoulProducer has drop {}
public struct Source has key, store { id: UID }
public struct Witness has drop {}
public struct Value has key, store { id: UID, score: u64 }
public struct Leaf has key, store { id: UID, score: u64 }
public struct LeafKey has copy, drop, store {}

fun h(): vector<u8> { x"0909090909090909090909090909090909090909090909090909090909090909" }
fun create(ctx: &mut TxContext): Soul {
    let source = Source { id: object::new(ctx) };
    let root = soul::new(SoulProducer {}, &source, 1, h(), string::utf8(b"audit"), ctx);
    transfer::public_transfer(source, ctx.sender());
    root
}
fun value(score: u64, ctx: &mut TxContext): Value { Value { id: object::new(ctx), score } }
fun install(root: &mut Soul, removable: bool, ctx: &mut TxContext): ID {
    let v = value(7, ctx);
    let id = object::id(&v);
    soul::install(root, Witness {}, b"module", v, 1, removable, h(), soul::revision(root));
    id
}

#[test]
fun fresh_shared_root_allows_stranger_uninstall_original_module() {
    let mut sc = test_scenario::begin(@0xa);
    let mut root = create(sc.ctx());
    let root_id = object::id(&root);
    let child_id = install(&mut root, true, sc.ctx());
    transfer::public_share_object(root);
    sc.next_tx(@0xb);
    assert!(sc.sender() == @0xb && !sc.has_most_recent_for_sender<Soul>(), 101);
    let mut root: Soul = sc.take_shared_by_id(root_id);
    let revision = soul::revision(&root);
    assert!(revision == 1 && soul::minted_by(&soul::origin(&root)) == @0xa, 102);
    // No Witness value, producer object, or author input is supplied here.
    let child = soul::uninstall<Witness, Value>(&mut root, b"module", revision);
    assert!(object::id(&child) == child_id && child.score == 7, 103);
    assert!(soul::module_count(&root) == 0 && soul::revision(&root) == 2, 104);
    transfer::public_transfer(child, @0xb);
    test_scenario::return_shared(root);
    sc.next_tx(@0xb);
    let child: Value = sc.take_from_sender_by_id(child_id);
    assert!(child.score == 7, 105);
    sc.return_to_sender(child);
    let root: Soul = sc.take_shared_by_id(root_id);
    assert!(soul::module_count(&root) == 0 && soul::revision(&root) == 2, 106);
    test_scenario::return_shared(root);
    sc.end();
}

#[test]
fun fresh_shared_parent_allows_stranger_unnest_original_soul() {
    let mut sc = test_scenario::begin(@0xa);
    let mut parent = create(sc.ctx());
    let parent_id = object::id(&parent);
    let child = create(sc.ctx());
    let child_id = object::id(&child);
    let child_manifest = soul::manifest_hash(&child);
    soul::nest(&mut parent, child, 0);
    transfer::public_share_object(parent);
    sc.next_tx(@0xb);
    assert!(sc.sender() == @0xb && !sc.has_most_recent_for_sender<Soul>(), 111);
    let mut parent: Soul = sc.take_shared_by_id(parent_id);
    let child = soul::unnest(&mut parent, child_id, 1);
    assert!(object::id(&child) == child_id && soul::manifest_hash(&child) == child_manifest, 112);
    assert!(soul::minted_by(&soul::origin(&child)) == @0xa, 113);
    transfer::public_transfer(child, @0xb);
    test_scenario::return_shared(parent);
    sc.next_tx(@0xb);
    let child: Soul = sc.take_from_sender_by_id(child_id);
    assert!(object::id(&child) == child_id && soul::manifest_hash(&child) == child_manifest, 114);
    sc.return_to_sender(child);
    let parent: Soul = sc.take_shared_by_id(parent_id);
    assert!(soul::module_count(&parent) == 0 && soul::revision(&parent) == 2, 115);
    test_scenario::return_shared(parent);
    sc.end();
}

#[test, expected_failure(abort_code=0, location=sui::transfer)]
fun previously_owned_root_cannot_be_newly_shared() {
    let mut sc = test_scenario::begin(@0xa);
    let root = create(sc.ctx());
    transfer::public_transfer(root, @0xa);
    sc.next_tx(@0xa);
    let root: Soul = sc.take_from_sender();
    transfer::public_share_object(root);
    sc.end();
}

#[test, expected_failure(abort_code=3, location=sui::test_scenario)]
fun private_owned_root_is_absent_from_stranger_sender_inventory() {
    let mut sc = test_scenario::begin(@0xa);
    let mut root = create(sc.ctx());
    install(&mut root, true, sc.ctx());
    transfer::public_transfer(root, @0xa);
    sc.next_tx(@0xb);
    // Positive owner inventory check distinguishes bad fixture setup from denial.
    assert!(test_scenario::has_most_recent_for_address<Soul>(@0xa), 121);
    assert!(!sc.has_most_recent_for_sender<Soul>(), 122);
    let mut root: Soul = sc.take_from_sender();
    let child = soul::uninstall<Witness, Value>(&mut root, b"module", 1);
    transfer::public_transfer(child, @0xb);
    sc.return_to_sender(root);
    sc.end();
}

#[test]
fun private_owned_root_owner_can_access_and_uninstall() {
    let mut sc = test_scenario::begin(@0xa);
    let mut root = create(sc.ctx());
    let child_id = install(&mut root, true, sc.ctx());
    transfer::public_transfer(root, @0xa);
    sc.next_tx(@0xa);
    let mut root: Soul = sc.take_from_sender();
    let child = soul::uninstall<Witness, Value>(&mut root, b"module", 1);
    assert!(object::id(&child) == child_id, 123);
    transfer::public_transfer(child, @0xa);
    sc.return_to_sender(root);
    sc.end();
}

#[test]
fun fresh_root_can_be_publicly_frozen_and_read_by_stranger() {
    let mut sc = test_scenario::begin(@0xa);
    let mut root = create(sc.ctx());
    let child_id = install(&mut root, true, sc.ctx());
    let root_id = object::id(&root);
    let manifest = soul::manifest_hash(&root);
    transfer::public_freeze_object(root);
    sc.next_tx(@0xb);
    assert!(!sc.has_most_recent_for_sender<Soul>() && test_scenario::has_most_recent_immutable<Soul>(), 131);
    let root: Soul = sc.take_immutable_by_id(root_id);
    assert!(soul::manifest_hash(&root) == manifest, 132);
    assert!(object::id(soul::borrow_module<Witness, Value>(&root, b"module")) == child_id, 133);
    test_scenario::return_immutable(root);
    sc.end();
}

#[test, expected_failure(abort_code=9, location=soulidity_standard::soul)]
fun permanent_child_edit_cannot_substitute_new_object_id() {
    let mut sc = test_scenario::begin(@0xa);
    let mut root = create(sc.ctx());
    install(&mut root, false, sc.ctx());
    let descriptor = soul::descriptor<Witness>(&root, b"module").destroy_some();
    assert!(!soul::removable(&descriptor), 141);
    let (child, ticket) = soul::begin_update<Witness, Value>(&mut root, Witness {}, b"module", 1);
    transfer::public_transfer(child, @0xa);
    let replacement = value(88, sc.ctx());
    assert!(object::id(&replacement) != soul::module_id(&descriptor), 142);
    soul::commit_update(&mut root, ticket, Witness {}, replacement, 1, h());
    transfer::public_transfer(root, @0xa);
    sc.end();
}

#[test]
fun permanent_child_valid_edit_keeps_id_and_permanence() {
    let mut sc = test_scenario::begin(@0xa);
    let mut root = create(sc.ctx());
    let child_id = install(&mut root, false, sc.ctx());
    let (mut child, ticket) = soul::begin_update<Witness, Value>(&mut root, Witness {}, b"module", 1);
    child.score = 88;
    soul::commit_update(&mut root, ticket, Witness {}, child, 1, h());
    let descriptor = soul::descriptor<Witness>(&root, b"module").destroy_some();
    assert!(!soul::removable(&descriptor) && soul::module_id(&descriptor) == child_id, 143);
    assert!(soul::borrow_module<Witness, Value>(&root, b"module").score == 88 && soul::revision(&root) == 2, 144);
    transfer::public_transfer(root, @0xa);
    sc.end();
}

#[test]
fun extension_leaf_change_can_leave_body_and_attested_semantic_hash_equal() {
    let mut sc = test_scenario::begin(@0xa);
    let mut root = create(sc.ctx());
    let mut child = value(7, sc.ctx());
    let child_id = object::id(&child);
    let leaf = Leaf { id: object::new(sc.ctx()), score: 7 };
    let leaf_id = object::id(&leaf);
    dof::add(&mut child.id, LeafKey {}, leaf);
    soul::install(&mut root, Witness {}, b"module", child, 1, false, h(), 0);
    let before = soul::descriptor<Witness>(&root, b"module").destroy_some();
    let root_before = soul::manifest_hash(&root);
    let (mut child, ticket) = soul::begin_update<Witness, Value>(&mut root, Witness {}, b"module", 1);
    let bytes_before = bcs::to_bytes(&child);
    dof::borrow_mut<LeafKey, Leaf>(&mut child.id, LeafKey {}).score = 77;
    assert!(bcs::to_bytes(&child) == bytes_before && object::id(&child) == child_id, 151);
    // Deliberately stale application attestation: the kernel accepts 32 bytes,
    // but cannot infer a generic extension's descendant semantic commitment.
    soul::commit_update(&mut root, ticket, Witness {}, child, 1, soul::semantic_hash(&before));
    let after = soul::descriptor<Witness>(&root, b"module").destroy_some();
    let child = soul::borrow_module<Witness, Value>(&root, b"module");
    let leaf: &Leaf = dof::borrow(&child.id, LeafKey {});
    assert!(leaf.score == 77 && object::id(leaf) == leaf_id, 152);
    assert!(soul::body_hash(&before) == soul::body_hash(&after), 153);
    assert!(soul::semantic_hash(&before) == soul::semantic_hash(&after), 154);
    assert!(soul::revision(&root) == 2 && soul::manifest_hash(&root) != root_before, 155);
    transfer::public_transfer(root, @0xa);
    sc.end();
}

#[test]
fun ownership_transfer_preserves_revision_manifest_and_mint_origin() {
    let mut sc = test_scenario::begin(@0xa);
    let mut root = create(sc.ctx());
    let child_id = install(&mut root, true, sc.ctx());
    let root_id = object::id(&root);
    let revision = soul::revision(&root);
    let manifest = soul::manifest_hash(&root);
    transfer::public_transfer(root, @0xb);
    sc.next_tx(@0xb);
    let root: Soul = sc.take_from_sender_by_id(root_id);
    assert!(soul::revision(&root) == revision && soul::manifest_hash(&root) == manifest, 161);
    assert!(soul::minted_by(&soul::origin(&root)) == @0xa, 162);
    assert!(object::id(soul::borrow_module<Witness, Value>(&root, b"module")) == child_id, 163);
    assert!(!test_scenario::has_most_recent_for_address<Soul>(@0xa), 164);
    sc.return_to_sender(root);
    sc.end();
}
