// abstraction-provenance: {"artifact_sha256": "7d257d7c4253409b24cf769cbe979a1142e61a88660e88a912dfb88acb161e80", "source_sha256": "eed3bdbc8fef27830c5850ddac7a0ed91929c33fde29bd0fc4729b45b78fada0", "target_language": "java"}
// npm-runner.mjs — portiert nach java
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/npm-runner.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.File;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

public class NpmRunnerResolver {

    public static class ResolvedRunner {
        public final String command;
        public final List<String> args;
        public final boolean shell;
        public final Map<String, String> env;
        public final boolean windowsVerbatimArguments;

        public ResolvedRunner(String command, List<String> args, boolean shell, Map<String, String> env, boolean windowsVerbatimArguments) {
            this.command = command;
            this.args = args;
            this.shell = shell;
            this.env = env;
            this.windowsVerbatimArguments = windowsVerbatimArguments;
        }
    }

    public static class Params {
        public String execPath;
        public List<String> npmArgs;
        public Boolean existsSync;
        public Map<String, String> env;
        public String platform;
        public String comSpec;

        // Hilfsfelder für Standardwerte
        public static Params createDefault() {
            Params params = new Params();
            params.execPath = System.getProperty("java.home") + "/bin/java"; // Beispielwert
            params.npmArgs = new ArrayList<>();
            params.env = new HashMap<>(System.getenv());
            params.platform = System.getProperty("os.name").toLowerCase().contains("win") ? "win32" : "posix";
            params.comSpec = params.env.getOrDefault("ComSpec", "cmd.exe");
            return params;
        }
    }

    private static boolean defaultExistsSync(String path) {
        return Files.exists(Paths.get(path));
    }

    private static String resolvePathEnvKey(Map<String, String> env) {
        if (env.containsKey("PATH")) {
            return "PATH";
        } else if (env.containsKey("Path")) {
            return "Path";
        }
        return "PATH"; // Fallback
    }

    private static ResolvedRunner resolveToolchainNpmRunner(
            String comSpec,
            java.util.function.Function<String, Boolean> existsSyncFunc,
            String nodeDir,
            List<String> npmArgs,
            boolean isWindows) {

        List<String> npmCliCandidates = Arrays.asList(
                Paths.get(nodeDir, "../lib/node_modules/npm/bin/npm-cli.js").toString(),
                Paths.get(nodeDir, "node_modules/npm/bin/npm-cli.js").toString()
        );

        Optional<String> npmCliPathOpt = npmCliCandidates.stream()
                .filter(existsSyncFunc::apply)
                .findFirst();

        if (npmCliPathOpt.isPresent()) {
            String nodeExecutable = isWindows ?
                    Paths.get(nodeDir, "node.exe").toString() :
                    Paths.get(nodeDir, "node").toString();

            List<String> args = new ArrayList<>();
            args.add(npmCliPathOpt.get());
            args.addAll(npmArgs);

            return new ResolvedRunner(nodeExecutable, args, false, null, false);
        }

        if (!isWindows) {
            return null;
        }

        String npmExePath = Paths.get(nodeDir, "npm.exe").toString();
        if (existsSyncFunc.apply(npmExePath)) {
            return new ResolvedRunner(npmExePath, new ArrayList<>(npmArgs), false, null, false);
        }

        String npmCmdPath = Paths.get(nodeDir, "npm.cmd").toString();
        if (existsSyncFunc.apply(npmCmdPath)) {
            String cmdLine = buildCmdExeCommandLine(npmCmdPath, npmArgs);
            List<String> argsList = Arrays.asList("/d", "/s", "/c", cmdLine);
            return new ResolvedRunner(comSpec, argsList, false, null, true);
        }

        return null;
    }

    public static ResolvedRunner resolveNpmRunner(Params params) {
        if (params == null) {
            params = Params.createDefault();
        }

        String execPath = params.execPath != null ? params.execPath : System.getProperty("java.home") + "/bin/java";
        List<String> npmArgs = params.npmArgs != null ? new ArrayList<>(params.npmArgs) : new ArrayList<>();
        java.util.function.Function<String, Boolean> existsSyncFunc =
                params.existsSync != null ? (path) -> params.existsSync : NpmRunnerResolver::defaultExistsSync;
        Map<String, String> env = params.env != null ? new HashMap<>(params.env) : new HashMap<>(System.getenv());
        String platform = params.platform != null ? params.platform : (System.getProperty("os.name").toLowerCase().contains("win") ? "win32" : "posix");
        String comSpec = params.comSpec != null ? params.comSpec : env.getOrDefault("ComSpec", "cmd.exe");

        boolean isWindows = "win32".equals(platform);
        Path nodeDirPath = Paths.get(execPath).getParent();
        String nodeDir = nodeDirPath != null ? nodeDirPath.toString() : "";

        ResolvedRunner npmToolchain = resolveToolchainNpmRunner(comSpec, existsSyncFunc, nodeDir, npmArgs, isWindows);

        if (npmToolchain != null) {
            return npmToolchain;
        }

        if (isWindows) {
            List<String> expectedPaths = Arrays.asList(
                    Paths.get(nodeDir, "../lib/node_modules/npm/bin/npm-cli.js").toString(),
                    Paths.get(nodeDir, "node_modules/npm/bin/npm-cli.js").toString(),
                    Paths.get(nodeDir, "npm.exe").toString(),
                    Paths.get(nodeDir, "npm.cmd").toString()
            );
            throw new RuntimeException(
                    "failed to resolve a toolchain-local npm next to " + execPath + ". " +
                            "Checked: " + String.join(", ", expectedPaths) + ". " +
                            "OpenClaw refuses to shell out to bare npm on Windows; install a Node.js toolchain that bundles npm or run with a matching Node installation."
            );
        }

        String pathKey = resolvePathEnvKey(env);
        String currentPath = env.getOrDefault(pathKey, "");
        Map<String, String> newEnv = new HashMap<>(env);
        String newPathValue = currentPath.isEmpty() ? nodeDir : nodeDir + File.pathSeparator + currentPath;
        newEnv.put(pathKey, newPathValue);

        return new ResolvedRunner("npm", npmArgs, false, newEnv, false);
    }

    // Dummy-Methode für buildCmdExeCommandLine – muss entsprechend implementiert werden
    private static String buildCmdExeCommandLine(String command, List<String> args) {
        StringBuilder sb = new StringBuilder("\"" + command + "\"");
        for (String arg : args) {
            sb.append(" \"").append(arg).append("\"");
        }
        return sb.toString();
    }
}
