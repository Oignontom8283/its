
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
    
}