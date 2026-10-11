module audit_consumer::probe;
use soulidity_standard::soul::Soul;
public fun expose(s: &mut Soul): &mut UID { &mut s.id }
