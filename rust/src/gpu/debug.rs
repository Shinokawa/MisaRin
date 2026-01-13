use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::OnceLock;

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum LogLevel {
    Off,
    Warn,
    Info,
    Verbose,
}

static LOG_LEVEL: OnceLock<LogLevel> = OnceLock::new();
static SEQ: AtomicU64 = AtomicU64::new(1);

pub fn level() -> LogLevel {
    *LOG_LEVEL.get_or_init(read_level_from_env)
}

pub fn next_seq() -> u64 {
    SEQ.fetch_add(1, Ordering::Relaxed)
}

pub fn log(required: LogLevel, args: std::fmt::Arguments) {
    if level() < required {
        return;
    }
    eprintln!("[misa-rin][rust][gpu] {args}");
}

fn read_level_from_env() -> LogLevel {
    match std::env::var("MISA_RIN_RUST_GPU_LOG") {
        Ok(raw) => parse_level(&raw),
        Err(_) => {
            if cfg!(debug_assertions) {
                LogLevel::Info
            } else {
                LogLevel::Off
            }
        }
    }
}

fn parse_level(value: &str) -> LogLevel {
    let normalized = value.trim().to_ascii_lowercase();
    match normalized.as_str() {
        "" => LogLevel::Off,
        "0" | "off" | "false" | "no" => LogLevel::Off,
        "warn" | "warning" => LogLevel::Warn,
        "info" | "1" | "on" | "true" | "yes" => LogLevel::Info,
        "verbose" | "debug" | "2" => LogLevel::Verbose,
        _ => LogLevel::Info,
    }
}
