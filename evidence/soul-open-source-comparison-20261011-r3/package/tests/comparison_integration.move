#[test_only]
module soulidity_standard::comparison_integration;

use std::string;
use sui::coin::{Self, Coin};
use sui::sui::SUI;
use sui::kiosk::{Self, Kiosk};
use sui::transfer_policy::{Self, TransferPolicy};
use sui::test_scenario;
use soulidity_standard::soul::{Self, Soul};

public struct SoulProducer has drop {}
public struct Source has key, store { id: UID }
public struct Witness has drop {}
public struct CoinModule has key, store { id: UID, coin: Coin<SUI> }
public struct Value has key, store { id: UID, score: u64 }
public struct Rule has drop {}

fun h(): vector<u8> { x"0909090909090909090909090909090909090909090909090909090909090909" }
fun create(ctx: &mut TxContext): Soul {
    let source = Source { id: object::new(ctx) };
    let root = soul::new(SoulProducer {}, &source, 1, h(), string::utf8(b"comparison"), ctx);
    transfer::public_transfer(source, ctx.sender());
    root
}

#[test, expected_failure(abort_code=3, location=soulidity_standard::soul)]
fun external_witness_cannot_directly_install_framework_coin() {
    let mut sc = test_scenario::begin(@0xa);
    let mut root = create(sc.ctx());
    let coin = coin::mint_for_testing<SUI>(7, sc.ctx());
    soul::install(&mut root, Witness {}, b"coin", coin, 1, true, h(), 0);
    transfer::public_transfer(root, @0xa);
    sc.end();
}

#[test]
fun external_coin_adapter_preserves_identity_and_balance_across_edit() {
    let mut sc = test_scenario::begin(@0xa);
    let mut root = create(sc.ctx());
    let coin = coin::mint_for_testing<SUI>(7, sc.ctx());
    let wrapped = CoinModule { id: object::new(sc.ctx()), coin };
    let id = object::id(&wrapped);
    soul::install(&mut root, Witness {}, b"coin", wrapped, 1, true, h(), 0);
    let (mut wrapped, edit) = soul::begin_update<Witness, CoinModule>(&mut root, Witness {}, b"coin", 1);
    let split = wrapped.coin.split(2, sc.ctx());
    transfer::public_transfer(split, @0xa);
    soul::commit_update(&mut root, edit, Witness {}, wrapped, 1, h());
    let wrapped = soul::uninstall<Witness, CoinModule>(&mut root, b"coin", 2);
    assert!(object::id(&wrapped) == id && coin::value(&wrapped.coin) == 5, 100);
    assert!(soul::revision(&root) == 3 && soul::module_count(&root) == 0, 101);
    let CoinModule { id, coin } = wrapped;
    id.delete();
    transfer::public_transfer(coin, @0xa);
    transfer::public_transfer(root, @0xa);
    sc.end();
}

#[test]
fun soul_edit_and_kiosk_borrow_tickets_compose() {
    let mut sc = test_scenario::begin(@0xa);
    let mut root = create(sc.ctx());
    let root_id = object::id(&root);
    let child = Value { id: object::new(sc.ctx()), score: 7 };
    let child_id = object::id(&child);
    soul::install(&mut root, Witness {}, b"value", child, 1, false, h(), 0);
    let (mut k, cap) = kiosk::new(sc.ctx());
    kiosk::place(&mut k, &cap, root);
    let (mut root, borrow) = kiosk::borrow_val<Soul>(&mut k, &cap, root_id);
    let (mut child, edit) = soul::begin_update<Witness, Value>(&mut root, Witness {}, b"value", 1);
    child.score = 88;
    soul::commit_update(&mut root, edit, Witness {}, child, 1, h());
    let manifest = soul::manifest_hash(&root);
    kiosk::return_val(&mut k, root, borrow);
    let root = kiosk::take<Soul>(&mut k, &cap, root_id);
    assert!(object::id(&root) == root_id && soul::revision(&root) == 2, 110);
    assert!(soul::manifest_hash(&root) == manifest, 111);
    let child = soul::borrow_module<Witness, Value>(&root, b"value");
    assert!(object::id(child) == child_id && child.score == 88, 112);
    let coin = kiosk::close_and_withdraw(k, cap, sc.ctx());
    transfer::public_transfer(coin, @0xa);
    transfer::public_transfer(root, @0xa);
    sc.end();
}

#[test, expected_failure(abort_code=0, location=sui::kiosk)]
fun wrong_kiosk_cap_cannot_borrow_soul() {
    let mut sc = test_scenario::begin(@0xa);
    let root = create(sc.ctx());
    let id = object::id(&root);
    let (mut k1, cap1) = kiosk::new(sc.ctx());
    let (k2, cap2) = kiosk::new(sc.ctx());
    kiosk::place(&mut k1, &cap1, root);
    let (root, borrow) = kiosk::borrow_val<Soul>(&mut k1, &cap2, id);
    kiosk::return_val(&mut k1, root, borrow);
    let root = kiosk::take<Soul>(&mut k1, &cap1, id);
    transfer::public_transfer(root, @0xa);
    let zero1 = kiosk::close_and_withdraw(k1, cap1, sc.ctx());
    let zero2 = kiosk::close_and_withdraw(k2, cap2, sc.ctx());
    transfer::public_transfer(zero1, @0xa);
    transfer::public_transfer(zero2, @0xa);
    sc.end();
}

#[test, expected_failure(abort_code=9, location=sui::kiosk)]
fun listed_soul_cannot_be_mutably_borrowed() {
    let mut sc = test_scenario::begin(@0xa);
    let root = create(sc.ctx());
    let id = object::id(&root);
    let (mut k, cap) = kiosk::new(sc.ctx());
    kiosk::place(&mut k, &cap, root);
    kiosk::list<Soul>(&mut k, &cap, id, 5);
    let root = kiosk::borrow_mut<Soul>(&mut k, &cap, id);
    assert!(soul::revision(root) == 0, 120);
    kiosk::delist<Soul>(&mut k, &cap, id);
    let root = kiosk::take<Soul>(&mut k, &cap, id);
    transfer::public_transfer(root, @0xa);
    let zero = kiosk::close_and_withdraw(k, cap, sc.ctx());
    transfer::public_transfer(zero, @0xa);
    sc.end();
}

#[test]
fun transfer_policy_rules_do_not_intercept_direct_public_transfer() {
    let mut sc = test_scenario::begin(@0xa);
    let root = create(sc.ctx());
    let id = object::id(&root);
    let manifest = soul::manifest_hash(&root);
    let (mut policy, cap) = transfer_policy::new_for_testing<Soul>(sc.ctx());
    transfer_policy::add_rule<Soul, Rule, u64>(Rule {}, &mut policy, &cap, 7);
    assert!(transfer_policy::rules(&policy).size() == 1, 130);
    transfer::public_share_object(policy);
    transfer::public_transfer(cap, @0xa);
    transfer::public_transfer(root, @0xb);
    sc.next_tx(@0xb);
    let root: Soul = sc.take_from_sender_by_id(id);
    assert!(object::id(&root) == id && soul::manifest_hash(&root) == manifest, 131);
    sc.return_to_sender(root);
    sc.end();
}

#[test]
fun kiosk_purchase_transfers_composite_soul_and_child_to_buyer() {
    let mut sc = test_scenario::begin(@0xa);
    let mut parent = create(sc.ctx());
    let child = create(sc.ctx());
    let parent_id = object::id(&parent);
    let child_id = object::id(&child);
    soul::nest(&mut parent, child, 0);
    let manifest = soul::manifest_hash(&parent);
    let (mut k, cap) = kiosk::new(sc.ctx());
    let kiosk_id = object::id(&k);
    kiosk::place(&mut k, &cap, parent);
    kiosk::list<Soul>(&mut k, &cap, parent_id, 5);
    transfer::public_share_object(k);
    transfer::public_transfer(cap, @0xa);
    let (policy, cap) = transfer_policy::new_for_testing<Soul>(sc.ctx());
    let policy_id = object::id(&policy);
    transfer::public_share_object(policy);
    transfer::public_transfer(cap, @0xa);
    sc.next_tx(@0xb);
    let mut k: Kiosk = sc.take_shared_by_id(kiosk_id);
    let policy: TransferPolicy<Soul> = sc.take_shared_by_id(policy_id);
    let payment = coin::mint_for_testing<SUI>(5, sc.ctx());
    let (mut parent, request) = kiosk::purchase<Soul>(&mut k, parent_id, payment);
    let (item, paid, from) = transfer_policy::confirm_request(&policy, request);
    assert!(item == parent_id && paid == 5 && from == kiosk_id, 140);
    assert!(kiosk::profits_amount(&k) == 5, 141);
    assert!(soul::manifest_hash(&parent) == manifest && soul::revision(&parent) == 1, 142);
    let child = soul::unnest(&mut parent, child_id, 1);
    assert!(object::id(&child) == child_id, 143);
    transfer::public_transfer(parent, @0xb);
    transfer::public_transfer(child, @0xb);
    test_scenario::return_shared(k);
    test_scenario::return_shared(policy);
    sc.end();
}
