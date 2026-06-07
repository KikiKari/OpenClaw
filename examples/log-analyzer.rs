use std::collections::BTreeMap;
use std::io::{self, BufRead};

// OpenClaw log analyzer (Rust) — parses gateway access logs from stdin
fn main() {
    let mut counts: BTreeMap<String, u32> = BTreeMap::new();
    for key in ["ERROR", "INFO", "WARN"] {
        counts.insert(key.to_string(), 0);
    }
    let stdin = io::stdin();
    for line in stdin.lock().lines().map_while(Result::ok) {
        let mut it = line.split_whitespace();
        let (Some(ts), Some(level), Some(node)) = (it.next(), it.next(), it.next()) else {
            continue;
        };
        let msg = it.collect::<Vec<_>>().join(" ");
        if let Some(c) = counts.get_mut(level) {
            *c += 1;
            if level == "ERROR" {
                println!("\u{26a0} {ts} [{node}] {msg}");
            }
        }
    }
    println!("\n--- Summary ---");
    for (level, count) in &counts {
        println!("{level}: {count}");
    }
}
