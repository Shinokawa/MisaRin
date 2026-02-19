use std::collections::VecDeque;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum LogLevel {
    Off,
    Warn,
    Info,
    Verbose,
}

static LOG_LEVEL: OnceLock<LogLevel> = OnceLock::new();
static SEQ: AtomicU64 = AtomicU64::new(1);
static LOG_BUFFER: OnceLock<Mutex<VecDeque<String>>> = OnceLock::new();
const LOG_BUFFER_CAPACITY: usize = 512;

pub fn level() -> LogLevel {
    *LOG_LEVEL.get_or_init(read_level_from_env)
}

pub fn set_level(level: LogLevel) {
    let _ = LOG_LEVEL.set(level);
}

pub fn set_level_from_u32(raw: u32) {
    let level = match raw {
        0 => LogLevel::Off,
        1 => LogLevel::Warn,
        2 => LogLevel::Info,
        _ => LogLevel::Verbose,
    };
    set_level(level);
}

pub fn next_seq() -> u64 {
    SEQ.fetch_add(1, Ordering::Relaxed)
}

pub fn log(required: LogLevel, args: std::fmt::Arguments) {
    if level() < required {
        return;
    }
    let msg = format!("[misa-rin][rust][gpu] {args}");
    {
        let mut guard = log_buffer()
            .lock()
            .unwrap_or_else(|err| err.into_inner());
        if guard.len() >= LOG_BUFFER_CAPACITY {
            guard.pop_front();
        }
        guard.push_back(msg.clone());
    }
    eprintln!("{msg}");
}

pub fn pop_log_line() -> Option<String> {
    let mut guard = log_buffer()
        .lock()
        .unwrap_or_else(|err| err.into_inner());
    guard.pop_front()
}

fn read_level_from_env() -> LogLevel {
    match std::env::var("MISA_RIN_RUST_GPU_LOG") {
        Ok(raw) => parse_level(&raw),
        Err(_) => default_level(),
    }
}

fn default_level() -> LogLevel {
    LogLevel::Off
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

fn log_buffer() -> &'static Mutex<VecDeque<String>> {
    LOG_BUFFER.get_or_init(|| Mutex::new(VecDeque::with_capacity(LOG_BUFFER_CAPACITY)))
}
