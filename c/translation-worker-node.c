// abstraction-provenance: {"artifact_sha256": "ffd1fe838dc584515fedc7dcd3b8ef70f0342a81492786a0261ebf9a820a7919", "source_sha256": "9caa03d9bb15f9d91f7e2672653c8c81852b35f9076edf8b7f839f4f06ac7dfd", "target_language": "c"}
// translation-worker-node.sh — portiert nach c
// Quelle: shell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node.sh
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <openssl/sha.h>
#include <fcntl.h>

// Function to compute SHA256 hash of a file
int compute_sha256(const char *filepath, unsigned char *hash) {
    FILE *file = fopen(filepath, "rb");
    if (!file) return -1;

    SHA256_CTX sha256;
    SHA256_Init(&sha256);

    char buffer[8192];
    size_t bytes;
    while ((bytes = fread(buffer, 1, sizeof(buffer), file)) > 0) {
        SHA256_Update(&sha256, buffer, bytes);
    }

    SHA256_Final(hash, &sha256);
    fclose(file);
    return 0;
}

// Function to convert hash to hex string
void hash_to_hex(unsigned char *hash, char *output) {
    for (int i = 0; i < SHA256_DIGEST_LENGTH; i++) {
        sprintf(output + (i * 2), "%02x", hash[i]);
    }
    output[SHA256_DIGEST_LENGTH * 2] = '\0';
}

int main(int argc, char *argv[]) {
    // Check argument count
    if (argc != 3) {
        fprintf(stderr, "Usage: translation-worker-node node2|node3|node4|node6 prepare|health|run\n");
        exit(2);
    }

    const char *node = argv[1];
    const char *action = argv[2];

    const char *worker = NULL;
    const char *expected_hash = NULL;

    // Determine worker path and expected hash based on node
    if (strcmp(node, "node2") == 0) {
        worker = "/home/node/.openclaw/workers/translation-worker";
        expected_hash = "565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286";
    } else if (strcmp(node, "node3") == 0) {
        worker = "/home/openclaw/.openclaw/workers/translation-worker";
        expected_hash = "9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de";
    } else if (strcmp(node, "node4") == 0) {
        worker = "/root/.openclaw/workers/translation-worker";
        expected_hash = "565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286";
    } else if (strcmp(node, "node6") == 0) {
        worker = "/home/node/.openclaw/workers/translation-worker";
        expected_hash = "9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de";
    } else {
        fprintf(stderr, "Unknown or non-POSIX node\n");
        exit(2);
    }

    // Validate action
    if (strcmp(action, "prepare") != 0 && strcmp(action, "health") != 0 && strcmp(action, "run") != 0) {
        fprintf(stderr, "Unknown action\n");
        exit(2);
    }

    // Check if worker exists and is not a symlink
    struct stat st;
    if (stat(worker, &st) != 0 || S_ISLNK(st.st_mode)) {
        fprintf(stderr, "Missing worker or symlink rejected: %s\n", worker);
        exit(1);
    }

    // Compute actual hash
    unsigned char hash[SHA256_DIGEST_LENGTH];
    if (compute_sha256(worker, hash) != 0) {
        fprintf(stderr, "Failed to compute hash for: %s\n", worker);
        exit(1);
    }

    char actual_hash[SHA256_DIGEST_LENGTH * 2 + 1];
    hash_to_hex(hash, actual_hash);

    // Compare hashes
    if (strcmp(actual_hash, expected_hash) != 0) {
        fprintf(stderr, "Worker checksum mismatch: %s\n", worker);
        exit(1);
    }

    // Make worker executable
    if (chmod(worker, st.st_mode | S_IXUSR | S_IXGRP | S_IXOTH) != 0) {
        perror("chmod");
        exit(1);
    }

    // Execute action
    if (strcmp(action, "prepare") == 0) {
        printf("Worker verified and executable: %s\n", worker);
    } else if (strcmp(action, "health") == 0) {
        execl(worker, worker, "--health", (char *)NULL);
        perror("execl");
        exit(1);
    } else if (strcmp(action, "run") == 0) {
        // Forward stdin to worker
        execl(worker, worker, (char *)NULL);
        perror("execl");
        exit(1);
    }

    return 0;
}
