/// Optional native Kiosk authority. Only Sui dependencies; no business domain.
/// The actual owner cap has no public extraction, UID borrow or callback API.
module soulidity_standard::native_authority;
use sui::kiosk::{Self,Kiosk,KioskOwnerCap};
use sui::transfer_policy::TransferPolicy;
use sui::coin::Coin;
use sui::sui::SUI;
const EOwner:u64=1;const EPair:u64=2;const EClosed:u64=15;
const ELegacy:u64=13;const ELayout:u64=14;
public struct Authority has store { cap:KioskOwnerCap,kiosk:ID,owner:address,closed_digest:vector<u8> }
public fun seal(k:&mut Kiosk,cap:KioskOwnerCap,ctx:&TxContext):Authority {
    assert!(kiosk::owner(k)==ctx.sender() && kiosk::has_access(k,&cap),EPair);
    assert_legacy_disabled(k);Authority{cap,kiosk:object::id(k),owner:ctx.sender(),closed_digest:vector[]}
}
public fun assert_pair(k:&mut Kiosk,a:&Authority,ctx:&TxContext) {
    assert!(a.owner==ctx.sender(),EOwner);
    assert!(a.kiosk==object::id(k) && kiosk::owner(k)==a.owner && kiosk::has_access(k,&a.cap),EPair)
}
fun open(k:&mut Kiosk,a:&Authority,ctx:&TxContext) {
    assert_pair(k,a,ctx);assert!(a.closed_digest!=*ctx.digest(),EClosed)
}
public fun owner(a:&Authority):address{a.owner}
public fun kiosk_id(a:&Authority):ID{a.kiosk}
public fun cap_id(a:&Authority):ID{object::id(&a.cap)}
/// Locking further closed Creation values is safe batch initialization: it
/// exposes no root/cap/UID and does not reset the transaction closure marker.
public(package) fun lock_creation<T:key+store>(k:&mut Kiosk,a:&mut Authority,p:&TransferPolicy<T>,value:T,ctx:&TxContext) {
    assert_pair(k,a,ctx);assert_legacy_disabled(k);a.closed_digest=*ctx.digest();kiosk::lock(k,&a.cap,p,value)
}
/// Only defining-package atomic construction terminals may use this reference.
/// Ordinary and exclusive listings must both be absent before fresh attachment.
/// Repeated closed terminals safely append without reopening mutable authority.
public(package) fun borrow_locked_for_creation<T:key+store>(
    k:&mut Kiosk,a:&mut Authority,id:ID,ctx:&TxContext,
):&mut T {
    assert_pair(k,a,ctx);assert_legacy_disabled(k);
    assert!(kiosk::is_locked(k,id) && !kiosk::is_listed(k,id),EPair);
    a.closed_digest=*ctx.digest();kiosk::borrow_mut<T>(k,&a.cap,id)
}
public fun lock<T:key+store>(k:&mut Kiosk,a:&Authority,p:&TransferPolicy<T>,value:T,ctx:&TxContext) {
    open(k,a,ctx);kiosk::lock(k,&a.cap,p,value)
}
public fun borrow<T:key+store>(k:&mut Kiosk,a:&Authority,id:ID,ctx:&TxContext):&T {
    assert_pair(k,a,ctx);kiosk::borrow<T>(k,&a.cap,id)
}
public fun borrow_mut<T:key+store>(k:&mut Kiosk,a:&Authority,id:ID,ctx:&TxContext):&mut T {
    open(k,a,ctx);kiosk::borrow_mut<T>(k,&a.cap,id)
}
public fun place<T:key+store>(k:&mut Kiosk,a:&Authority,value:T,ctx:&TxContext) {
    open(k,a,ctx);kiosk::place(k,&a.cap,value)
}
public fun take<T:key+store>(k:&mut Kiosk,a:&Authority,id:ID,ctx:&TxContext):T {
    open(k,a,ctx);kiosk::take<T>(k,&a.cap,id)
}
public fun list<T:key+store>(k:&mut Kiosk,a:&Authority,id:ID,price:u64,ctx:&TxContext) {
    open(k,a,ctx);kiosk::list<T>(k,&a.cap,id,price)
}
public fun list_exclusively<T:key+store>(k:&mut Kiosk,a:&Authority,id:ID,ctx:&mut TxContext):sui::kiosk::PurchaseCap<T> {
    open(k,a,ctx);kiosk::list_with_purchase_cap<T>(k,&a.cap,id,0,ctx)
}
public fun withdraw(k:&mut Kiosk,a:&Authority,amount:Option<u64>,ctx:&mut TxContext):Coin<SUI> {
    open(k,a,ctx);kiosk::withdraw(k,&a.cap,amount,ctx)
}
public fun add_extension<X:drop>(x:X,k:&mut Kiosk,a:&Authority,ctx:&mut TxContext) {
    open(k,a,ctx);sui::kiosk_extension::add(x,k,&a.cap,0,ctx)
}
public fun disable_extension<X:drop>(k:&mut Kiosk,a:&Authority,ctx:&TxContext) {
    open(k,a,ctx);sui::kiosk_extension::disable<X>(k,&a.cap)
}
public fun enable_extension<X:drop>(k:&mut Kiosk,a:&Authority,ctx:&TxContext) {
    open(k,a,ctx);sui::kiosk_extension::enable<X>(k,&a.cap)
}
public fun remove_extension<X:drop>(k:&mut Kiosk,a:&Authority,ctx:&TxContext) {
    open(k,a,ctx);sui::kiosk_extension::remove<X>(k,&a.cap)
}
public fun assert_legacy_disabled(k:&Kiosk) {
    let bytes=std::bcs::to_bytes(k);assert!(bytes.length()==77,ELayout);
    let mut b=sui::bcs::new(bytes);let uid=b.peel_address();let profits=b.peel_u64();
    let owner=b.peel_address();let count=b.peel_u32();let flag=b.peel_u8();
    assert!(flag<=1 && b.into_remainder_bytes().is_empty(),ELayout);
    assert!(uid==object::id(k).to_address() && profits==kiosk::profits_amount(k) && owner==kiosk::owner(k) && count==kiosk::item_count(k),ELayout);
    assert!(flag==0,ELegacy)
}
#[test_only]
public fun has_access_for_testing(k:&mut Kiosk,a:&Authority):bool{kiosk::has_access(k,&a.cap)}
