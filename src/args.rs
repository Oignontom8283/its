
use clap::{Parser};
use crate::common::{SearchMode, SelectionMode};


#[derive(Parser, Debug)]
#[command(author, version, about, term_width = 120)]
pub struct Cli {

    /// The index of the item to select by default.
    #[arg(short, long, default_value_t = 0)]
    index: u64,

    /// Select the selection mode to use.
    #[arg(short, long, value_enum, default_value_t = SelectionMode::Single)]
    mode: SelectionMode,

    /// The comment displayed in the header of the UX
    #[arg(short, long)]
    comment: Option<String>,
    
    /// Enable search mode.
    #[arg(long, num_args = 1, default_missing_value = "true", num_args = 1, default_value_t = true)]
    search: bool,

}