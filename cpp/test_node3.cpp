// abstraction-provenance: {"artifact_sha256": "fc969d5b61e7f66e019614a5726497e65521ec133c87dd0e547db5ad990db98c", "source_sha256": "151279ec3dae16c8f81904c36418b5f9c6040036a0a98adef5ec52bfea0b57ab", "target_language": "cpp"}
// test_node3.sh — portiert nach cpp
// Quelle: shell, OpenClaw@gateway1:scripts/test_node3.sh
// auch in: OpenClaw@gateway2:scripts/test_node3.sh
// auch in: workspace@local:scripts/test_node3.sh
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <cstdlib>
#include <iostream>
#include <string>
#include <memory>

#ifdef _WIN32
#include <windows.h>
#else
#include <unistd.h>
#include <sys/wait.h>
#include <signal.h>
#include <cstring>
#endif

// Helper function to execute command with timeout
int executeWithTimeout(const std::string& command, int timeoutSeconds) {
#ifdef _WIN32
    // Windows implementation using CreateProcess and WaitForSingleObject
    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));
    
    char* cmd = new char[command.length() + 1];
    strcpy(cmd, command.c_str());
    
    if (!CreateProcessA(NULL, cmd, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi)) {
        delete[] cmd;
        return -1;
    }
    
    delete[] cmd;
    
    DWORD waitResult = WaitForSingleObject(pi.hProcess, timeoutSeconds * 1000);
    
    if (waitResult == WAIT_TIMEOUT) {
        TerminateProcess(pi.hProcess, 1);
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
        return 124; // Timeout exit code
    }
    
    DWORD exitCode;
    GetExitCodeProcess(pi.hProcess, &exitCode);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    return static_cast<int>(exitCode);
#else
    // Unix/Linux implementation using fork and alarm
    pid_t pid = fork();
    
    if (pid == 0) {
        // Child process
        execl("/bin/sh", "sh", "-c", command.c_str(), (char*)NULL);
        _exit(127); // Failed to execute
    } else if (pid > 0) {
        // Parent process
        signal(SIGALRM, [](int) { }); // Empty signal handler
        alarm(timeoutSeconds);
        
        int status;
        pid_t result = waitpid(pid, &status, 0);
        alarm(0); // Cancel alarm
        
        if (result == -1) {
            // Timeout or error
            kill(pid, SIGKILL);
            waitpid(pid, &status, 0); // Clean up zombie
            return 124; // Timeout exit code
        }
        
        if (WIFEXITED(status)) {
            return WEXITSTATUS(status);
        } else {
            return -1; // Process terminated by signal
        }
    } else {
        // Fork failed
        return -1;
    }
#endif
}

int main() {
    // Test Node 3 Connection
    // Set environment variable
#ifdef _WIN32
    _putenv("OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=1");
#else
    setenv("OPENCLAW_ALLOW_INSECURE_PRIVATE_WS", "1", 1);
#endif
    
    std::cout << "Starting node connection test..." << std::endl;
    
    // Execute the command with timeout
    std::string command = "/usr/local/bin/openclaw node run --host 152.53.145.65 --port 18789";
    int exitCode = executeWithTimeout(command, 15);
    
    // Print the exit code
    std::cout << "Exit code: " << exitCode << std::endl;
    
    return exitCode;
}
