use std::env;
use std::io::{Read, Write};
use std::net::TcpStream;
use std::time::Duration;

// OpenClaw Node Health Check (Rust) — raw HTTP/1.0 probe over std TCP, no deps
fn check_node(addr: &str) -> String {
    match TcpStream::connect(addr) {
        Ok(mut stream) => {
            let _ = stream.set_read_timeout(Some(Duration::from_secs(3)));
            let req = format!(
                "GET /health HTTP/1.0\r\nHost: {addr}\r\nConnection: close\r\n\r\n"
            );
            if stream.write_all(req.as_bytes()).is_err() {
                return format!("FAIL {addr}: write error");
            }
            let mut buf = String::new();
            let _ = stream.read_to_string(&mut buf);
            let status = buf.lines().next().unwrap_or("no response");
            format!("OK   {addr}: {status}")
        }
        Err(e) => format!("FAIL {addr}: {e}"),
    }
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let nodes = if args.is_empty() {
        vec!["localhost:8080".to_string(), "localhost:8081".to_string()]
    } else {
        args
    };
    for node in &nodes {
        println!("{}", check_node(node));
    }
}
