module audit_consumer::probe;
use soulidity_standard::soul::{Self, Soul, Origin};
public fun inspect(s: &Soul): (u64, Origin) { (soul::revision(s), soul::origin(s)) }
