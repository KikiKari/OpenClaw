// abstraction-provenance: {"artifact_sha256": "acc75c3197347a083ffe6ee4809de2bf79fce48ff9025de00dd4c6fad9e81436", "source_sha256": "95f62a3e3f38308dd9be80e09ec85e4a14455ab95457febb8f915c0f54685141", "target_language": "java"}
// test_model_usage.py — portiert nach java
// Quelle: python, workspace@local:skills/github-clones/openclaw/skills/model-usage/scripts/test_model_usage.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import static org.junit.jupiter.api.Assertions.*;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.stream.Collectors;

public class TestModelUsage {

    @Test
    @DisplayName("test_positive_int_accepts_valid_numbers")
    public void testPositiveIntAcceptsValidNumbers() {
        assertEquals(1, ModelUsage.positiveInt("1"));
        assertEquals(7, ModelUsage.positiveInt("7"));
    }

    @Test
    @DisplayName("test_positive_int_rejects_zero_and_negative")
    public void testPositiveIntRejectsZeroAndNegative() {
        assertThrows(IllegalArgumentException.class, () -> {
            ModelUsage.positiveInt("0");
        });
        assertThrows(IllegalArgumentException.class, () -> {
            ModelUsage.positiveInt("-3");
        });
    }

    @Test
    @DisplayName("test_filter_by_days_keeps_recent_entries")
    public void testFilterByDaysKeepsRecentEntries() {
        LocalDate today = LocalDate.now();
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd");
        
        List<Map<String, Object>> entries = new ArrayList<>();
        
        Map<String, Object> entry1 = new HashMap<>();
        entry1.put("date", today.minusDays(5).format(formatter));
        entry1.put("modelBreakdowns", new ArrayList<>());
        entries.add(entry1);
        
        Map<String, Object> entry2 = new HashMap<>();
        entry2.put("date", today.minusDays(1).format(formatter));
        entry2.put("modelBreakdowns", new ArrayList<>());
        entries.add(entry2);
        
        Map<String, Object> entry3 = new HashMap<>();
        entry3.put("date", today.format(formatter));
        entry3.put("modelBreakdowns", new ArrayList<>());
        entries.add(entry3);

        List<Map<String, Object>> filtered = ModelUsage.filterByDays(entries, 2);

        assertEquals(2, filtered.size());
        assertEquals(today.minusDays(1).format(formatter), filtered.get(0).get("date"));
        assertEquals(today.format(formatter), filtered.get(1).get("date"));
    }
}
