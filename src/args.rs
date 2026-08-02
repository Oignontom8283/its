
use clap::{Parser};
use crate::common::{SearchMode, SelectionMode};


#[derive(Parser, Debug)]
#[command(author, version, about, term_width = 120)]
pub struct Cli {

}