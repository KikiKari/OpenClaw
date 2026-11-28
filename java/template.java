// abstraction-provenance: {"artifact_sha256": "8a2af086ddb45461997ac2d6441409963304ca8f43604bd79f956cc5bf8d2e33", "source_sha256": "4a2933eefa63483e06669c63463cb479ee7726e59314faa3024778c7ec79ce7e", "target_language": "java"}
// template.js — portiert nach java
// Quelle: javascript, workspace@local:skills/github-clones/openclaw/src/auto-reply/reply/export-html/template.js
// Erzeugt: 2026-11-28 durch ABSTRACTIONS_MANAGER.py

import java.util.*;
import java.util.stream.Collectors;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.io.IOException;
import java.net.URLDecoder;
import java.nio.file.Files;
import java.nio.file.Paths;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

public class Template {
    private static final ObjectMapper objectMapper = new ObjectMapper();
    
    // ============================================================
    // DATA LOADING
    // ============================================================
    
    private static JsonNode loadData() throws IOException {
        // In a real implementation, you would load this from a file or resource
        String base64 = Files.readAllLines(Paths.get("session-data.txt")).get(0);
        byte[] decodedBytes = Base64.getDecoder().decode(base64);
        String jsonData = new String(decodedBytes, StandardCharsets.UTF_8);
        return objectMapper.readTree(jsonData);
    }
    
    // ============================================================
    // URL PARAMETER HANDLING
    // ============================================================
    
    private static Map<String, String> parseUrlParameters(String queryString) {
        Map<String, String> params = new HashMap<>();
        if (queryString != null && !queryString.isEmpty()) {
            String[] pairs = queryString.split("&");
            for (String pair : pairs) {
                String[] keyValue = pair.split("=");
                if (keyValue.length > 1) {
                    params.put(keyValue[0], keyValue[1]);
                } else {
                    params.put(keyValue[0], "");
                }
            }
        }
        return params;
    }
    
    // ============================================================
    // DATA STRUCTURES
    // ============================================================
    
    private static class Entry {
        public String id;
        public String type;
        public String parentId;
        public String timestamp;
        public JsonNode message;
        public String targetId;
        public String label;
        public String customType;
        public JsonNode content;
        public String summary;
        public String modelId;
        public String thinkingLevel;
        
        public Entry(JsonNode node) {
            this.id = node.get("id").asText();
            this.type = node.get("type").asText();
            this.parentId = node.has("parentId") ? node.get("parentId").asText() : null;
            this.timestamp = node.has("timestamp") ? node.get("timestamp").asText() : null;
            this.message = node.has("message") ? node.get("message") : null;
            this.targetId = node.has("targetId") ? node.get("targetId").asText() : null;
            this.label = node.has("label") ? node.get("label").asText() : null;
            this.customType = node.has("customType") ? node.get("customType").asText() : null;
            this.content = node.has("content") ? node.get("content") : null;
            this.summary = node.has("summary") ? node.get("summary").asText() : null;
            this.modelId = node.has("modelId") ? node.get("modelId").asText() : null;
            this.thinkingLevel = node.has("thinkingLevel") ? node.get("thinkingLevel").asText() : null;
        }
    }
    
    // ============================================================
    // TREE DATA PREPARATION (no DOM, pure data)
    // ============================================================
    
    /**
     * Build tree structure from flat entries.
     * Returns array of root nodes, each with { entry, children, label }.
     */
    private static List<TreeNode> buildTree(List<Entry> entries, Map<String, String> labelMap) {
        Map<String, TreeNode> nodeMap = new HashMap<>();
        List<TreeNode> roots = new ArrayList<>();
        
        // Create nodes
        for (Entry entry : entries) {
            nodeMap.put(entry.id, new TreeNode(entry, new ArrayList<>(), labelMap.get(entry.id)));
        }
        
        // Build parent-child relationships
        for (Entry entry : entries) {
            TreeNode node = nodeMap.get(entry.id);
            if (entry.parentId == null || entry.parentId.equals("") || entry.parentId.equals(entry.id)) {
                roots.add(node);
            } else {
                TreeNode parent = nodeMap.get(entry.parentId);
                if (parent != null) {
                    parent.children.add(node);
                } else {
                    roots.add(node);
                }
            }
        }
        
        // Sort children by timestamp
        for (TreeNode root : roots) {
            sortChildren(root);
        }
        
        return roots;
    }
    
    private static void sortChildren(TreeNode node) {
        node.children.sort((a, b) -> {
            LocalDateTime timeA = LocalDateTime.parse(a.entry.timestamp);
            LocalDateTime timeB = LocalDateTime.parse(b.entry.timestamp);
            return timeA.compareTo(timeB);
        });
        for (TreeNode child : node.children) {
            sortChildren(child);
        }
    }
    
    /**
     * Build set of entry IDs on path from root to target.
     */
    private static Set<String> buildActivePathIds(String targetId, Map<String, Entry> byId) {
        Set<String> ids = new HashSet<>();
        Entry current = byId.get(targetId);
        while (current != null) {
            ids.add(current.id);
            // Stop if no parent or self-referencing (root)
            if (current.parentId == null || current.parentId.equals(current.id)) {
                break;
            }
            current = byId.get(current.parentId);
        }
        return ids;
    }
    
    /**
     * Get array of entries from root to target (the conversation path).
     */
    private static List<Entry> getPath(String targetId, Map<String, Entry> byId) {
        List<Entry> path = new ArrayList<>();
        Entry current = byId.get(targetId);
        while (current != null) {
            path.add(0, current);
            // Stop if no parent or self-referencing (root)
            if (current.parentId == null || current.parentId.equals(current.id)) {
                break;
            }
            current = byId.get(current.parentId);
        }
        return path;
    }
    
    // Tree node lookup for finding leaves
    private static Map<String, TreeNode> treeNodeMap = null;
    
    /**
     * Find the newest leaf node reachable from a given node.
     * This allows clicking any node in a branch to show the full branch.
     * Children are sorted by timestamp, so the newest is always last.
     */
    private static String findNewestLeaf(String nodeId, List<TreeNode> tree) {
        // Build tree node map lazily
        if (treeNodeMap == null) {
            treeNodeMap = new HashMap<>();
            for (TreeNode rootNode : tree) {
                mapNodes(rootNode);
            }
        }
        
        TreeNode node = treeNodeMap.get(nodeId);
        if (node == null) {
            return nodeId;
        }
        
        // Follow the newest (last) child at each level
        TreeNode current = node;
        while (!current.children.isEmpty()) {
            current = current.children.get(current.children.size() - 1);
        }
        return current.entry.id;
    }
    
    private static void mapNodes(TreeNode node) {
        treeNodeMap.put(node.entry.id, node);
        for (TreeNode child : node.children) {
            mapNodes(child);
        }
    }
    
    /**
     * Flatten tree into list with indentation and connector info.
     * Returns array of { node, indent, showConnector, isLast, gutters, isVirtualRootChild, multipleRoots }.
     * Matches tree-selector.ts logic exactly.
     */
    private static List<FlatNode> flattenTree(List<TreeNode> roots, Set<String> activePathIds) {
        List<FlatNode> result = new ArrayList<>();
        boolean multipleRoots = roots.size() > 1;
        
        // Mark which subtrees contain the active leaf
        Map<TreeNode, Boolean> containsActive = new HashMap<>();
        for (TreeNode root : roots) {
            markActive(root, activePathIds, containsActive);
        }
        
        // Stack: [node, indent, justBranched, showConnector, isLast, gutters, isVirtualRootChild]
        Stack<Object[]> stack = new Stack<>();
        
        // Add roots (prioritize branch containing active leaf)
        List<TreeNode> orderedRoots = new ArrayList<>(roots);
        orderedRoots.sort((a, b) -> Boolean.compare(containsActive.get(b), containsActive.get(a)));
        
        for (int i = orderedRoots.size() - 1; i >= 0; i--) {
            boolean isLast = i == orderedRoots.size() - 1;
            stack.push(new Object[]{
                orderedRoots.get(i),
                multipleRoots ? 1 : 0,
                multipleRoots,
                multipleRoots,
                isLast,
                new ArrayList<Gutter>(),
                multipleRoots
            });
        }
        
        while (!stack.isEmpty()) {
            Object[] item = stack.pop();
            TreeNode node = (TreeNode) item[0];
            int indent = (Integer) item[1];
            boolean justBranched = (Boolean) item[2];
            boolean showConnector = (Boolean) item[3];
            boolean isLast = (Boolean) item[4];
            List<Gutter> gutters = (List<Gutter>) item[5];
            boolean isVirtualRootChild = (Boolean) item[6];
            
            result.add(new FlatNode(node, indent, showConnector, isLast, gutters, isVirtualRootChild, multipleRoots));
            
            List<TreeNode> children = node.children;
            boolean multipleChildren = children.size() > 1;
            
            // Order children (active branch first)
            List<TreeNode> orderedChildren = new ArrayList<>(children);
            orderedChildren.sort((a, b) -> Boolean.compare(containsActive.get(b), containsActive.get(a)));
            
            // Calculate child indent (matches tree-selector.ts)
            int childIndent;
            if (multipleChildren) {
                // Parent branches: children get +1
                childIndent = indent + 1;
            } else if (justBranched && indent > 0) {
                // First generation after a branch: +1 for visual grouping
                childIndent = indent + 1;
            } else {
                // Single-child chain: stay flat
                childIndent = indent;
            }
            
            // Build gutters for children
            boolean connectorDisplayed = showConnector && !isVirtualRootChild;
            int currentDisplayIndent = multipleRoots ? Math.max(0, indent - 1) : indent;
            int connectorPosition = Math.max(0, currentDisplayIndent - 1);
            List<Gutter> childGutters = new ArrayList<>(gutters);
            if (connectorDisplayed) {
                childGutters.add(new Gutter(connectorPosition, !isLast));
            }
            
            // Add children in reverse order for stack
            for (int i = orderedChildren.size() - 1; i >= 0; i--) {
                boolean childIsLast = i == orderedChildren.size() - 1;
                stack.push(new Object[]{
                    orderedChildren.get(i),
                    childIndent,
                    multipleChildren,
                    multipleChildren,
                    childIsLast,
                    childGutters,
                    false
                });
            }
        }
        
        return result;
    }
    
    private static boolean markActive(TreeNode node, Set<String> activePathIds, Map<TreeNode, Boolean> containsActive) {
        boolean has = activePathIds.contains(node.entry.id);
        for (TreeNode child : node.children) {
            if (markActive(child, activePathIds, containsActive)) {
                has = true;
            }
        }
        containsActive.put(node, has);
        return has;
    }
    
    /**
     * Build ASCII prefix string for tree node.
     */
    private static String buildTreePrefix(FlatNode flatNode) {
        int indent = flatNode.indent;
        boolean showConnector = flatNode.showConnector;
        boolean isLast = flatNode.isLast;
        List<Gutter> gutters = flatNode.gutters;
        boolean isVirtualRootChild = flatNode.isVirtualRootChild;
        boolean multipleRoots = flatNode.multipleRoots;
        
        int displayIndent = multipleRoots ? Math.max(0, indent - 1) : indent;
        String connector = showConnector && !isVirtualRootChild ? (isLast ? "└─ " : "├─ ") : "";
        int connectorPosition = connector.isEmpty() ? -1 : displayIndent - 1;
        
        int totalChars = displayIndent * 3;
        StringBuilder prefixChars = new StringBuilder();
        for (int i = 0; i < totalChars; i++) {
            int level = i / 3;
            int posInLevel = i % 3;
            
            Gutter gutter = null;
            for (Gutter g : gutters) {
                if (g.position == level) {
                    gutter = g;
                    break;
                }
            }
            
            if (gutter != null) {
                prefixChars.append(posInLevel == 0 ? (gutter.show ? "│" : " ") : " ");
            } else if (!connector.isEmpty() && level == connectorPosition) {
                if (posInLevel == 0) {
                    prefixChars.append(isLast ? "└" : "├");
                } else if (posInLevel == 1) {
                    prefixChars.append("─");
                } else {
                    prefixChars.append(" ");
                }
            } else {
                prefixChars.append(" ");
            }
        }
        return prefixChars.toString();
    }
    
    // ============================================================
    // FILTERING (pure data)
    // ============================================================
    
    private static String filterMode = "default";
    private static String searchQuery = "";
    
    private static boolean hasTextContent(Object content) {
        if (content instanceof String) {
            return !((String) content).trim().isEmpty();
        }
        if (content instanceof List) {
            for (Object c : (List<?>) content) {
                if (c instanceof Map) {
                    Map<String, Object> map = (Map<String, Object>) c;
                    if ("text".equals(map.get("type")) && map.containsKey("text") && 
                        map.get("text") instanceof String && 
                        !((String) map.get("text")).trim().isEmpty()) {
                        return true;
                    }
                }
            }
        }
        return false;
    }
    
    private static String extractContent(Object content) {
        if (content instanceof String) {
            return (String) content;
        }
        if (content instanceof List) {
            StringBuilder sb = new StringBuilder();
            for (Object c : (List<?>) content) {
                if (c instanceof Map) {
                    Map<String, Object> map = (Map<String, Object>) c;
                    if ("text".equals(map.get("type")) && map.containsKey("text") && map.get("text") instanceof String) {
                        sb.append((String) map.get("text"));
                    }
                }
            }
            return sb.toString();
        }
        return "";
    }
    
    private static String getSearchableText(Entry entry, String label) {
        List<String> parts = new ArrayList<>();
        if (label != null) {
            parts.add(label);
        }
        
        switch (entry.type) {
            case "message": {
                JsonNode msg = entry.message;
                parts.add(msg.get("role").asText());
                if (msg.has("content")) {
                    parts.add(extractContent(msg.get("content")));
                }
                if ("bashExecution".equals(msg.get("role").asText()) && msg.has("command")) {
                    parts.add(msg.get("command").asText());
                }
                break;
            }
            case "custom_message":
                parts.add(entry.customType);
                parts.add(entry.content instanceof String ? (String) entry.content : extractContent(entry.content));
                break;
            case "compaction":
                parts.add("compaction");
                break;
            case "branch_summary":
                parts.add("branch summary");
                parts.add(entry.summary);
                break;
            case "model_change":
                parts.add("model");
                parts.add(entry.modelId);
                break;
            case "thinking_level_change":
                parts.add("thinking");
                parts.add(entry.thinkingLevel);
                break;
        }
        
        return String.join(" ", parts).toLowerCase();
    }
    
    /**
     * Filter flat nodes based on current filterMode and searchQuery.
     */
    private static List<FlatNode> filterNodes(List<FlatNode> flatNodes, String currentLeafId) {
        String[] searchTokens = searchQuery.toLowerCase().split("\\s+");
        List<FlatNode> filtered = new ArrayList<>();
        
        for (FlatNode flatNode : flatNodes) {
            Entry entry = flatNode.node.entry;
            String label = flatNode.node.label;
            boolean isCurrentLeaf = entry.id.equals(currentLeafId);
            
            // Always show current leaf
            if (isCurrentLeaf) {
                filtered.add(flatNode);
                continue;
            }
            
            // Hide assistant messages with only tool calls (no text) unless error/aborted
            if ("message".equals(entry.type) && entry.message.get("role").asText().equals("assistant")) {
                JsonNode msg = entry.message;
                boolean hasText = hasTextContent(msg.get("content"));
                boolean isErrorOrAborted = msg.has("stopReason") && 
                    !"stop".equals(msg.get("stopReason").asText()) && 
                    !"toolUse".equals(msg.get("stopReason").asText());
                if (!hasText && !isErrorOrAborted) {
                    continue;
                }
            }
            
            // Apply filter mode
            List<String> settingsEntries = Arrays.asList("label", "custom", "model_change", "thinking_level_change");
            boolean isSettingsEntry = settingsEntries.contains(entry.type);
            boolean passesFilter = true;
            
            switch (filterMode) {
                case "user-only":
                    passesFilter = "message".equals(entry.type) && "user".equals(entry.message.get("role").asText());
                    break;
                case "no-tools":
                    passesFilter = !isSettingsEntry && !("message".equals(entry.type) && "toolResult".equals(entry.message.get("role").asText()));
                    break;
                case "labeled-only":
                    passesFilter = label != null;
                    break;
                case "all":
                    passesFilter = true;
                    break;
                default: // 'default'
                    passesFilter = !isSettingsEntry;
                    break;
            }
            
            if (!passesFilter) {
                continue;
            }
            
            // Apply search filter
            if (searchTokens.length > 0) {
                String nodeText = getSearchableText(entry, label);
                boolean matches = true;
                for (String token : searchTokens) {
                    if (!nodeText.contains(token)) {
                        matches = false;
                        break;
                    }
                }
                if (!matches) {
                    continue;
                }
            }
            
            filtered.add(flatNode);
        }
        
        // Recalculate visual structure based on visible tree
        recalculateVisualStructure(filtered, flatNodes);
        
        return filtered;
    }
    
    /**
     * Recompute indentation/connectors for the filtered view
     *
     * Filtering can hide intermediate entries; descendants attach to the nearest visible ancestor.
     * Keep indentation semantics aligned with flattenTree() so single-child chains don't drift right.
     */
    private static void recalculateVisualStructure(List<FlatNode> filteredNodes, List<FlatNode> allFlatNodes) {
        if (filteredNodes.isEmpty()) {
            return;
        }
        
        Set<String> visibleIds = filteredNodes.stream()
            .map(n -> n.node.entry.id)
            .collect(Collectors.toSet());
        
        // Build entry map for parent lookup (using full tree)
        Map<String, FlatNode> entryMap = new HashMap<>();
        for (FlatNode flatNode : allFlatNodes) {
            entryMap.put(flatNode.node.entry.id, flatNode);
        }
        
        // Find nearest visible ancestor for a node
        java.util.function.Function<String, String> findVisibleAncestor = (nodeId) -> {
            String currentId = entryMap.get(nodeId) != null ? 
                entryMap.get(nodeId).node.entry.parentId : null;
            while (currentId != null) {
                if (visibleIds.contains(currentId)) {
                    return currentId;
                }
                currentId = entryMap.get(currentId) != null ? 
                    entryMap.get(currentId).node.entry.parentId : null;
            }
            return null;
        };
        
        // Build visible tree structure
        Map<String, String> visibleParent = new HashMap<>();
        Map<String, List<String>> visibleChildren = new HashMap<>();
        visibleChildren.put(null, new ArrayList<>()); // root-level nodes
        
        for (FlatNode flatNode : filteredNodes) {
            String nodeId = flatNode.node.entry.id;
            String ancestorId = findVisibleAncestor.apply(nodeId);
            visibleParent.put(nodeId, ancestorId);
            
            if (!visibleChildren.containsKey(ancestorId)) {
                visibleChildren.put(ancestorId, new ArrayList<>());
            }
            visibleChildren.get(ancestorId).add(nodeId);
        }
        
        // Update multipleRoots based on visible roots
        List<String> visibleRootIds = visibleChildren.get(null);
        boolean multipleRoots = visibleRootIds.size() > 1;
        
        // Build a map for quick lookup: nodeId → FlatNode
        Map<String, FlatNode> filteredNodeMap = new HashMap<>();
        for (FlatNode flatNode : filteredNodes) {
            filteredNodeMap.put(flatNode.node.entry.id, flatNode);
        }
        
        // DFS traversal of visible tree, applying same indentation rules as flattenTree()
        // Stack items: [nodeId, indent, justBranched, showConnector, isLast, gutters, isVirtualRootChild]
        Stack<Object[]> stack = new Stack<>();
        
        // Add visible roots in reverse order (to process in forward order via stack)
        for (int i = visibleRootIds.size() - 1; i >= 0; i--) {
            boolean isLast = i == visibleRootIds.size() - 1;
            stack.push(new Object[]{
                visibleRootIds.get(i),
                multipleRoots ? 1 : 0,
                multipleRoots,
                multipleRoots,
                isLast,
                new ArrayList<Gutter>(),
                multipleRoots
            });
        }
        
        while (!stack.isEmpty()) {
            Object[] item = stack.pop();
            String nodeId = (String) item[0];
            int indent = (Integer) item[1];
            boolean justBranched = (Boolean) item[2];
            boolean showConnector = (Boolean) item[3];
            boolean isLast = (Boolean) item[4];
            List<Gutter> gutters = (List<Gutter>) item[5];
            boolean isVirtualRootChild = (Boolean) item[6];
            
            FlatNode flatNode = filteredNodeMap.get(nodeId);
            if (flatNode == null) {
                continue;
            }
            
            // Update this node's visual properties
            flatNode.indent = indent;
            flatNode.showConnector = showConnector;
            flatNode.isLast = isLast;
            flatNode.gutters = gutters;
            flatNode.isVirtualRootChild = isVirtualRootChild;
            flatNode.multipleRoots = multipleRoots;
            
            // Get visible children of this node
            List<String> children = visibleChildren.get(nodeId) != null ? 
                visibleChildren.get(nodeId) : new ArrayList<>();
            boolean multipleChildren = children.size() > 1;
            
            // Calculate child indent using same rules as flattenTree():
            // - Parent branches (multiple children): children get +1
            // - Just branched and indent > 0: children get +1 for visual grouping
            // - Single-child chain: stay flat
            int childIndent;
            if (multipleChildren) {
                childIndent = indent + 1;
            } else if (justBranched && indent > 0) {
                childIndent = indent + 1;
            } else {
                childIndent = indent;
            }
            
            // Build gutters for children (same logic as flattenTree)
            boolean connectorDisplayed = showConnector && !isVirtualRootChild;
            int currentDisplayIndent = multipleRoots ? Math.max(0, indent - 1) : indent;
            int connectorPosition = Math.max(0, currentDisplayIndent - 1);
            List<Gutter> childGutters = new ArrayList<>(gutters);
            if (connectorDisplayed) {
                childGutters.add(new Gutter(connectorPosition, !isLast));
            }
            
            // Add children in reverse order (to process in forward order via stack)
            for (int i = children.size() - 1; i >= 0; i--) {
                boolean childIsLast = i == children.size() - 1;
                stack.push(new Object[]{
                    children.get(i),
                    childIndent,
                    multipleChildren,
                    multipleChildren,
                    childIsLast,
                    childGutters,
                    false
                });
            }
        }
    }
    
    // ============================================================
    // TREE DISPLAY TEXT (pure data -> string)
    // ============================================================
    
    private static String shortenPath(String p) {
        if (p == null) {
            return "";
        }
        if (p.startsWith("/Users/")) {
            String[] parts = p.split("/");
            if (parts.length > 2) {
                return "~" + p.substring(("/Users/" + parts[2]).length());
            }
        }
        if (p.startsWith("/home/")) {
            String[] parts = p.split("/");
            if (parts.length > 2) {
                return "~" + p.substring(("/home/" + parts[2]).length());
            }
        }
        return p;
    }
    
    private static String formatToolCall(String name, Map<String, Object> args) {
        switch (name) {
            case "read": {
                String path = shortenPath(String.valueOf(args.getOrDefault("path", args.get("file_path"))));
                Object offset = args.get("offset");
                Object limit = args.get("limit");
                String display = path;
                if (offset != null || limit != null) {
                    int start = offset != null ? (Integer) offset : 1;
                    String end = limit != null ? String.valueOf(start + (Integer) limit - 1) : "";
                    display += ":" + start + (end.isEmpty() ? "" : "-" + end);
                }
                return "[read: " + display + "]";
            }
            case "write":
                return "[write: " + shortenPath(String.valueOf(args.getOrDefault("path", args.get("file_path")))) + "]";
            case "edit":
                return "[edit: " + shortenPath(String.valueOf(args.getOrDefault("path", args.get("file_path")))) + "]";
            case "bash": {
                String rawCmd = String.valueOf(args.getOrDefault("command", ""));
                String cmd = rawCmd.replaceAll("[\\n\\t]", " ").trim().substring(0, Math.min(50, rawCmd.length()));
                return "[bash: " + cmd + (rawCmd.length() > 50 ? "..." : "") + "]";
            }
            case "grep":
                return "[grep: /" + args.getOrDefault("pattern", "") + "/ in " + shortenPath(String.valueOf(args.getOrDefault("path", "."))) + "]";
            case "find":
                return "[find: " + args.getOrDefault("pattern", "") + " in " + shortenPath(String.valueOf(args.getOrDefault("path", "."))) + "]";
            case "ls":
                return "[ls: " + shortenPath(String.valueOf(args.getOrDefault("path", "."))) + "]";
            default: {
                String argsStr = objectMapper.valueToTree(args).toString().substring(0, Math.min(40, objectMapper.valueToTree(args).toString().length()));
                return "[" + name + ": " + argsStr + (objectMapper.valueToTree(args).toString().length() > 40 ? "..." : "") + "]";
            }
        }
    }
    
    // ============================================================
    // TREE RENDERING (DOM manipulation)
    // ============================================================
    
    private static String currentLeafId;
    private static String currentTargetId;
    private static boolean treeRendered = false;
    
    private static void renderTree(List<Entry> entries, String leafId, String urlTargetId, 
                                 Map<String, Entry> byId, Map<String, Map<String, Object>> toolCallMap, 
                                 Map<String, String> labelMap) {
        List<TreeNode> tree = buildTree(entries, labelMap);
        Set<String> activePathIds = buildActivePathIds(currentLeafId, byId);
        List<FlatNode> flatNodes = flattenTree(tree, activePathIds);
        List<FlatNode> filtered = filterNodes(flatNodes, currentLeafId);
        
        // In a real implementation, you would render to HTML here
        System.out.println("Rendering tree with " + filtered.size() + " nodes");
    }
    
    private static void forceTreeRerender() {
        treeRendered = false;
        // renderTree(); // Would call renderTree again
    }
    
    // ============================================================
    // MESSAGE RENDERING
    // ============================================================
    
    private static String formatTokens(int count) {
        if (count < 1000) {
            return String.valueOf(count);
        }
        if (count < 10000) {
            return String.format("%.1fk", count / 1000.0);
        }
        if (count < 1000000) {
            return Math.round(count / 1000) + "k";
        }
        return String.format("%.1fM", count / 1000000.0);
    }
    
    private static String formatTimestamp(String ts) {
        if (ts == null || ts.isEmpty()) {
            return "";
        }
        LocalDateTime dateTime = LocalDateTime.parse(ts);
        return dateTime.format(DateTimeFormatter.ofPattern("HH:mm:ss"));
    }
    
    private static String replaceTabs(String text) {
        return text.replace("\t", "   ");
    }
    
    /** Safely coerce value to string for display. Returns null if invalid type. */
    private static String str(Object value) {
        if (value instanceof String) {
            return (String) value;
        }
        if (value == null) {
            return "";
        }
        return null;
    }
    
    // ============================================================
    // INITIALIZATION
    // ============================================================
    
    public static void main(String[] args) {
        try {
            JsonNode data = loadData();
            JsonNode headerNode = data.get("header");
            List<Entry> entries = new ArrayList<>();
            for (JsonNode entryNode : data.get("entries")) {
                entries.add(new Entry(entryNode));
            }
            String defaultLeafId = data.get("leafId").asText();
            String systemPrompt = data.has("systemPrompt") ? data.get("systemPrompt").asText() : null;
            // tools and renderedTools would be parsed similarly
            
            // ============================================================
            // URL PARAMETER HANDLING
            // ============================================================
            
            String queryString = System.getenv("QUERY_STRING"); // This would come from the web request
            Map<String, String> urlParams = parseUrlParameters(queryString);
            String urlLeafId = urlParams.get("leafId");
            String urlTargetId = urlParams.get("targetId");
            String leafId = urlLeafId != null ? urlLeafId : defaultLeafId;
            
            // ============================================================
            // DATA STRUCTURES
            // ============================================================
            
            // Entry lookup by ID
            Map<String, Entry> byId = new HashMap<>();
            for (Entry entry : entries) {
                byId.put(entry.id, entry);
            }
            
            // Tool call lookup (toolCallId -> {name, arguments})
            Map<String, Map<String, Object>> toolCallMap = new HashMap<>();
            for (Entry entry : entries) {
                if ("message".equals(entry.type) && entry.message.get("role").asText().equals("assistant")) {
                    JsonNode content = entry.message.get("content");
                    if (content.isArray()) {
                        for (JsonNode block : content) {
                            if ("toolCall".equals(block.get("type").asText())) {
                                Map<String, Object> toolInfo = new HashMap<>();
                                toolInfo.put("name", block.get("name").asText());
                                // In a real implementation, you'd parse the arguments properly
                                toolInfo.put("arguments", new HashMap<>()); 
                                toolCallMap.put(block.get("id").asText(), toolInfo);
                            }
                        }
                    }
                }
            }
            
            // Label lookup (entryId -> label string)
            // Labels are stored in 'label' entries that reference their target via targetId
            Map<String, String> labelMap = new HashMap<>();
            for (Entry entry : entries) {
                if ("label".equals(entry.type) && entry.targetId != null && entry.label != null) {
                    labelMap.put(entry.targetId, entry.label);
                }
            }
            
            // Initialize navigation variables
            currentLeafId = leafId;
            currentTargetId = urlTargetId != null ? urlTargetId : leafId;
            
            // Initial render
            // If URL has targetId, scroll to that specific message; otherwise stay at top
            if (leafId != null) {
                if (urlTargetId != null && byId.containsKey(urlTargetId)) {
                    // Deep link: navigate to leaf and scroll to target message
                    // navigateTo(leafId, "target", urlTargetId);
                } else {
                    // navigateTo(leafId, "none");
                }
            } else if (!entries.isEmpty()) {
                // Fallback: use last entry if no leafId
                // navigateTo(entries.get(entries.size() - 1).id, "none");
            }
            
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
    
    // Helper classes
    private static class TreeNode {
        public Entry entry;
        public List<TreeNode> children;
        public String label;
        
        public TreeNode(Entry entry, List<TreeNode> children, String label) {
            this.entry = entry;
            this.children = children;
            this.label = label;
        }
    }
    
    private static class FlatNode {
        public TreeNode node;
        public int indent;
        public boolean showConnector;
        public boolean isLast;
        public List<Gutter> gutters;
        public boolean isVirtualRootChild;
        public boolean multipleRoots;
        
        public FlatNode(TreeNode node, int indent, boolean showConnector, boolean isLast, 
                       List<Gutter> gutters, boolean isVirtualRootChild, boolean multipleRoots) {
            this.node = node;
            this.indent = indent;
            this.showConnector = showConnector;
            this.isLast = isLast;
            this.gutters = gutters;
            this.isVirtualRootChild = isVirtualRootChild;
            this.multipleRoots = multipleRoots;
        }
    }
    
    private static class Gutter {
        public int position;
        public boolean show;
        
        public Gutter(int position, boolean show) {
            this.position = position;
            this.show = show;
        }
    }
}
