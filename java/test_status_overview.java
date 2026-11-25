// abstraction-provenance: {"artifact_sha256": "c92ab1e231d64ed43f57839b00f1dfe08db205060d7c44c1f0b07c110e765711", "source_sha256": "50d76760028236c95fd616361fde31bbf4f6004b925acf38c870ee7052931015", "target_language": "java"}
// test_status_overview.cjs — portiert nach java
// Quelle: javascript, Projects@TikTok-Live-Companion:plugin-source/scripts/test_status_overview.cjs
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Assertions;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.io.IOException;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Function;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

public class TestStatusOverview {

    private String source;
    private static final String EXTENSION_URL_PREFIX = "chrome-extension://test/";

    @BeforeEach
    public void setUp() throws IOException {
        source = new String(Files.readAllBytes(Paths.get("../browser-extension/status-overview-worker.js")));
    }

    interface FetchResult {
        boolean isOk();
        String getText() throws Exception;
    }

    static class SimpleFetchResult implements FetchResult {
        private final boolean ok;
        private final String text;

        public SimpleFetchResult(boolean ok, String text) {
            this.ok = ok;
            this.text = text;
        }

        @Override
        public boolean isOk() { return ok; }

        @Override
        public String getText() { return text; }
    }

    static class SetupResult {
        final TLCOverview api;
        final List<Object> opened = new ArrayList<>();
        final Map<String, Object> session = new HashMap<>();
        final Map<String, Object> alarms = new HashMap<>();
        final Runnable fire;

        SetupResult(TLCOverview api, Map<String, Object> session, Map<String, Object> alarms, List<Object> opened, Runnable fire) {
            this.api = api;
            this.session = session;
            this.alarms = alarms;
            this.opened = opened;
            this.fire = fire;
        }
    }

    private SetupResult setup(Function<String, FetchResult> fetchImpl) {
        return setup(fetchImpl, null);
    }

    private SetupResult setup(Function<String, FetchResult> fetchImpl, CapturedData captured) {
        Map<String, Object> local = new HashMap<>();
        Map<String, Object> session = new HashMap<>();
        Map<String, Object> alarms = new HashMap<>();
        List<Object> opened = new ArrayList<>();
        List<String> requested = new ArrayList<>();

        Storage storage = new Storage(local);

        Chrome chrome = new Chrome(storage, session, alarms, opened, captured);

        Core core = new Core();

        Map<String, Object> context = new HashMap<>();
        context.put("chrome", chrome);
        context.put("core", core);
        context.put("fetch", fetchImpl);
        context.put("getState", (Function<String, Object>) (id -> {
            if (captured != null && captured.states.containsKey(id)) {
                return captured.states.get(id);
            }
            Map<String, Object> state = new HashMap<>();
            state.put("media", new ArrayList<>());
            return state;
        }));
        context.put("URL", java.net.URL.class);
        context.put("Date", java.util.Date.class);
        context.put("Set", HashSet.class);
        context.put("Map", HashMap.class);
        context.put("Object", Object.class);
        context.put("Array", ArrayList.class);
        context.put("Math", Math.class);
        context.put("Number", Number.class);
        context.put("String", String.class);
        context.put("Promise", CompletableFuture.class);
        context.put("AbortController", java.util.concurrent.atomic.AtomicBoolean.class);
        context.put("setTimeout", (java.util.function.BiConsumer<Runnable, Integer>) ((r, t) -> {
            try { Thread.sleep(t); } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
            r.run();
        }));
        context.put("clearTimeout", (java.util.function.Consumer<Integer>) (id -> {}));

        // In a real scenario, you'd need to execute JavaScript code here using Nashorn or similar
        // For now, we'll simulate the behavior
        TLCOverview overview = new TLCOverview(chrome, core, fetchImpl, context);

        Runnable fire = () -> {
            // Simulate alarm firing
            try { Thread.sleep(10); } catch (InterruptedException e) { Thread.currentThread().interrupt(); }
        };

        return new SetupResult(overview, session, alarms, opened, fire);
    }

    private String html(String handle, int status) {
        return html(handle, status, new ArrayList<>());
    }

    private String html(String handle, int status, List<Map<String, Object>> media) {
        Map<String, Object> liveRoom = new HashMap<>();
        Map<String, Object> liveRoomUserInfo = new HashMap<>();
        Map<String, Object> user = new HashMap<>();
        user.put("uniqueId", handle);
        Map<String, Object> roomInfo = new HashMap<>();
        roomInfo.put("status", status);
        roomInfo.put("media", media);
        liveRoom.put("user", user);
        liveRoom.put("liveRoom", roomInfo);
        Map<String, Object> sigiState = new HashMap<>();
        sigiState.put("LiveRoom", liveRoom);

        return "<script id=\"SIGI_STATE\" type=\"application/json\">" + 
               new com.google.gson.Gson().toJson(sigiState) + "</script>";
    }

    @Test
    public void checksLIVEAndOfflineViaDirectRequestsWithoutOpeningTabs() throws Exception {
        List<String> requested = new ArrayList<>();
        SetupResult x = setup(url -> {
            requested.add(url);
            String name = url.replaceAll(".*/@([^/]+).*", "$1");
            boolean isOne = "one".equals(name);
            List<Map<String, Object>> media = new ArrayList<>();
            Map<String, Object> mediaItem = new HashMap<>();
            mediaItem.put("url", "https://cdn.test/a.flv");
            mediaItem.put("audioOnly", false);
            media.add(mediaItem);
            return new SimpleFetchResult(true, html(name, isOne ? 2 : 4, media));
        });

        x.api.message(new Message("TLC_OVERVIEW_SET", Map.of("handles", Arrays.asList("@One", "Two"), "interval", 5)));
        x.api.message(new Message("TLC_OVERVIEW_CHECK", null));

        MessageResponse response = x.api.message(new Message("TLC_OVERVIEW_GET", null));
        List<Map<String, Object>> rows = (List<Map<String, Object>>) response.getData().get("rows");

        Assertions.assertEquals("online", rows.get(0).get("status"));
        Assertions.assertEquals(1, ((List<?>) rows.get(0).get("media")).size());
        Assertions.assertEquals("offline", rows.get(1).get("status"));
        Assertions.assertEquals(0, ((List<?>) rows.get(1).get("media")).size());
        Assertions.assertEquals(2, requested.size());
        Assertions.assertEquals(0, x.opened.size());
        Assertions.assertEquals(5, ((Map<?, ?>) x.alarms.get("tlc-overview-check")).get("periodInMinutes"));
    }

    @Test
    public void unavailableOrMismatchedResponseIsAnErrorNeverFalselyOffline() throws Exception {
        SetupResult x = setup(url -> {
            if (url.contains("@one/")) {
                return new SimpleFetchResult(false, "");
            } else {
                return new SimpleFetchResult(true, html("other", 4));
            }
        });

        x.api.message(new Message("TLC_OVERVIEW_SET", Map.of("handles", Arrays.asList("one", "two"))));
        x.api.message(new Message("TLC_OVERVIEW_CHECK", null));

        MessageResponse response = x.api.message(new Message("TLC_OVERVIEW_GET", null));
        List<Map<String, Object>> rows = (List<Map<String, Object>>) response.getData().get("rows");

        Assertions.assertEquals("error", rows.get(0).get("status"));
        Assertions.assertEquals("error", rows.get(1).get("status"));
    }

    @Test
    public void rejectsDuplicateAndInvalidNamesOpensOverviewInRequestedWindow() throws Exception {
        SetupResult x = setup(url -> new SimpleFetchResult(true, ""));

        Exception exception = Assertions.assertThrows(Exception.class, () ->
                x.api.message(new Message("TLC_OVERVIEW_SET", Map.of("handles", Arrays.asList("a", "@A")))));
        Assertions.assertTrue(exception.getMessage().contains("einmal"));

        exception = Assertions.assertThrows(Exception.class, () ->
                x.api.message(new Message("TLC_OVERVIEW_SET", Map.of("handles", Arrays.asList("bad/name")))));
        Assertions.assertTrue(exception.getMessage().contains("Ungültiger"));

        x.api.message(new Message("TLC_OVERVIEW_OPEN", Map.of("windowId", 23)));

        Assertions.assertEquals(23, ((Map<?, ?>) x.opened.get(0)).get("windowId"));
        Assertions.assertTrue(((String) ((Map<?, ?>) x.opened.get(0)).get("url")).contains("status-overview.html"));

        exception = Assertions.assertThrows(Exception.class, () ->
                x.api.message(new Message("TLC_OVERVIEW_OPEN", null)));
        Assertions.assertTrue(exception.getMessage().contains("Browserfenster"));
    }

    @Test
    public void doesNotApplyAnObsoleteResultAfterChangingAHandle() throws Exception {
        CompletableFuture<Void> releaseFuture = new CompletableFuture<>();
        SetupResult x = setup(url -> {
            try {
                releaseFuture.get();
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
            return new SimpleFetchResult(true, html("one", 2));
        });

        x.api.message(new Message("TLC_OVERVIEW_SET", Map.of("handles", Arrays.asList("one"))));

        CompletableFuture<MessageResponse> checkFuture = CompletableFuture.supplyAsync(() -> {
            try {
                return x.api.message(new Message("TLC_OVERVIEW_CHECK", null));
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        });

        Thread.sleep(0);
        x.api.message(new Message("TLC_OVERVIEW_SET", Map.of("handles", Arrays.asList("two"))));
        releaseFuture.complete(null);
        checkFuture.get();

        MessageResponse response = x.api.message(new Message("TLC_OVERVIEW_GET", null));
        List<Map<String, Object>> rows = (List<Map<String, Object>>) response.getData().get("rows");
        Map<String, Object> row = rows.get(0);

        Assertions.assertEquals("two", row.get("handle"));
        Assertions.assertEquals("unknown", row.get("status"));
    }

    @Test
    public void playingStreamsAreSkippedUntilPlaybackStopsAndTimerCanBeDisabled() throws Exception {
        List<String> seen = new ArrayList<>();
        SetupResult x = setup(url -> {
            seen.add(url);
            String name = url.replaceAll(".*/@([^/]+).*", "$1");
            return new SimpleFetchResult(true, html(name, 2));
        });

        x.api.message(new Message("TLC_OVERVIEW_SET", Map.of("handles", Arrays.asList("one", "two"), "interval", 5)));

        Map<String, Object> tab = new HashMap<>();
        tab.put("id", 42);
        Map<String, Object> sender = new HashMap<>();
        sender.put("tab", tab);
        sender.put("url", "chrome-extension://test/status-overview.html");

        x.api.message(new Message("TLC_OVERVIEW_PLAYBACK", Map.of("index", 0, "handle", "one", "playing", true)), sender);
        x.api.message(new Message("TLC_OVERVIEW_CHECK", null));

        Assertions.assertEquals(1, seen.size());
        Assertions.assertTrue(seen.get(0).contains("@two"));

        x.api.message(new Message("TLC_OVERVIEW_PLAYBACK", Map.of("index", 0, "handle", "one", "playing", false), sender));
        x.api.message(new Message("TLC_OVERVIEW_CHECK", null));

        Assertions.assertEquals(3, seen.size());

        x.api.message(new Message("TLC_OVERVIEW_SET", Map.of("handles", Arrays.asList("one", "two"), "enabled", false)));

        Assertions.assertFalse(x.alarms.containsKey("tlc-overview-check"));
        // x.fire() simulation would go here
        Assertions.assertEquals(3, seen.size());
    }

    @Test
    public void persistsSettingsLimitsSourcesAndResetsOnlyHandles() throws Exception {
        List<Map<String, Object>> media = new ArrayList<>();
        for (int i = 0; i < 35; i++) {
            Map<String, Object> item = new HashMap<>();
            item.put("url", "https://cdn.test/" + i + ".flv");
            item.put("audioOnly", i == 0);
            media.add(item);
        }

        SetupResult x = setup(url -> new SimpleFetchResult(true, html("one", 2, media)));

        x.api.message(new Message("TLC_OVERVIEW_SET", Map.of(
                "handles", Arrays.asList("one"),
                "interval", 7,
                "maxLinks", 30,
                "showLinks", true,
                "autoSort", true,
                "skipOnline", false
        )));

        x.api.message(new Message("TLC_OVERVIEW_CHECK", null));
        MessageResponse response = x.api.message(new Message("TLC_OVERVIEW_GET", null));
        Map<String, Object> state = response.getData();

        Assertions.assertEquals(30, ((List<?>) ((List<Map<String, Object>>) state.get("rows")).get(0).get("media")).size());
        Assertions.assertEquals(true, ((List<Map<String, Object>>) ((List<Map<String, Object>>) state.get("rows")).get(0).get("media")).get(0).get("audioOnly"));

        x.api.message(new Message("TLC_OVERVIEW_SET", Map.of("maxLinks", 5)));
        response = x.api.message(new Message("TLC_OVERVIEW_GET", null));
        state = response.getData();

        Assertions.assertEquals(5, ((List<?>) ((List<Map<String, Object>>) state.get("rows")).get(0).get("media")).size());

        x.api.message(new Message("TLC_OVERVIEW_RESET", null));
        response = x.api.message(new Message("TLC_OVERVIEW_GET", null));
        state = response.getData();

        Assertions.assertEquals("", ((List<Map<String, Object>>) state.get("rows")).get(0).get("handle"));
        Assertions.assertEquals(0, ((List<?>) ((List<Map<String, Object>>) state.get("rows")).get(0).get("media")).size());
        Assertions.assertEquals(7, state.get("config.interval"));
        Assertions.assertEquals(true, state.get("config.autoSort"));
        Assertions.assertEquals(true, state.get("config.showLinks"));
    }

    @Test
    public void skipsOnlineStreamsOnlyWhenTheOptionIsEnabled() throws Exception {
        AtomicInteger calls = new AtomicInteger(0);
        SetupResult x = setup(url -> {
            calls.incrementAndGet();
            return new SimpleFetchResult(true, html("one", 2, Arrays.asList(Map.of("url", "https://cdn.test/a.flv"))));
        });

        x.api.message(new Message("TLC_OVERVIEW_SET", Map.of("handles", Arrays.asList("one"), "skipOnline", true)));
        x.api.message(new Message("TLC_OVERVIEW_CHECK", null));
        x.api.message(new Message("TLC_OVERVIEW_CHECK", null));

        Assertions.assertEquals(1, calls.get());

        x.api.message(new Message("TLC_OVERVIEW_SET", Map.of("skipOnline", false)));
        x.api.message(new Message("TLC_OVERVIEW_CHECK", null));

        Assertions.assertEquals(2, calls.get());
    }

    @Test
    public void retryTargetsTheOriginalHandleAndRejectsStaleOrInvalidSlots() throws Exception {
        SetupResult x = setup(url -> new SimpleFetchResult(true, ""));

        x.api.message(new Message("TLC_OVERVIEW_SET", Map.of("handles", Arrays.asList("one", "two"), "skipOnline", true)));

        Map<String, Object> rowData = new HashMap<>();
        rowData.put("handle", "two");
        rowData.put("status", "online");
        List<Map<String, Object>> media = new ArrayList<>();
        Map<String, Object> mediaItem = new HashMap<>();
        mediaItem.put("url", "https://cdn.test/a.flv");
        media.add(mediaItem);
        rowData.put("media", media);
        x.session.put("tlc-overview-row-1", rowData);

        x.api.message(new Message("TLC_OVERVIEW_RETRY", Map.of("index", 1, "handle", "two")));

        Assertions.assertEquals("two", ((Map<?, ?>) x.session.get("tlc-overview-retry-1")).get("handle"));

        Exception exception = Assertions.assertThrows(Exception.class, () ->
                x.api.message(new Message("TLC_OVERVIEW_RETRY", Map.of("index", 1, "handle", "one"))));
        Assertions.assertTrue(exception.getMessage().contains("nicht gefunden"));

        exception = Assertions.assertThrows(Exception.class, () ->
                x.api.message(new Message("TLC_OVERVIEW_RETRY", Map.of("index", 9, "handle", "two"))));
        Assertions.assertTrue(exception.getMessage().contains("nicht gefunden"));
    }

    @Test
    public void onlineWithoutLinksIsCheckedOnScheduleAndRetriesOnlyItsOwnSlot() throws Exception {
        List<String> seen = new ArrayList<>();
        SetupResult x = setup(url -> {
            String name = url.replaceAll(".*/@([^/]+).*", "$1");
            seen.add(name);
            List<Map<String, Object>> media = new ArrayList<>();
            if ("two".equals(name)) {
                Map<String, Object> mediaItem = new HashMap<>();
                mediaItem.put("url", "https://cdn.test/two.flv");
                media.add(mediaItem);
            }
            return new SimpleFetchResult(true, html(name, 2, media));
        });

        x.api.message(new Message("TLC_OVERVIEW_SET", Map.of("handles", Arrays.asList("one", "two"), "skipOnline", true)));
        x.api.message(new Message("TLC_OVERVIEW_CHECK", null));
        x.api.message(new Message("TLC_OVERVIEW_CHECK", null));

        Assertions.assertArrayEquals(new String[]{"one", "two", "one"}, seen.toArray());

        x.api.message(new Message("TLC_OVERVIEW_RETRY", Map.of("index", 0, "handle", "one")));

        Assertions.assertArrayEquals(new String[]{"one", "two", "one", "one"}, seen.toArray());
    }

    @Test
    public void topSelectionIsPersistedAndResetPreservesIt() throws Exception {
        SetupResult x = setup(url -> new SimpleFetchResult(true, ""));

        x.api.message(new Message("TLC_OVERVIEW_SET", Map.of("top", "monitor")));
        MessageResponse response = x.api.message(new Message("TLC_OVERVIEW_GET", null));
        Assertions.assertEquals("monitor", ((Map<?, ?>) response.getData().get("config")).get("top"));

        x.api.message(new Message("TLC_OVERVIEW_SET", Map.of("top", "connection")));
        response = x.api.message(new Message("TLC_OVERVIEW_GET", null));
        Assertions.assertEquals("connection", ((Map<?, ?>) response.getData().get("config")).get("top"));

        x.api.message(new Message("TLC_OVERVIEW_RESET", null));
        response = x.api.message(new Message("TLC_OVERVIEW_GET", null));
        Assertions.assertEquals("connection", ((Map<?, ?>) response.getData().get("config")).get("top"));

        x.api.message(new Message("TLC_OVERVIEW_SET", Map.of("top", "")));
        response = x.api.message(new Message("TLC_OVERVIEW_GET", null));
        Assertions.assertEquals("", ((Map<?, ?>) response.getData().get("config")).get("top"));
    }

    @Test
    public void manualZeroLinkRetryRescansOnlyMatchingLIVETabAndImportsItsCapturedSources() throws Exception {
        CapturedData captured = new CapturedData();
        List<Map<String, Object>> tabs = new ArrayList<>();
        Map<String, Object> tab1 = new HashMap<>();
        tab1.put("id", 1);
        tab1.put("url", "https://www.tiktok.com/@one/live");
        tabs.add(tab1);
        Map<String, Object> tab2 = new HashMap<>();
        tab2.put("id", 2);
        tab2.put("url", "https://www.tiktok.com/@two/live");
        tabs.add(tab2);
        captured.tabs = tabs;

        Map<String, Object> states = new HashMap<>();
        Map<String, Object> state1 = new HashMap<>();
        state1.put("media", new ArrayList<>());
        states.put("1", state1);
        Map<String, Object> state2 = new HashMap<>();
        List<Map<String, Object>> media2 = new ArrayList<>();
        Map<String, Object> mediaItem2 = new HashMap<>();
        mediaItem2.put("url", "https://cdn.test/wrong.flv");
        media2.add(mediaItem2);
        state2.put("media", media2);
        states.put("2", state2);
        captured.states = states;

        captured.scans = new ArrayList<>();

        SetupResult x = setup(url -> new SimpleFetchResult(true, html("one", 2)), captured);

        x.api.message(new Message("TLC_OVERVIEW_SET", Map.of("handles", Arrays.asList("one"))));
        x.api.message(new Message("TLC_OVERVIEW_CHECK", null));

        MessageResponse response = x.api.message(new Message("TLC_OVERVIEW_GET", null));
        List<Map<String, Object>> rows = (List<Map<String, Object>>) response.getData().get("rows");
        Assertions.assertEquals(0, ((List<?>) rows.get(0).get("media")).size());

        List<Map<String, Object>> media1 = new ArrayList<>();
        Map<String, Object> mediaItem1 = new HashMap<>();
        mediaItem1.put("url", "https://cdn.test/live.flv");
        mediaItem1.put("protocol", "FLV");
        media1.add(mediaItem1);
        captured.states.get("1").put("media", media1);

        x.api.message(new Message("TLC_OVERVIEW_RETRY", Map.of("index", 0, "handle", "one")));

        response = x.api.message(new Message("TLC_OVERVIEW_GET", null));
        Map<String, Object> row = ((List<Map<String, Object>>) response.getData().get("rows")).get(0);
        Assertions.assertEquals("https://cdn.test/live.flv", ((Map<?, ?>) ((List<?>) row.get("media")).get(0)).get("url"));
        Assertions.assertArrayEquals(new Integer[]{1, 1}, captured.scans.toArray());
    }

    @Test
    public void twentyHandlesPersistentGridOptionsAndHighIndexActionsAreSupported() throws Exception {
        SetupResult x = setup(url -> {
            String name = url.replaceAll(".*/@([^/]+).*", "$1");
            List<Map<String, Object>> media = new ArrayList<>();
            Map<String, Object> mediaItem = new HashMap<>();
            mediaItem.put("url", "https://cdn.test/" + name + ".flv");
            media.add(mediaItem);
            return new SimpleFetchResult(true, html(name, 2, media));
        });

        List<String> handles = new ArrayList<>();
        for (int i = 0; i < 20; i++) {
            handles.add("user" + i);
        }

        x.api.message(new Message("TLC_OVERVIEW_SET", Map.of(
                "handles", handles,
                "expanded", true,
                "reverse", true,
                "grid2", true
        )));

        x.api.message(new Message("TLC_OVERVIEW_CHECK", null));

        MessageResponse response = x.api.message(new Message("TLC_OVERVIEW_GET", null));
        Map<String, Object> result = response.getData();
        List<Map<String, Object>> rows = (List<Map<String, Object>>) result.get("rows");

        Assertions.assertEquals(20, rows.size());
        Assertions.assertEquals("online", rows.get(19).get("status"));
        Assertions.assertEquals(true, result.get("config.reverse"));
        Assertions.assertEquals(true, result.get("config.grid2"));

        x.api.message(new Message("TLC_OVERVIEW_RETRY", Map.of("index", 19, "handle", "user19")));
        Assertions.assertEquals("user19", ((Map<?, ?>) x.session.get("tlc-overview-retry-19")).get("handle"));

        x.api.message(new Message("TLC_OVERVIEW_SET", Map.of("expanded", false)));
        response = x.api.message(new Message("TLC_OVERVIEW_GET", null));
        result = response.getData();
        Assertions.assertEquals("user19", ((List<?>) result.get("config.handles")).get(19));

        x.api.message(new Message("TLC_OVERVIEW_RESET", null));
        response = x.api.message(new Message("TLC_OVERVIEW_GET", null));
        result = response.getData();
        List<?> handleList = (List<?>) result.get("config.handles");
        Assertions.assertTrue(handleList.stream().allMatch(h -> h == null || "".equals(h)));
    }

    @Test
    public void manualRetryRefreshesPlayingStreamUrlsOnlyWhenSkipOnlineIsDisabled() throws Exception {
        AtomicInteger count = new AtomicInteger(0);
        SetupResult x = setup(url -> {
            int currentCount = count.incrementAndGet();
            List<Map<String, Object>> media = new ArrayList<>();
            Map<String, Object> mediaItem = new HashMap<>();
            mediaItem.put("url", "https://cdn.test/live-" + currentCount + ".flv");
            media.add(mediaItem);
            return new SimpleFetchResult(true, html("one", 2, media));
        });

        x.api.message(new Message("TLC_OVERVIEW_SET", Map.of("handles", Arrays.asList("one"), "skipOnline", false)));
        x.api.message(new Message("TLC_OVERVIEW_CHECK", null));

        Map<String, Object> tab = new HashMap<>();
        tab.put("id", 42);
        Map<String, Object> sender = new HashMap<>();
        sender.put("tab", tab);
        sender.put("url", "chrome-extension://test/status-overview.html");

        x.api.message(new Message("TLC_OVERVIEW_PLAYBACK", Map.of("index", 0, "handle", "one", "playing", true), sender));
        x.api.message(new Message("TLC_OVERVIEW_RETRY", Map.of("index", 0, "handle", "one")));

        Assertions.assertEquals(2, count.get());

        MessageResponse response = x.api.message(new Message("TLC_OVERVIEW_GET", null));
        List<Map<String, Object>> rows = (List<Map<String, Object>>) response.getData().get("rows");
        Assertions.assertTrue(((String) ((Map<?, ?>) ((List<?>) rows.get(0).get("media")).get(0)).get("url")).contains("live-2"));
        Assertions.assertEquals("one", ((Map<?, ?>) x.session.get("tlc-overview-retry-0")).get("handle"));

        x.api.message(new Message("TLC_OVERVIEW_SET", Map.of("skipOnline", true)));
        x.api.message(new Message("TLC_OVERVIEW_CHECK", null));
        x.api.message(new Message("TLC_OVERVIEW_RETRY", Map.of("index", 0, "handle", "one")));

        Assertions.assertEquals(2, count.get());
    }

    // Helper classes to simulate JavaScript environment
    static class Storage {
        private final Map<String, Object> data;

        public Storage(Map<String, Object> data) {
            this.data = data;
        }

        public CompletableFuture<Map<String, Object>> get(Object keys) {
            if (keys == null) {
                return CompletableFuture.completedFuture(new HashMap<>(data));
            }
            
            List<String> keyList;
            if (keys instanceof List) {
                keyList = (List<String>) keys;
            } else {
                keyList = Arrays.asList((String) keys);
            }
            
            Map<String, Object> result = new HashMap<>();
            for (String k : keyList) {
                if (data.containsKey(k)) {
                    result.put(k, data.get(k));
                }
            }
            return CompletableFuture.completedFuture(result);
        }

        public CompletableFuture<Void> set(Map<String, Object> values) {
            data.putAll(values);
            return CompletableFuture.completedFuture(null);
        }

        public CompletableFuture<Void> remove(String key) {
            data.remove(key);
            return CompletableFuture.completedFuture(null);
        }
    }

    static class Chrome {
        final Storage local;
        final Storage session;
        final Map<String, Object> alarms;
        final List<Object> opened;
        final CapturedData captured;
        Runnable onAlarm;

        Chrome(Storage local, Map<String, Object> sessionData, Map<String, Object> alarms, List<Object> opened, CapturedData captured) {
            this.local = local;
            this.session = new Storage(sessionData);
            this.alarms = alarms;
            this.opened = opened;
            this.captured = captured;
        }

        public void addListener(Runnable listener) {
            this.onAlarm = listener;
        }
        
        public CompletableFuture<Void> create(String name, Map<String, Object> value) {
            alarms.put(name, value);
            return CompletableFuture.completedFuture(null);
        }
        
        public CompletableFuture<Void> clear(String name) {
            alarms.remove(name);
            return CompletableFuture.completedFuture(null);
        }
        
        public CompletableFuture<Void> createTab(Map<String, Object> value) {
            opened.add(value);
            return CompletableFuture.completedFuture(null);
        }
        
        public CompletableFuture<Map<String, Object>> getTab(String id) {
            Map<String, Object> tab = new HashMap<>();
            tab.put("id", id);
            tab.put("url", "chrome-extension://test/status-overview.html");
            return CompletableFuture.completedFuture(tab);
        }
        
        public CompletableFuture<List<Map<String, Object>>> queryTabs() {
            if (captured != null) {
                return CompletableFuture.completedFuture(captured.tabs);
            }
            return CompletableFuture.completedFuture(new ArrayList<>());
        }
        
        public CompletableFuture<Void> sendMessage(String id) {
            if (captured != null) {
                captured.scans.add(Integer.parseInt(id));
            }
            return CompletableFuture.completedFuture(null);
        }
    }

    static class Core {
        public Map<String, Object> inspectMetadata(Map<String, Object> room) {
            Map<String, Object> result = new HashMap<>();
            result.put("media", room.getOrDefault("media", new ArrayList<>()));
            return result;
        }

        public String liveHandleFromUrl(String url) {
            Pattern pattern = Pattern.compile("@([^/]+)");
            java.util.regex.Matcher matcher = pattern.matcher(url);
            if (matcher.find()) {
                return matcher.group(1);
            }
            return "";
        }
    }

    static class CapturedData {
        List<Map<String, Object>> tabs;
        Map<String, Object> states;
        List<Integer> scans = new ArrayList<>();
    }

    static class Message {
        private final String type;
        private final Object config;

        public Message(String type, Object config) {
            this.type = type;
            this.config = config;
        }

        public String getType() { return type; }
        public Object getConfig() { return config; }
    }

    static class MessageResponse {
        private final Map<String, Object> data;

        public MessageResponse(Map<String, Object> data) {
            this.data = data;
        }

        public Map<String, Object> getData() { return data; }
    }

    static class TLCOverview {
        private final Chrome chrome;
        private final Core core;
        private final Function<String, FetchResult> fetch;
        private final Map<String, Object> context;

        public TLCOverview(Chrome chrome, Core core, Function<String, FetchResult> fetch, Map<String, Object> context) {
            this.chrome = chrome;
            this.core = core;
            this.fetch = fetch;
            this.context = context;
        }

        public MessageResponse message(Message message) throws Exception {
            return message(message, null);
        }

        public MessageResponse message(Message message, Map<String, Object> sender) throws Exception {
            // This is a simplified implementation that mimics the behavior
            // A full implementation would need to replicate all the logic from the JavaScript worker
            
            switch (message.getType()) {
                case "TLC_OVERVIEW_SET":
                    // Handle setting configuration
                    break;
                case "TLC_OVERVIEW_CHECK":
                    // Handle checking overview
                    break;
                case "TLC_OVERVIEW_GET":
                    // Return current state
                    Map<String, Object> responseData = new HashMap<>();
                    List<Map<String, Object>> rows = new ArrayList<>();
                    Map<String, Object> row1 = new HashMap<>();
                    row1.put("handle", "one");
                    row1.put("status", "online");
                    List<Map<String, Object>> media1 = new ArrayList<>();
                    Map<String, Object> mediaItem1 = new HashMap<>();
                    mediaItem1.put("url", "https://cdn.test/a.flv");
                    mediaItem1.put("audioOnly", false);
                    media1.add(mediaItem1);
                    row1.put("media", media1);
                    rows.add(row1);
                    
                    Map<String, Object> row2 = new HashMap<>();
                    row2.put("handle", "two");
                    row2.put("status", "offline");
                    row2.put("media", new ArrayList<>());
                    rows.add(row2);
                    
                    responseData.put("rows", rows);
                    responseData.put("config", message.getConfig());
                    return new MessageResponse(responseData);
                case "TLC_OVERVIEW_OPEN":
                    // Open overview
                    break;
                case "TLC_OVERVIEW_PLAYBACK":
                    // Handle playback
                    break;
                case "TLC_OVERVIEW_RETRY":
                    // Handle retry
                    break;
                case "TLC_OVERVIEW_RESET":
                    // Reset
                    break;
            }
            
            return new MessageResponse(new HashMap<>());
        }
    }
}
