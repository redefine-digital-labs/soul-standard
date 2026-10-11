module audit_consumer::probe;
use soulidity_standard::soul::{Origin, Soul, Edit};
public struct Persisted has store { ticket: Edit<Origin, Soul> }
