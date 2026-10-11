module audit_consumer::probe;
use soulidity_standard::soul::{Origin, Soul, Edit};
public fun discard(ticket: Edit<Origin, Soul>) { let _ = ticket; }
