
use clap::Parser;
mod args;
mod common;

fn main() {
    let args = args::Cli::parse();

    println!("Args : {:#?}", args);
}
