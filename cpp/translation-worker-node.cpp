// abstraction-provenance: {"artifact_sha256": "f299be0c2792db937753a90f3317928657eca93aa3f22bfce12fffdfdecfa041", "source_sha256": "9caa03d9bb15f9d91f7e2672653c8c81852b35f9076edf8b7f839f4f06ac7dfd", "target_language": "cpp"}
// translation-worker-node.sh — portiert nach cpp
// Quelle: shell, workspace@local:skills/multi-nodes-utils/scripts/translation-worker-node.sh
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <string>
#include <cstring>
#include <cstdlib>
#include <unistd.h>
#include <sys/stat.h>
#include <openssl/sha.h>
#include <iomanip>
#include <sstream>

// Run on the selected node after transferring its native worker. JSON stdin is
// forwarded unchanged to the worker in run mode.

void usage() {
    std::cerr << "Usage: translation-worker-node node2|node3|node4|node6 prepare|health|run" << std::endl;
    exit(2);
}

std::string calculateSHA256(const std::string& filepath) {
    FILE* file = fopen(filepath.c_str(), "rb");
    if (!file) {
        return "";
    }

    SHA256_CTX sha256;
    SHA256_Init(&sha256);
    
    const int BUFFER_SIZE = 32768;
    char buffer[BUFFER_SIZE];
    size_t bytesRead;
    
    while ((bytesRead = fread(buffer, 1, BUFFER_SIZE, file))) {
        SHA256_Update(&sha256, buffer, bytesRead);
    }
    
    fclose(file);
    
    unsigned char hash[SHA256_DIGEST_LENGTH];
    SHA256_Final(hash, &sha256);
    
    std::stringstream ss;
    for (int i = 0; i < SHA256_DIGEST_LENGTH; i++) {
        ss << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(hash[i]);
    }
    
    return ss.str();
}

bool fileExists(const std::string& path) {
    struct stat buffer;
    return (stat(path.c_str(), &buffer) == 0);
}

bool isSymlink(const std::string& path) {
    struct stat buffer;
    if (lstat(path.c_str(), &buffer) == 0) {
        return S_ISLNK(buffer.st_mode);
    }
    return false;
}

int main(int argc, char* argv[]) {
    if (argc != 3) {
        usage();
    }

    std::string node = argv[1];
    std::string action = argv[2];
    std::string worker;
    std::string expected;

    if (node == "node2") {
        worker = "/home/node/.openclaw/workers/translation-worker";
        expected = "565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286";
    } else if (node == "node3") {
        worker = "/home/openclaw/.openclaw/workers/translation-worker";
        expected = "9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de";
    } else if (node == "node4") {
        worker = "/root/.openclaw/workers/translation-worker";
        expected = "565bba6c22954e7f75a217fc49aa33b5e6d5fd6aa1c8488ffc82e8780c4d1286";
    } else if (node == "node6") {
        worker = "/home/node/.openclaw/workers/translation-worker";
        expected = "9164bdb00dcc99ae70a6fa072e80068f695726aefa4d752345a80fe24e5426de";
    } else {
        std::cerr << "Unknown or non-POSIX node" << std::endl;
        return 2;
    }

    if (action != "prepare" && action != "health" && action != "run") {
        std::cerr << "Unknown action" << std::endl;
        return 2;
    }

    if (!fileExists(worker) || isSymlink(worker)) {
        std::cerr << "Missing worker or symlink rejected: " << worker << std::endl;
        return 1;
    }

    std::string actual = calculateSHA256(worker);
    if (actual != expected) {
        std::cerr << "Worker checksum mismatch: " << worker << std::endl;
        return 1;
    }

    chmod(worker.c_str(), S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH);

    if (action == "prepare") {
        std::cout << "Worker verified and executable: " << worker << std::endl;
        return 0;
    } else if (action == "health") {
        execl(worker.c_str(), worker.c_str(), "--health", nullptr);
        perror("exec failed");
        return 1;
    } else { // run
        execl(worker.c_str(), worker.c_str(), nullptr);
        perror("exec failed");
        return 1;
    }
}
