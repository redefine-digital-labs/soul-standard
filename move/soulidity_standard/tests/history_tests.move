#[test_only]
module soulidity_standard::history_tests;
use std::string;
use sui::test_scenario::{Self, Scenario};
use soulidity_standard::soul::{Self, Soul, ModuleVersion};
public struct SoulProducer has drop {}
public struct Witness has drop {}
public struct PassiveWitness has drop {}
public struct Source has key, store { id: UID }
public struct Value has key, store { id: UID, score: u64 }
fun h():vector<u8>{vector::tabulate!(32,|_|9)}
fun create(ctx:&mut TxContext):Soul{
 let p=Source{id:object::new(ctx)};
 let s=soul::creation_raw_for_testing(soul::new(SoulProducer{},&p,1,h(),string::utf8(b"history"),ctx));
 transfer::public_transfer(p,ctx.sender());s
}
fun install(s:&mut Soul,ctx:&mut TxContext){let r=soul::revision(s);soul::install(s,Witness{},b"protected",Value{id:object::new(ctx),score:1},1,false,h(),r)}
fun version(s:&Soul):ModuleVersion{let d=soul::descriptor<Witness>(s,b"protected").destroy_some();soul::module_version(s,&d).destroy_some()}
fun edit(s:&mut Soul,score:u64){let r=soul::revision(s);let(mut v,t)=soul::begin_update<Witness,Value>(s,Witness{},b"protected",r);v.score=score;soul::commit_update(s,t,Witness{},v,1,h())}
fun finish(s:Soul,mut sc:Scenario){transfer::public_transfer(s,sc.ctx().sender());sc.end();}

#[test]
fun reverted_bytes_still_advance_module_history(){
 let mut sc=test_scenario::begin(@0xa);let mut s=create(sc.ctx());install(&mut s,sc.ctx());
 let d=soul::descriptor<Witness>(&s,b"protected").destroy_some();let before=version(&s);
 edit(&mut s,9);edit(&mut s,1);
 let after=version(&s);let current=soul::descriptor<Witness>(&s,b"protected").destroy_some();
 assert!(d==current,100);assert!(soul::installed_revision(&before)==soul::installed_revision(&after),101);
 assert!(soul::updated_revision(&after)==soul::updated_revision(&before)+2,102);finish(s,sc)
}
#[test]
fun passive_edit_keeps_protected_history_and_topology_unchanged(){
 let mut sc=test_scenario::begin(@0xa);let mut s=create(sc.ctx());install(&mut s,sc.ctx());let before=version(&s);
 let r=soul::revision(&s);soul::install(&mut s,PassiveWitness{},b"passive",Value{id:object::new(sc.ctx()),score:0},1,true,h(),r);
 let topology=soul::nesting_revision(&s);let r=soul::revision(&s);
 let(mut v,t)=soul::begin_update<PassiveWitness,Value>(&mut s,PassiveWitness{},b"passive",r);v.score=1;soul::commit_update(&mut s,t,PassiveWitness{},v,1,h());
 assert!(version(&s)==before && soul::nesting_revision(&s)==topology,103);assert!(soul::module_count(&s)==2,104);finish(s,sc)
}
#[test]
fun same_child_id_reinsertion_has_new_install_and_topology_versions(){
 let mut sc=test_scenario::begin(@0xa);let mut s=create(sc.ctx());let child=create(sc.ctx());let id=object::id(&child);
 let r=soul::revision(&s);soul::nest(&mut s,child,r);let before=soul::nesting_revision(&s).destroy_some();
 let d=soul::descriptor<soul::NestedSoulWitness>(&s,std::bcs::to_bytes(&id)).destroy_some();let old=soul::module_version(&s,&d).destroy_some();
 let r=soul::revision(&s);let child=soul::unnest(&mut s,id,r);let r=soul::revision(&s);soul::nest(&mut s,child,r);
 let current=soul::descriptor<soul::NestedSoulWitness>(&s,std::bcs::to_bytes(&id)).destroy_some();let new=soul::module_version(&s,&current).destroy_some();
 assert!(d==current && object::id(soul::nested(&s,id))==id,105);assert!(soul::nesting_revision(&s).destroy_some()==before+2,106);
 assert!(soul::installed_revision(&new)>soul::installed_revision(&old) && soul::module_count(&s)==1,107);finish(s,sc)
}
#[test]
fun editing_child_does_not_change_parent_native_topology(){
 let mut sc=test_scenario::begin(@0xa);let mut s=create(sc.ctx());let mut child=create(sc.ctx());install(&mut child,sc.ctx());let id=object::id(&child);
 let r=soul::revision(&s);soul::nest(&mut s,child,r);let topology=soul::nesting_revision(&s);let r=soul::revision(&s);
 let(mut child,t)=soul::begin_nested_update(&mut s,id,r);edit(&mut child,2);soul::commit_nested_update(&mut s,t,child);
 assert!(soul::nesting_revision(&s)==topology && soul::borrow_module<Witness,Value>(soul::nested(&s,id),b"protected").score==2,108);finish(s,sc)
}
#[test]
fun recorded_versions_persist_across_transactions_with_original_module_count(){
 let mut sc=test_scenario::begin(@0xa);let mut s=create(sc.ctx());install(&mut s,sc.ctx());let id=object::id(&s);let before=version(&s);transfer::public_transfer(s,@0xa);
 sc.next_tx(@0xa);let mut s:Soul=sc.take_from_sender_by_id(id);assert!(version(&s)==before && soul::module_count(&s)==1,109);edit(&mut s,2);let after=version(&s);sc.return_to_sender(s);
 sc.next_tx(@0xa);let s:Soul=sc.take_from_sender_by_id(id);assert!(version(&s)==after && soul::module_count(&s)==1,110);sc.return_to_sender(s);sc.end();
}
#[test]
fun missing_historical_metadata_is_explicit_and_not_fabricated(){
 let mut sc=test_scenario::begin(@0xa);let mut s=create(sc.ctx());install(&mut s,sc.ctx());
 soul::remove_version_for_testing<Witness>(&mut s,b"protected");let d=soul::descriptor<Witness>(&s,b"protected").destroy_some();assert!(soul::module_version(&s,&d).is_none(),111);
 soul::remove_nesting_version_for_testing(&mut s);assert!(soul::nesting_revision(&s).is_none(),112);
 edit(&mut s,2);let v=version(&s);assert!(soul::installed_revision(&v)==0 && soul::updated_revision(&v)==soul::revision(&s),113);finish(s,sc)
}
#[test,expected_failure(abort_code=9,location=soulidity_standard::soul)]
fun descriptor_from_another_root_cannot_substitute_history(){
 let mut sc=test_scenario::begin(@0xa);let mut a=create(sc.ctx());let b=create(sc.ctx());install(&mut a,sc.ctx());let d=soul::descriptor<Witness>(&a,b"protected").destroy_some();let _=soul::module_version(&b,&d);transfer::public_transfer(a,@0xa);finish(b,sc)
}
#[test,expected_failure(abort_code=2,location=soulidity_standard::soul)]
fun in_progress_edit_cannot_claim_a_completed_history(){
 let mut sc=test_scenario::begin(@0xa);let mut s=create(sc.ctx());install(&mut s,sc.ctx());let d=soul::descriptor<Witness>(&s,b"protected").destroy_some();let r=soul::revision(&s);
 let(v,t)=soul::begin_update<Witness,Value>(&mut s,Witness{},b"protected",r);let _=soul::module_version(&s,&d);soul::commit_update(&mut s,t,Witness{},v,1,h());finish(s,sc)
}

#[test]
fun source_annotations_distinguish_permanent_roles_without_extra_module_or_revision(){
 let mut sc=test_scenario::begin(@0xa);let mut a=create(sc.ctx());let mut b=create(sc.ctx());install(&mut a,sc.ctx());
 soul::install_annotated(&mut b,Witness{},b"protected",Value{id:object::new(sc.ctx()),score:1},1,false,h(),0,b"provider-defined-duty-v1");
 let ad=soul::descriptor<Witness>(&a,b"protected").destroy_some();let bd=soul::descriptor<Witness>(&b,b"protected").destroy_some();
 assert!(!soul::removable(&ad) && !soul::removable(&bd),114);assert!(soul::module_annotation(&a,&ad).is_none() && soul::module_annotation(&b,&bd)==option::some(b"provider-defined-duty-v1"),115);
 assert!(soul::module_count(&a)==1 && soul::module_count(&b)==1 && soul::revision(&a)==1 && soul::revision(&b)==1,116);transfer::public_transfer(a,@0xa);finish(b,sc)
}
#[test]
fun ordinary_edit_cannot_erase_immutable_source_annotation(){
 let mut sc=test_scenario::begin(@0xa);let mut s=create(sc.ctx());
 soul::install_annotated(&mut s,Witness{},b"protected",Value{id:object::new(sc.ctx()),score:1},1,false,h(),0,b"opaque-producer-bytes");
 edit(&mut s,9);edit(&mut s,1);let d=soul::descriptor<Witness>(&s,b"protected").destroy_some();
 assert!(soul::module_annotation(&s,&d)==option::some(b"opaque-producer-bytes") && soul::module_count(&s)==1,117);finish(s,sc)
}
#[test]
fun removable_reinstall_does_not_inherit_annotation_or_old_version(){
 let mut sc=test_scenario::begin(@0xa);let mut s=create(sc.ctx());
 soul::install_annotated(&mut s,Witness{},b"protected",Value{id:object::new(sc.ctx()),score:1},1,true,h(),0,vector[]);
 let d=soul::descriptor<Witness>(&s,b"protected").destroy_some();let before=soul::module_version(&s,&d).destroy_some();assert!(soul::module_annotation(&s,&d)==option::some(vector[]),118);
 let v=soul::uninstall<Witness,Value>(&mut s,b"protected",1);soul::install(&mut s,Witness{},b"protected",v,1,true,h(),2);
 let d=soul::descriptor<Witness>(&s,b"protected").destroy_some();let after=soul::module_version(&s,&d).destroy_some();
 assert!(soul::module_annotation(&s,&d).is_none() && soul::installed_revision(&after)>soul::installed_revision(&before),119);finish(s,sc)
}
#[test,expected_failure(abort_code=3,location=soulidity_standard::soul)]
fun declaration_cannot_authorize_another_producer_value(){
 let mut sc=test_scenario::begin(@0xa);let mut s=create(sc.ctx());
 soul::install_annotated(&mut s,Witness{},b"foreign",soulidity_standard::foreign::new(sc.ctx()),1,true,h(),0,b"opaque");finish(s,sc)
}
