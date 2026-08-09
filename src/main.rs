
use clap::Parser;
mod args;
mod common;
mod utils;


fn main() {
    let args = args::Cli::parse();

    println!("Args : {:#?}", args);
}
