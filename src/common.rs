
use clap::{ValueEnum};


/// Represents the selection mode for the application.
#[derive(Debug, Clone, Copy, PartialEq, ValueEnum, Eq)]
pub enum SelectionMode {
    /// Single selection mode. Allows selecting a single item.
    Single,
    /// Multi selection mode. Allows selecting multiple items.
    Multi,
}

/// Represents the search mode for the application.
#[derive(Debug, Clone, Copy, PartialEq, ValueEnum, Eq)]
pub enum SearchMode {
    /// Exact search mode. Matches the search string exactly.
    Exact,
    /// Fuzzy search mode. Matches the search string approximately.
    Fuzzy,
    /// Custom search mode. Matches the search string using a custom script (e.g., Bash, Python, PowerShell, etc.).
    Custom,
}
