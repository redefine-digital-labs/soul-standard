#[test_only]
module soulidity_standard::creation_boundary_tests;
use soulidity_standard::soul::{Self,Soul,Creation,Origin};
use soulidity_standard::native_authority::{Self as sealed,Authority};
use sui::test_scenario::{Self,Scenario};
use sui::kiosk::{Self,Kiosk};
use sui::transfer_policy::{Self,TransferPolicy};
public struct SoulProducer has drop {}
public struct Source has key,store {id:UID}
public struct Witness has drop {}
public struct State has key,store {id:UID,root:ID,value:u64}
public struct Wallet has key {id:UID,authority:Authority}
fun source(ctx:&mut TxContext):Source{Source{id:object::new(ctx)}}
fun fresh(p:&Source,ctx:&mut TxContext):Creation{soul::new(SoulProducer{},p,1,vector::tabulate!(32,|_|7),b"Creation".to_string(),ctx)}
fun state(c:&Creation,ctx:&mut TxContext):State{State{id:object::new(ctx),root:soul::creation_id(c),value:0}}
fun install(c:&mut Creation,ctx:&mut TxContext){let v=state(c,ctx);soul::creation_install(c,Witness{},b"state",v,1,true,vector::tabulate!(32,|_|1),0)}
fun policy(sc:&mut Scenario):TransferPolicy<Soul>{let(p,cap)=transfer_policy::new_for_testing<Soul>(sc.ctx());transfer::public_transfer(cap,@0xa);p}
#[test]
fun public_creation_initial_edit_and_sender_terminal_preserve_identity(){
 let mut sc=test_scenario::begin(@0xa);let p=source(sc.ctx());let mut c=fresh(&p,sc.ctx());let id=soul::creation_id(&c);let origin=soul::origin(soul::creation_ref(&c));install(&mut c,sc.ctx());
 let(mut v,t)=soul::creation_begin_update<Witness,State>(&mut c,Witness{},b"state",1);let child=object::id(&v);v.value=9;soul::creation_commit_update(&mut c,t,Witness{},v,1,vector::tabulate!(32,|_|2));
 assert!(soul::revision(soul::creation_ref(&c))==2,0);soul::creation_deliver_sender(c,sc.ctx());transfer::public_transfer(p,@0xa);
 sc.next_tx(@0xa);let s:Soul=sc.take_from_sender_by_id(id);let v=soul::borrow_module<Witness,State>(&s,b"state");assert!(object::id(v)==child && v.value==9 && soul::origin(&s)==origin,1);transfer::public_transfer(s,@0xb);
 sc.next_tx(@0xb);let s:Soul=sc.take_from_sender_by_id(id);assert!(soul::origin(&s)==origin,2);sc.return_to_sender(s);sc.end();
}
#[test,expected_failure(abort_code=9,location=soulidity_standard::soul)]
fun initial_edit_cannot_substitute_same_type_different_child(){
 let mut sc=test_scenario::begin(@0xa);let p=source(sc.ctx());let mut c=fresh(&p,sc.ctx());install(&mut c,sc.ctx());let(v,t)=soul::creation_begin_update<Witness,State>(&mut c,Witness{},b"state",1);let other=state(&c,sc.ctx());soul::creation_commit_update(&mut c,t,Witness{},other,1,vector::tabulate!(32,|_|2));transfer::public_transfer(v,@0xa);soul::creation_deliver_sender(c,sc.ctx());transfer::public_transfer(p,@0xa);sc.end();
}
#[test,expected_failure(abort_code=3,location=soulidity_standard::soul)]
fun initial_generic_edit_cannot_extract_nested_soul_with_metadata_witness(){
 let mut sc=test_scenario::begin(@0xa);let p=source(sc.ctx());let mut c=fresh(&p,sc.ctx());let child=fresh(&p,sc.ctx());let ci=soul::creation_id(&child);soul::creation_nest(&mut c,child,0);let origin=soul::origin(soul::creation_ref(&c));
 let(v,t)=soul::creation_begin_update<Origin,Soul>(&mut c,origin,std::bcs::to_bytes(&ci),1);soul::creation_commit_update(&mut c,t,origin,v,1,vector::tabulate!(32,|_|2));soul::creation_deliver_sender(c,sc.ctx());transfer::public_transfer(p,@0xa);sc.end();
}
#[test,expected_failure(abort_code=3,location=soulidity_standard::soul)]
fun fresh_address_terminal_cannot_target_unknown_object_receiver(){
 let mut sc=test_scenario::begin(@0xa);let p=source(sc.ctx());let c=fresh(&p,sc.ctx());soul::creation_deliver(c,object::id(&p).to_address());transfer::public_transfer(p,@0xa);sc.end();
}
fun nested_existing(sc:&mut Scenario):(ID,ID){
 let p=source(sc.ctx());let mut parent=fresh(&p,sc.ctx());let child=fresh(&p,sc.ctx());let pi=soul::creation_id(&parent);let ci=soul::creation_id(&child);soul::creation_nest(&mut parent,child,0);soul::creation_deliver_sender(parent,sc.ctx());transfer::public_transfer(p,@0xa);sc.next_tx(@0xa);(pi,ci)
}
#[test]
fun existing_parent_and_child_promote_new_grandchild_through_exact_scope(){
 let mut sc=test_scenario::begin(@0xa);let(pi,ci)=nested_existing(&mut sc);let owned:Soul=sc.take_from_sender_by_id(pi);let p:Source=sc.take_from_sender();let mut parent=soul::hold_owned(owned);let(mut child,t)=soul::creation_begin_nested_update(&mut parent,ci,1);let grand=fresh(&p,sc.ctx());let gi=soul::creation_id(&grand);let origin=soul::origin(soul::creation_ref(&grand));soul::creation_nest(&mut child,grand,0);soul::creation_commit_nested_update(&mut parent,t,child);soul::creation_deliver_sender(parent,sc.ctx());sc.return_to_sender(p);
 sc.next_tx(@0xa);let owned:Soul=sc.take_from_sender_by_id(pi);assert!(object::id(soul::nested(soul::nested(&owned,ci),gi))==gi && soul::origin(soul::nested(soul::nested(&owned,ci),gi))==origin,0);sc.return_to_sender(owned);sc.end();
}
#[test,expected_failure(abort_code=3,location=soulidity_standard::soul)]
fun grandchild_freshness_cannot_downgrade_when_committed_to_owned_parent(){
 let mut sc=test_scenario::begin(@0xa);let(pi,ci)=nested_existing(&mut sc);let owned:Soul=sc.take_from_sender_by_id(pi);let p:Source=sc.take_from_sender();let mut parent=soul::hold_owned(owned);let(mut child,t)=soul::creation_begin_nested_update(&mut parent,ci,1);let grand=fresh(&p,sc.ctx());soul::creation_nest(&mut child,grand,0);soul::creation_commit_nested_update(&mut parent,t,child);soul::creation_deliver(parent,@0xb);sc.return_to_sender(p);sc.end();
}
fun lock(sc:&mut Scenario):(Kiosk,Wallet,ID,TransferPolicy<Soul>){
 let(mut k,cap)=kiosk::new(sc.ctx());let authority=sealed::seal(&mut k,cap,sc.ctx());let mut wallet=Wallet{id:object::new(sc.ctx()),authority};let p=source(sc.ctx());let mut c=fresh(&p,sc.ctx());let child=fresh(&p,sc.ctx());soul::creation_nest(&mut c,child,0);let id=soul::creation_id(&c);let policy=policy(sc);soul::creation_lock(c,&mut k,&mut wallet.authority,&policy,sc.ctx());transfer::public_transfer(p,@0xa);(k,wallet,id,policy)
}
#[test,expected_failure(abort_code=15,location=soulidity_standard::native_authority)]
fun cap_scope_blocks_same_transaction_mutable_nested_root(){
 let mut sc=test_scenario::begin(@0xa);let(mut k,w,id,policy)=lock(&mut sc);let root=sealed::borrow_mut<Soul>(&mut k,&w.authority,id,sc.ctx());let _=soul::revision(root);transfer::public_share_object(k);transfer::transfer(w,@0xa);transfer::public_share_object(policy);sc.end();
}
#[test,expected_failure(abort_code=15,location=soulidity_standard::native_authority)]
fun cap_scope_blocks_same_transaction_listing(){
 let mut sc=test_scenario::begin(@0xa);let(mut k,w,id,policy)=lock(&mut sc);sealed::list<Soul>(&mut k,&w.authority,id,0,sc.ctx());transfer::public_share_object(k);transfer::transfer(w,@0xa);transfer::public_share_object(policy);sc.end();
}
#[test,expected_failure(abort_code=15,location=soulidity_standard::native_authority)]
fun cap_scope_blocks_same_transaction_take(){
 let mut sc=test_scenario::begin(@0xa);let(mut k,w,id,policy)=lock(&mut sc);let s=sealed::take<Soul>(&mut k,&w.authority,id,sc.ctx());transfer::public_transfer(s,@0xa);transfer::public_share_object(k);transfer::transfer(w,@0xa);transfer::public_share_object(policy);sc.end();
}
#[test]
fun cap_scope_keeps_safe_batch_locks_read_and_next_transaction_mutation(){
 let mut sc=test_scenario::begin(@0xa);let(mut k,mut w,id,policy)=lock(&mut sc);let p=source(sc.ctx());let c=fresh(&p,sc.ctx());let second=soul::creation_id(&c);soul::creation_lock(c,&mut k,&mut w.authority,&policy,sc.ctx());let ki=object::id(&k);let wi=object::id(&w);let cap=sealed::cap_id(&w.authority);assert!(object::id(sealed::borrow<Soul>(&mut k,&w.authority,id,sc.ctx()))==id && kiosk::is_locked(&k,second),0);transfer::public_share_object(k);transfer::transfer(w,@0xa);transfer::public_share_object(policy);transfer::public_transfer(p,@0xa);
 sc.next_tx(@0xa);let mut k:Kiosk=sc.take_shared_by_id(ki);let w:Wallet=sc.take_from_sender_by_id(wi);let root=sealed::borrow_mut<Soul>(&mut k,&w.authority,id,sc.ctx());assert!(soul::revision(root)==1 && sealed::cap_id(&w.authority)==cap,1);test_scenario::return_shared(k);sc.return_to_sender(w);sc.end();
}
#[test,expected_failure(abort_code=9,location=soulidity_standard::soul)]
fun nested_linear_edit_cannot_substitute_fresh_child_identity(){
 let mut sc=test_scenario::begin(@0xa);let p=source(sc.ctx());let mut parent=fresh(&p,sc.ctx());let child=fresh(&p,sc.ctx());let ci=soul::creation_id(&child);soul::creation_nest(&mut parent,child,0);let(child,t)=soul::creation_begin_nested_update(&mut parent,ci,1);let other=fresh(&p,sc.ctx());soul::creation_commit_nested_update(&mut parent,t,other);soul::creation_deliver_sender(child,sc.ctx());soul::creation_deliver_sender(parent,sc.ctx());transfer::public_transfer(p,@0xa);sc.end();
}
#[test,expected_failure(abort_code=3,location=soulidity_standard::soul)]
fun fresh_nested_child_cannot_change_creation_actor(){
 let mut sc=test_scenario::begin(@0xa);let p=source(sc.ctx());let mut parent=fresh(&p,sc.ctx());let mut child_ctx=sui::tx_context::new_from_hint(@0xb,123,0,0,0);let child=soul::new(SoulProducer{},&p,1,vector::tabulate!(32,|_|7),b"Creation".to_string(),&mut child_ctx);soul::creation_nest(&mut parent,child,0);soul::creation_deliver_sender(parent,sc.ctx());transfer::public_transfer(p,@0xa);sc.end();
}
#[test,expected_failure(abort_code=1,location=soulidity_standard::native_authority)]
fun authority_refuses_wrong_actual_scenario_transaction_sender(){
 let mut sc=test_scenario::begin(@0xa);let(k,w,id,policy)=lock(&mut sc);let ki=object::id(&k);let wi=object::id(&w);transfer::public_share_object(k);transfer::transfer(w,@0xa);transfer::public_share_object(policy);
 sc.next_tx(@0xb);let mut k:Kiosk=sc.take_shared_by_id(ki);let w:Wallet=test_scenario::take_from_address_by_id(&sc,@0xa,wi);let root=sealed::borrow_mut<Soul>(&mut k,&w.authority,id,sc.ctx());let _=soul::revision(root);test_scenario::return_shared(k);test_scenario::return_to_address(@0xa,w);sc.end();
}
