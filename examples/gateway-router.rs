use std::collections::hash_map::RandomState;
use std::hash::{BuildHasher, Hasher};

// OpenClaw gateway router — upstream node selection (port of nginx-gateway)
// Dependency-free pseudo-random index via the std hasher's random seed.
fn get_node(nodes: &[&str]) -> usize {
    let seed = RandomState::new().build_hasher().finish();
    (seed % nodes.len() as u64) as usize
}

fn main() {
    let nodes = ["gateway1.openclaw.internal", "gateway2.openclaw.internal"];
    let target = nodes[get_node(&nodes)];
    println!("OpenClaw routing to: {target}");
}
