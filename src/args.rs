
use clap::{Parser, builder::PossibleValuesParser};
use crate::common::{SearchMode, SelectionMode, displayers_ux};


#[derive(Parser, Debug)]
#[command(author, version, about, term_width = 120)]
pub struct Cli {

    /// The index of the item to select by default.
    #[arg(short, long, default_value_t = 0)]
    index: usize,

    /// The displayer to use for the UX.
    #[arg(short, long, alias = "displayer", visible_alias = "displayer", value_parser = PossibleValuesParser::new(displayers_ux()), default_value = "WaySee")]
    ux: String,

    /// The separator used to separate the displays (columns) value from the returned value. (e.g., "col1|value" or "col1;col2|value")
    #[arg(short, long, default_value = "|")]
    separator: String,

    /// The separator used to separate columns in the display. (e.g., "col1;col2;col3")
    #[arg(short, long, default_value = ";")]
    delimiter: String,

    /// The maximum number of items to display in the UX. (if not provided, the default UX selected max value will be used.)
    #[arg(long)]
    max: Option<usize>,

    /// Select the selection mode to use.
    #[arg(short, long, value_enum, default_value_t = SelectionMode::Single)]
    mode: SelectionMode,

    /// The comment displayed in the header of the UX
    #[arg(short, long)]
    comment: Option<String>,

    /// Portion of the screen used by the displayer, if supported (e.g., "50%"). (/!\ Ignored by displayers that do not declare this capability.)
    #[arg(short = 'e', long)]
    height: Option<String>,
    
    /// Enable search mode.
    #[arg(long, num_args = 1, action = clap::ArgAction::SetFalse)]
    search: bool,
    
    /// The default search string.
    #[arg(long = "search-default", default_value = "")]
    search_default: String,

    /// Command to transform the search string. (e.g., for uppercase or lowercase search string transformations)
    #[arg(long = "search-transform")]
    search_transform: Option<String>,

    /// Select the search mode to use.
    #[arg(long = "search-mode", value_enum, default_value_t = SearchMode::Fuzzy)]
    search_mode: SearchMode,

    /// Value push to the search engine (fuzzy, exact, cmd, etc.) to specify where to search.
    #[arg(long = "search-haystack", default_value = "{full}")]
    search_haystack: String,

    /// The command to use for script search mode. (e.g., Bash, Python, PowerShell, etc.) (/!\ only used if search-mode is set to Script)
    #[arg(long = "search-cmd")]
    search_cmd: Option<String>,

    /// Allows to use regex in search.
    #[arg(long = "search-regex", default_missing_value = "true", num_args = 1, default_value_t = true)]
    search_regex: bool,

    /// Command to preview the selected item. (e.g., 'cat {}', 'cat {value}', 'cat {1}')
    #[arg(long = "preview-cmd")]
    preview_cmd: Option<String>,
}