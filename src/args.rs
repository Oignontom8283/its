
use clap::{Parser};
use crate::common::{SearchMode, SelectionMode};


#[derive(Parser, Debug)]
#[command(author, version, about, term_width = 120)]
pub struct Cli {

    /// The index of the item to select by default.
    #[arg(short, long, default_value_t = 0)]
    index: u64,

}