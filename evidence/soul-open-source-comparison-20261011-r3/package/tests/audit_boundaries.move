#[test_only]
module soulidity_standard::audit_boundaries;

use std::string;
use sui::test_scenario;
use soulidity_standard::soul::{Self, Origin, Soul};

public struct SoulProducer has drop {}
public struct Source has key, store { id: UID }
public struct Witness has drop {}
public struct Value has key, store { id: UID, score: u64 }

fun h(): vector<u8> { x"0808080808080808080808080808080808080808080808080808080808080808" }
fun create(ctx: &mut TxContext): Soul {
    let source = Source { id: object::new(ctx) };
    let root = soul::new(SoulProducer {}, &source, 1, h(), string::utf8(b"boundary"), ctx);
    transfer::public_transfer(source, ctx.sender());
    root
}

#[test]
fun origin_metadata_can_install_and_edit_permanent_noncanonical_soul() {
    let mut sc = test_scenario::begin(@0xa);
    let mut parent = create(sc.ctx());
    let child = create(sc.ctx());
    let child_id = object::id(&child);
    let witness = soul::origin(&parent);
    soul::install<Origin, Soul>(&mut parent, witness, b"noncanonical", child, 1, false, h(), 0);
    let before = soul::descriptor<Origin>(&parent, b"noncanonical").destroy_some();
    assert!(!soul::removable(&before) && soul::module_id(&before) == child_id, 201);
    let witness = soul::origin(&parent);
    let (mut child, ticket) = soul::begin_update<Origin, Soul>(&mut parent, witness, b"noncanonical", 1);
    let grandchild = create(sc.ctx());
    soul::nest(&mut child, grandchild, 0);
    let semantic = soul::manifest_hash(&child);
    let witness = soul::origin(&parent);
    soul::commit_update<Origin, Soul>(&mut parent, ticket, witness, child, 1, semantic);
    let after = soul::descriptor<Origin>(&parent, b"noncanonical").destroy_some();
    assert!(!soul::removable(&after) && soul::module_id(&after) == child_id, 202);
    assert!(soul::module_count(soul::borrow_module<Origin, Soul>(&parent, b"noncanonical")) == 1, 203);
    assert!(soul::revision(&parent) == 2, 204);
    transfer::public_transfer(parent, @0xa);
    sc.end();
}

#[test, expected_failure(abort_code=8, location=soulidity_standard::soul)]
fun permanent_noncanonical_soul_cannot_be_directly_uninstalled() {
    let mut sc = test_scenario::begin(@0xa);
    let mut parent = create(sc.ctx());
    let child = create(sc.ctx());
    let witness = soul::origin(&parent);
    soul::install<Origin, Soul>(&mut parent, witness, b"noncanonical", child, 1, false, h(), 0);
    let child = soul::uninstall<Origin, Soul>(&mut parent, b"noncanonical", 1);
    transfer::public_transfer(child, @0xa);
    transfer::public_transfer(parent, @0xa);
    sc.end();
}

#[test]
fun removable_schema_floor_resets_after_same_object_reinstallation() {
    let mut sc = test_scenario::begin(@0xa);
    let mut root = create(sc.ctx());
    let value = Value { id: object::new(sc.ctx()), score: 7 };
    let value_id = object::id(&value);
    soul::install(&mut root, Witness {}, b"value", value, 2, true, h(), 0);
    let before = soul::manifest_hash(&root);
    let value = soul::uninstall<Witness, Value>(&mut root, b"value", 1);
    assert!(object::id(&value) == value_id, 211);
    soul::install(&mut root, Witness {}, b"value", value, 1, true, h(), 2);
    let descriptor = soul::descriptor<Witness>(&root, b"value").destroy_some();
    assert!(soul::module_id(&descriptor) == value_id && soul::module_schema(&descriptor) == 1, 212);
    assert!(soul::revision(&root) == 3 && soul::manifest_hash(&root) != before, 213);
    transfer::public_transfer(root, @0xa);
    sc.end();
}
