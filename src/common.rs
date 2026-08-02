
use clap::{ValueEnum};


/// Represents the selection mode for the application.
#[derive(Debug, Clone, Copy, PartialEq, ValueEnum, Eq)]
pub enum SelectionMode {
    /// Single selection mode. Allows selecting a single item.
    Single,
    /// Multi selection mode. Allows selecting multiple items.
    Multi,
}
