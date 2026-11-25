<?php
// abstraction-provenance: {"artifact_sha256": "0523d02465245b6cfeb7be33aeadace99b09baa4df58ee4682a95b97cc4194ad", "source_sha256": "95f62a3e3f38308dd9be80e09ec85e4a14455ab95457febb8f915c0f54685141", "target_language": "php"}
// test_model_usage.py — portiert nach php
// Quelle: python, workspace@local:skills/github-clones/openclaw/skills/model-usage/scripts/test_model_usage.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py
/**
 * Tests for model_usage helpers.
 */

require_once 'model_usage.php';

class TestModelUsage extends PHPUnit\Framework\TestCase {
    public function test_positive_int_accepts_valid_numbers() {
        $this->assertEquals(positive_int("1"), 1);
        $this->assertEquals(positive_int("7"), 7);
    }

    public function test_positive_int_rejects_zero_and_negative() {
        $this->expectException(InvalidArgumentException::class);
        positive_int("0");
        
        $this->expectException(InvalidArgumentException::class);
        positive_int("-3");
    }

    public function test_filter_by_days_keeps_recent_entries() {
        $today = new DateTime();
        $entries = [
            ["date" => $today->sub(new DateInterval('P5D'))->format('Y-m-d'), "modelBreakdowns" => []],
            ["date" => $today->add(new DateInterval('P4D'))->format('Y-m-d'), "modelBreakdowns" => []],
            ["date" => $today->add(new DateInterval('P1D'))->format('Y-m-d'), "modelBreakdowns" => []],
        ];

        $filtered = filter_by_days($entries, 2);

        $this->assertCount(2, $filtered);
        $this->assertEquals($filtered[0]["date"], $today->sub(new DateInterval('P1D'))->format('Y-m-d'));
        $this->assertEquals($filtered[1]["date"], $today->add(new DateInterval('P1D'))->format('Y-m-d'));
    }
}

?>
