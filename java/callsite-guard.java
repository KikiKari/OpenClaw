// abstraction-provenance: {"artifact_sha256": "a91a394c0e49a9a65f616f1a0dc5137bf74250b8a1824d95448c8ed7e2f7e72e", "source_sha256": "b6d33ba222e838d8ea4e8f134b161c60019978c5abaa86299906dfe095635a2b", "target_language": "java"}
// callsite-guard.mjs — portiert nach java
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/scripts/lib/callsite-guard.mjs
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

import java.io.IOException;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;
import java.util.function.Function;
import java.util.stream.Collectors;

public class CallsiteGuard {

    public static class Params {
        private final String repoRoot;
        private final List<String> sourceRoots;
        private final List<String> extraTestSuffixes;
        private final Function<String, Boolean> skipRelativePath;
        private final Function<String, List<Integer>> findCallLines;
        private final Function<String, Boolean> allowCallsite;
        private final String header;
        private final String footer;
        private final Boolean sortViolations;

        public Params(String repoRoot, List<String> sourceRoots, List<String> extraTestSuffixes,
                      Function<String, Boolean> skipRelativePath, Function<String, List<Integer>> findCallLines,
                      Function<String, Boolean> allowCallsite, String header, String footer, Boolean sortViolations) {
            this.repoRoot = repoRoot;
            this.sourceRoots = sourceRoots != null ? sourceRoots : new ArrayList<>();
            this.extraTestSuffixes = extraTestSuffixes != null ? extraTestSuffixes : new ArrayList<>();
            this.skipRelativePath = skipRelativePath;
            this.findCallLines = findCallLines;
            this.allowCallsite = allowCallsite;
            this.header = header;
            this.footer = footer;
            this.sortViolations = sortViolations;
        }

        // Getters
        public String getRepoRoot() { return repoRoot; }
        public List<String> getSourceRoots() { return sourceRoots; }
        public List<String> getExtraTestSuffixes() { return extraTestSuffixes; }
        public Function<String, Boolean> getSkipRelativePath() { return skipRelativePath; }
        public Function<String, List<Integer>> getFindCallLines() { return findCallLines; }
        public Function<String, Boolean> getAllowCallsite() { return allowCallsite; }
        public String getHeader() { return header; }
        public String getFooter() { return footer; }
        public Boolean getSortViolations() { return sortViolations; }
    }

    public static void runCallsiteGuard(Params params) throws IOException, InterruptedException, ExecutionException {
        TsGuardUtils utils = new TsGuardUtils();
        List<String> sourceRoots = utils.resolveSourceRoots(params.getRepoRoot(), params.getSourceRoots());
        
        List<String> files = utils.collectTypeScriptFilesFromRoots(sourceRoots, params.getExtraTestSuffixes());
        List<String> violations = new ArrayList<>();

        for (String filePath : files) {
            Path file = Paths.get(filePath);
            String relPath = utils.getRelativePath(params.getRepoRoot(), filePath).replace("\\", "/");
            
            if (params.getSkipRelativePath() != null && params.getSkipRelativePath().apply(relPath)) {
                continue;
            }
            
            String content = Files.readString(file);
            List<Integer> lines = params.getFindCallLines().apply(content);
            
            for (Integer line : lines) {
                String callsite = relPath + ":" + line;
                if (params.getAllowCallsite() != null && params.getAllowCallsite().apply(callsite)) {
                    continue;
                }
                violations.add(callsite);
            }
        }

        if (violations.isEmpty()) {
            return;
        }

        System.err.println(params.getHeader());
        List<String> output = params.getSortViolations() == Boolean.FALSE ? violations : 
                             violations.stream().sorted().collect(Collectors.toList());
        
        for (String violation : output) {
            System.err.println("- " + violation);
        }
        
        if (params.getFooter() != null) {
            System.err.println(params.getFooter());
        }
        
        System.exit(1);
    }
}
