/// Application-independent asset root. No mutable UID or mutable-child escape.
module soulidity_standard::soul;

use std::bcs;
use std::hash;
use std::string::String;
use std::type_name::{Self, TypeName};
use sui::dynamic_object_field as dof;
use sui::dynamic_field as df;
use sui::event;

const ERevision: u64 = 1;
const EEditing: u64 = 2;
const EAuthority: u64 = 3;
const EType: u64 = 4;
const EInput: u64 = 5;
const EDuplicate: u64 = 6;
const ECapacity: u64 = 7;
const EPermanent: u64 = 8;
const EIdentity: u64 = 9;
const ESchema: u64 = 10;
const MAX_MODULES: u64 = 64;
const MAX_CHILD_BYTES: u64 = 245760;

/// Package ownership proof for standard Sui integrations such as a real
/// TransferPolicy<Soul>. The kernel does not install rules or depend on a market.
public struct SOUL has drop {}
fun init(w: SOUL, ctx: &mut TxContext) { sui::package::claim_and_keep(w, ctx) }
#[test_only]
public fun init_for_testing(ctx: &mut TxContext) { init(SOUL {}, ctx) }

public struct Soul has key, store {
    id: UID,
    schema: u16,
    name: String,
    revision: u64,
    origin: Origin,
    modules: vector<Descriptor>,
    editing: bool,
}

/// Source identity is an actual object input. Version/hash are its module's
/// attestation, not a kernel interpretation of a Maker or a storage service.
public struct Origin has copy, drop, store {
    producer: TypeName,
    source_type: TypeName,
    source: ID,
    source_version: u64,
    source_hash: vector<u8>,
    minted_by: address,
}

public struct Descriptor has copy, drop, store {
    namespace: TypeName,
    name: vector<u8>,
    value_type: TypeName,
    object: ID,
    schema: u16,
    removable: bool,
    body_hash: vector<u8>,
    semantic_hash: vector<u8>,
}

/// Private constructor and typed DOF keys isolate every application namespace.
public struct ModuleKey<phantom W> has copy, drop, store { name: vector<u8> }

/// Canonical native nesting namespace. A nested Soul remains a distinct asset,
/// never a new form of its parent. Constructor stays inside this module.
public struct NestedSoulWitness has drop {}

/// Neutral history lives outside existing root and descriptor layouts. These
/// private keys cannot be forged by a producer or another application.
public struct ModuleVersionKey has copy, drop, store { namespace: TypeName, name: vector<u8> }
public struct ModuleVersion has copy, drop, store { installed: u64, updated: u64 }
public struct NestingVersionKey has copy, drop, store {}
/// Optional immutable source-owned bytes. The kernel assigns no business
/// meaning: consumers must agree on an annotation format and its obligations.
public struct ModuleAnnotationKey has copy, drop, store { namespace: TypeName, name: vector<u8> }



/// No abilities: successful transactions must restore this exact child into
/// this exact Soul. Permanent modules can be edited but cannot be withdrawn.
public struct Edit<phantom W, phantom T> {
    soul: ID,
    object: ID,
    name: vector<u8>,
    revision: u64,
}

public struct Changed has copy, drop {
    soul: ID, revision: u64, operation: u8,
    namespace: TypeName, name: vector<u8>, object: ID,
}

public struct Manifest has copy, drop, store {
    domain: vector<u8>, soul: ID, schema: u16, name: String,
    revision: u64, origin: Origin, modules: vector<Descriptor>,
}

fun same_module<W, T>() {
    let w = type_name::with_original_ids<W>();
    let t = type_name::with_original_ids<T>();
    assert!(!w.is_primitive() && !t.is_primitive(), EAuthority);
    assert!(w.address_string() == t.address_string()
        && w.module_string() == t.module_string(), EAuthority);
}

fun hash32(value: &vector<u8>) { assert!(value.length() == 32, EInput) }
fun check_name(value: &vector<u8>) {
    assert!(value.length() > 0 && value.length() <= 64, EInput)
}
fun ready(s: &Soul) { assert!(s.schema == 1 && !s.editing, EEditing) }
fun cas(s: &Soul, expected: u64) { assert!(s.revision == expected, ERevision) }
// Root contents use Sui's execution-level Move object size bound. Imposing a
// smaller name/root ceiling here changes the original native metadata domain.
fun child_hash<T>(value: &T): vector<u8> {
    let bytes = bcs::to_bytes(value);
    assert!(bytes.length() <= MAX_CHILD_BYTES, ECapacity);
    hash::sha3_256(bytes)
}

public fun new<W: drop, P: key>(
    witness: W, source: &P, source_version: u64,
    source_hash: vector<u8>, name: String, ctx: &mut TxContext,
): Creation {
    same_module<W, P>(); let _ = witness;
    // Same-module public metadata values also have drop. Only the producer's
    // designated marker may attest issuance; its constructor must remain private.
    assert!(*type_name::with_original_ids<W>().datatype_string().as_bytes()==b"SoulProducer",EAuthority);
    hash32(&source_hash);
    assert!(source_version > 0, EInput);
    let mut s = Soul {
        id: object::new(ctx), schema: 1, name, revision: 0, modules: vector[], editing: false,
        origin: Origin {
            producer: type_name::with_defining_ids<W>(),
            source_type: type_name::with_defining_ids<P>(), source: object::id(source),
            source_version, source_hash, minted_by: ctx.sender(),
        },
    };
    df::add(&mut s.id, NestingVersionKey {}, 0u64);
    Creation { root:s, actor:ctx.sender(), fresh:true }
}

fun find<W>(s: &Soul, name: &vector<u8>): Option<u64> {
    let namespace = type_name::with_defining_ids<W>();
    let mut i = 0;
    while (i < s.modules.length()) {
        if (s.modules[i].namespace == namespace && s.modules[i].name == *name)
            return option::some(i);
        i = i + 1
    };
    option::none()
}

fun index<W, T>(s: &Soul, name: &vector<u8>): u64 {
    let found = find<W>(s, name);
    assert!(found.is_some(), EType);
    let i = found.destroy_some();
    assert!(s.modules[i].value_type == type_name::with_defining_ids<T>(), EType);
    i
}

fun version_key(d: &Descriptor): ModuleVersionKey {
    ModuleVersionKey { namespace: d.namespace, name: d.name }
}
fun installed(s: &mut Soul, d: &Descriptor) {
    let next = s.revision + 1;
    df::add(&mut s.id, version_key(d), ModuleVersion { installed: next, updated: next })
}
fun updated(s: &mut Soul, d: &Descriptor) {
    let key = version_key(d);
    let next = s.revision + 1;
    if (df::exists<ModuleVersionKey>(&s.id, key)) {
        let v: &mut ModuleVersion = df::borrow_mut(&mut s.id, key);
        v.updated = next
    } else {
        // An older root lacks a proved installed version. Keep zero explicit;
        // consumers requiring exact installation history must reject it.
        df::add(&mut s.id, key, ModuleVersion { installed: 0, updated: next })
    }
}
fun annotation_key(d: &Descriptor): ModuleAnnotationKey {
    ModuleAnnotationKey { namespace: d.namespace, name: d.name }
}
fun annotated(s: &mut Soul, d: &Descriptor, bytes: Option<vector<u8>>) {
    if (bytes.is_some()) {
        let data = bytes.destroy_some();
        assert!(data.length() <= MAX_CHILD_BYTES, ECapacity);
        df::add(&mut s.id, annotation_key(d), data)
    }
}
fun removed(s: &mut Soul, d: &Descriptor) {
    let a = annotation_key(d);
    if (df::exists<ModuleAnnotationKey>(&s.id, a)) {
        let _: vector<u8> = df::remove(&mut s.id, a);
    };
    let key = version_key(d);
    if (df::exists<ModuleVersionKey>(&s.id, key)) {
        let _: ModuleVersion = df::remove(&mut s.id, key);
    }
}
fun topology_changed(s: &mut Soul, d: &Descriptor) {
    if (d.namespace == type_name::with_defining_ids<NestedSoulWitness>()) {
        let key = NestingVersionKey {};
        let next = s.revision + 1;
        if (df::exists<NestingVersionKey>(&s.id, key)) {
            *df::borrow_mut<NestingVersionKey, u64>(&mut s.id, key) = next
        } else { df::add(&mut s.id, key, next) }
    }
}

/// None means history was not recorded by this kernel. A getter never invents
/// a successful zero version for an unknown legacy module or nesting tree.
public fun module_version(s: &Soul, d: &Descriptor): Option<ModuleVersion> {
    ready(s);
    assert!(s.modules.any!(|current| *current == *d), EIdentity);
    let key = version_key(d);
    if (df::exists<ModuleVersionKey>(&s.id, key)) option::some(*df::borrow(&s.id, key))
    else option::none()
}
/// Absent and empty annotations are distinct. Bytes are immutable for this
/// installation and cannot be changed through ordinary module edits.
public fun module_annotation(s: &Soul, d: &Descriptor): Option<vector<u8>> {
    ready(s); assert!(s.modules.any!(|current| *current == *d), EIdentity);
    let key = annotation_key(d);
    if (df::exists<ModuleAnnotationKey>(&s.id, key)) option::some(*df::borrow(&s.id, key))
    else option::none()
}
public fun installed_revision(v: &ModuleVersion): u64 { v.installed }
public fun updated_revision(v: &ModuleVersion): u64 { v.updated }
public fun nesting_revision(s: &Soul): Option<u64> {
    ready(s); let key = NestingVersionKey {};
    if (df::exists<NestingVersionKey>(&s.id, key)) option::some(*df::borrow(&s.id, key))
    else option::none()
}

fun changed(s: &mut Soul, operation: u8, d: &Descriptor) {
    s.revision = s.revision + 1;
    event::emit(Changed {
        soul: object::id(s), revision: s.revision, operation,
        namespace: d.namespace, name: d.name, object: d.object,
    })
}

public fun install<W: drop, T: key + store>(
    s: &mut Soul, witness: W, name: vector<u8>, value: T,
    schema: u16, removable: bool, semantic_hash: vector<u8>, expected: u64,
) {
    install_declared(s, witness, name, value, schema, removable, semantic_hash, expected, option::none())
}

/// Source-owned generic declaration, atomically bound to the actual module
/// installation. It adds no module and uses the same single CAS revision step.
public fun install_annotated<W: drop, T: key + store>(
    s: &mut Soul, witness: W, name: vector<u8>, value: T,
    schema: u16, removable: bool, semantic_hash: vector<u8>, expected: u64,
    annotation: vector<u8>,
) {
    install_declared(s, witness, name, value, schema, removable, semantic_hash, expected, option::some(annotation))
}

fun install_declared<W: drop, T: key + store>(
    s: &mut Soul, witness: W, name: vector<u8>, value: T,
    schema: u16, removable: bool, semantic_hash: vector<u8>, expected: u64,
    annotation: Option<vector<u8>>,
) {
    ready(s); cas(s, expected); same_module<W, T>(); let _ = witness;
    check_name(&name); hash32(&semantic_hash); assert!(schema > 0, ESchema);
    assert!(find<W>(s, &name).is_none(), EDuplicate);
    assert!(s.modules.length() < MAX_MODULES, ECapacity);
    let d = Descriptor {
        namespace: type_name::with_defining_ids<W>(), name,
        value_type: type_name::with_defining_ids<T>(), object: object::id(&value),
        schema, removable, body_hash: child_hash(&value), semantic_hash,
    };
    dof::add(&mut s.id, ModuleKey<W> { name }, value);
    installed(s, &d); annotated(s, &d, annotation); topology_changed(s, &d);
    s.modules.push_back(d); changed(s, 0, &d)
}

public fun borrow_module<W, T: key + store>(s: &Soul, name: vector<u8>): &T {
    ready(s); let _ = index<W, T>(s, &name);
    dof::borrow(&s.id, ModuleKey<W> { name })
}

public fun uninstall<W, T: key + store>(s: &mut Soul, name: vector<u8>, expected: u64): T {
    ready(s); cas(s, expected);
    let i = index<W, T>(s, &name); let d = s.modules[i];
    assert!(d.removable, EPermanent);
    let value = dof::remove<ModuleKey<W>, T>(&mut s.id, ModuleKey<W> { name });
    assert!(object::id(&value) == d.object, EIdentity);
    removed(s, &d); topology_changed(s, &d);
    s.modules.remove(i); changed(s, 1, &d); value
}

public fun begin_update<W: drop, T: key + store>(
    s: &mut Soul, witness: W, name: vector<u8>, expected: u64,
): (T, Edit<W, T>) {
    ready(s); cas(s, expected); same_module<W, T>(); let _ = witness;
    let i = index<W, T>(s, &name); let id = s.modules[i].object;
    let value = dof::remove<ModuleKey<W>, T>(&mut s.id, ModuleKey<W> { name });
    assert!(object::id(&value) == id, EIdentity);
    s.editing = true;
    (value, Edit { soul: object::id(s), object: id, name, revision: expected })
}

public fun commit_update<W: drop, T: key + store>(
    s: &mut Soul, ticket: Edit<W, T>, witness: W, value: T,
    schema: u16, semantic_hash: vector<u8>,
) {
    same_module<W, T>(); let _ = witness; hash32(&semantic_hash);
    let Edit { soul, object: id, name, revision } = ticket;
    assert!(s.editing && soul == object::id(s) && id == object::id(&value), EIdentity);
    cas(s, revision);
    let i = index<W, T>(s, &name);
    let mut d = s.modules[i];
    assert!(d.object == id, EIdentity); assert!(schema >= d.schema, ESchema);
    d.schema = schema; d.body_hash = child_hash(&value); d.semantic_hash = semantic_hash;
    dof::add(&mut s.id, ModuleKey<W> { name }, value);
    updated(s, &d);
    *s.modules.borrow_mut(i) = d; s.editing = false; changed(s, 2, &d)
}

public fun revision(s: &Soul): u64 { s.revision }
public fun schema(s: &Soul): u16 { s.schema }
public fun name(s: &Soul): &String { &s.name }
public fun origin(s: &Soul): Origin { s.origin }
public fun source(o: &Origin): ID { o.source }
public fun source_type(o: &Origin): TypeName { o.source_type }
public fun producer(o: &Origin): TypeName { o.producer }
public fun source_version(o: &Origin): u64 { o.source_version }
public fun source_hash(o: &Origin): vector<u8> { o.source_hash }
public fun minted_by(o: &Origin): address { o.minted_by }
public fun module_count(s: &Soul): u64 { ready(s); s.modules.length() }
public fun descriptor<W>(s: &Soul, name: vector<u8>): Option<Descriptor> {
    ready(s); find<W>(s, &name).map!(|i| s.modules[i])
}
public fun module_page(s: &Soul, offset: u64, limit: u64): vector<Descriptor> {
    ready(s); assert!(limit <= MAX_MODULES && offset <= s.modules.length(), EInput);
    let end = if (limit < s.modules.length() - offset) offset + limit else s.modules.length();
    let mut result = vector[]; let mut i = offset;
    while (i < end) { result.push_back(s.modules[i]); i = i + 1 };
    result
}
public fun module_id(d: &Descriptor): ID { d.object }
public fun namespace(d: &Descriptor): TypeName { d.namespace }
public fun module_name(d: &Descriptor): vector<u8> { d.name }
public fun value_type(d: &Descriptor): TypeName { d.value_type }
public fun module_schema(d: &Descriptor): u16 { d.schema }
public fun removable(d: &Descriptor): bool { d.removable }
public fun body_hash(d: &Descriptor): vector<u8> { d.body_hash }
public fun semantic_hash(d: &Descriptor): vector<u8> { d.semantic_hash }
public fun manifest(s: &Soul): Manifest {
    ready(s); Manifest {
        domain: b"soulidity/standard/manifest/v1", soul: object::id(s), schema: s.schema,
        name: s.name, revision: s.revision, origin: s.origin, modules: s.modules,
    }
}
public fun manifest_hash(s: &Soul): vector<u8> { hash::sha3_256(bcs::to_bytes(&manifest(s))) }
public fun assert_manifest(s: &Soul, expected_revision: u64, expected_hash: vector<u8>) {
    ready(s); cas(s, expected_revision); hash32(&expected_hash);
    assert!(manifest_hash(s) == expected_hash, EInput)
}

/// Native whole-asset composition. Unnesting is always available to the actual
/// parent holder; no application can turn this namespace into a permanent lock.
public fun nest(s: &mut Soul, child: Soul, expected: u64) {
    let id = object::id(&child);
    assert!(id != object::id(s), EIdentity);
    let semantic = manifest_hash(&child);
    install(s, NestedSoulWitness {}, bcs::to_bytes(&id), child, 1, true, semantic, expected)
}
public fun nested(s: &Soul, child: ID): &Soul {
    borrow_module<NestedSoulWitness, Soul>(s, bcs::to_bytes(&child))
}
public fun unnest(s: &mut Soul, child: ID, expected: u64): Soul {
    uninstall<NestedSoulWitness, Soul>(s, bcs::to_bytes(&child), expected)
}
/// PTB-compatible value path. No mutable child/root UID or reference escapes;
/// edited child must return under the same parent with the same object ID.
public fun begin_nested_update(s: &mut Soul, child: ID, expected: u64): (Soul, Edit<NestedSoulWitness, Soul>) {
    begin_update(s, NestedSoulWitness {}, bcs::to_bytes(&child), expected)
}
public fun commit_nested_update(s: &mut Soul, ticket: Edit<NestedSoulWitness, Soul>, child: Soul) {
    let semantic = manifest_hash(&child);
    commit_update(s, ticket, NestedSoulWitness {}, child, 1, semantic)
}

#[test_only]
public fun remove_version_for_testing<W>(s: &mut Soul, name: vector<u8>) {
    let d = descriptor<W>(s, name).destroy_some(); removed(s, &d)
}
#[test_only]
public fun remove_nesting_version_for_testing(s: &mut Soul) {
    let _: u64 = df::remove(&mut s.id, NestingVersionKey {});
}


/// Private linear custody of a root until the defining-module terminal.
/// No ability, unpack, mutable root/UID borrow or raw-root return is public.
public struct Creation { root:Soul, actor:address, fresh:bool }
public fun creation_ref(c:&Creation):&Soul { &c.root }
public fun creation_id(c:&Creation):ID { object::id(&c.root) }
/// This ingress accepts a previously available owned value. It cannot release
/// that value again, and cannot weaken a fresh descendant's custody boundary.
public fun hold_owned(root:Soul):Creation { Creation {root,actor:@0x0,fresh:false} }
public fun creation_install<W:drop,T:key+store>(c:&mut Creation,w:W,name:vector<u8>,value:T,schema:u16,removable:bool,semantic:vector<u8>,expected:u64) {
    assert!(type_name::with_original_ids<T>()!=type_name::with_original_ids<Soul>(),EAuthority);
    install(&mut c.root,w,name,value,schema,removable,semantic,expected)
}
public fun creation_install_annotated<W:drop,T:key+store>(c:&mut Creation,w:W,name:vector<u8>,value:T,schema:u16,removable:bool,semantic:vector<u8>,expected:u64,annotation:vector<u8>) {
    assert!(type_name::with_original_ids<T>()!=type_name::with_original_ids<Soul>(),EAuthority);
    install_annotated(&mut c.root,w,name,value,schema,removable,semantic,expected,annotation)
}
/// Initial edits are confined to a genuine source namespace, exact child and
/// exact root/revision. Native nested Souls never leave Creation through Edit.
public fun creation_begin_update<W:drop,T:key+store>(c:&mut Creation,w:W,name:vector<u8>,expected:u64):(T,Edit<W,T>) {
    assert!(type_name::with_original_ids<T>()!=type_name::with_original_ids<Soul>(),EAuthority);
    begin_update(&mut c.root,w,name,expected)
}
public fun creation_commit_update<W:drop,T:key+store>(c:&mut Creation,t:Edit<W,T>,w:W,value:T,schema:u16,semantic:vector<u8>) {
    assert!(type_name::with_original_ids<T>()!=type_name::with_original_ids<Soul>(),EAuthority);
    commit_update(&mut c.root,t,w,value,schema,semantic)
}
public fun creation_nest(c:&mut Creation,child:Creation,expected:u64) {
    let Creation {root,actor,fresh}=child;
    if(fresh){assert!(c.actor==@0x0 || c.actor==actor,EAuthority);c.actor=actor;c.fresh=true};nest(&mut c.root,root,expected)
}
public fun creation_nest_owned(c:&mut Creation,child:Soul,expected:u64) {
    nest(&mut c.root,child,expected)
}
/// Fresh roots and descendants finish to the actual creating sender.
/// Existing-owned handovers retain their original recipient; only an ID returns.
/// The caller cannot keep a reference after this value is consumed.
public fun creation_deliver(c:Creation,recipient:address):ID {
    assert!(recipient!=@0x0,EInput);let Creation{root,actor,fresh}=c;assert!(!fresh || recipient==actor,EAuthority);ready(&root);
    let id=object::id(&root);sui::transfer::public_transfer(root,recipient);id
}
public fun creation_deliver_sender(c:Creation,ctx:&TxContext):ID {
    assert!(c.actor==ctx.sender() || c.actor==@0x0,EAuthority);
    creation_deliver(c,ctx.sender())
}
public fun creation_lock(c:Creation,k:&mut sui::kiosk::Kiosk,a:&mut soulidity_standard::native_authority::Authority,p:&sui::transfer_policy::TransferPolicy<Soul>,ctx:&TxContext):ID {
    let Creation{root,actor,fresh}=c;assert!(!fresh || actor==ctx.sender(),EAuthority);ready(&root);let id=object::id(&root);
    soulidity_standard::native_authority::lock_creation(k,a,p,root,ctx);id
}
/// Append a closed fresh child to an actual locked, unlisted parent. The only
/// mutable parent reference remains inside this atomic defining-module terminal.
/// Closing sealed authority prevents subsequent public mutable access in this Tx.
public fun creation_nest_locked(
    c:Creation,k:&mut sui::kiosk::Kiosk,a:&mut soulidity_standard::native_authority::Authority,
    parent:ID,parent_origin:Origin,expected:u64,ctx:&TxContext,
):ID {
    let Creation{root,actor,fresh}=c;
    assert!(fresh && actor==ctx.sender(),EAuthority);ready(&root);
    let child=object::id(&root);
    let s=soulidity_standard::native_authority::borrow_locked_for_creation<Soul>(k,a,parent,ctx);
    assert!(object::id(s)==parent && origin(s)==parent_origin,EIdentity);
    nest(s,root,expected);child
}
#[test_only]
public fun creation_raw_for_testing(c:Creation):Soul {let Creation{root,actor:_,fresh:_}=c;root}

/// Existing-owned placement retains ordinary Kiosk handover. Any fresh
/// descendant keeps this boundary closed and requires the sealed lock terminal.
public fun creation_place_owned(c:Creation,k:&mut sui::kiosk::Kiosk,cap:&sui::kiosk::KioskOwnerCap):ID {
    let Creation{root,actor:_,fresh}=c;assert!(!fresh,EAuthority);ready(&root);
    let id=object::id(&root);sui::kiosk::place(k,cap,root);id
}

/// Nested initialization editing never returns a Soul or mutable Soul reference.
/// The exact child must return before the parent's edit can finish.
public struct CreationEdit { inner:Edit<NestedSoulWitness,Soul> }
public fun creation_begin_nested_update(c:&mut Creation,child:ID,expected:u64):(Creation,CreationEdit) {
    let(root,inner)=begin_nested_update(&mut c.root,child,expected);
    (Creation{root,actor:c.actor,fresh:c.fresh},CreationEdit{inner})
}
public fun creation_commit_nested_update(c:&mut Creation,ticket:CreationEdit,child:Creation) {
    let CreationEdit{inner}=ticket;let Creation{root,actor,fresh}=child;
    if(fresh){assert!(c.actor==@0x0 || actor==c.actor,EAuthority);c.actor=actor;c.fresh=true};
    commit_nested_update(&mut c.root,inner,root)
}
public fun creation_place_owned_authority(c:Creation,k:&mut sui::kiosk::Kiosk,a:&soulidity_standard::native_authority::Authority,ctx:&TxContext):ID {
    let Creation{root,actor:_,fresh}=c;assert!(!fresh,EAuthority);ready(&root);
    let id=object::id(&root);soulidity_standard::native_authority::place(k,a,root,ctx);id
}

/// Historical fixture bridge only. Excluded from every production root build.
#[test_only]
public fun creation_raw_mut_for_testing(c:&mut Creation):&mut Soul { &mut c.root }
