module audit_consumer::probe;
use soulidity_standard::soul::{Origin, Soul, Edit};
public fun duplicate(ticket: Edit<Origin, Soul>): (Edit<Origin, Soul>, Edit<Origin, Soul>) { let other = copy ticket; (ticket, other) }
