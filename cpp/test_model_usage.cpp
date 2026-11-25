// abstraction-provenance: {"artifact_sha256": "3ac5554de4ca533c662528a618dd0d3981ad041b00594283b918f70850635fa7", "source_sha256": "95f62a3e3f38308dd9be80e09ec85e4a14455ab95457febb8f915c0f54685141", "target_language": "cpp"}
// test_model_usage.py — portiert nach cpp
// Quelle: python, workspace@local:skills/github-clones/openclaw/skills/model-usage/scripts/test_model_usage.py
// Erzeugt: 2026-11-25 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <vector>
#include <string>
#include <stdexcept>
#include <chrono>
#include <sstream>
#include <iomanip>
#include <algorithm>
#include <cassert>

// Mocking the model_usage functions we need to test
int positive_int(const std::string& value) {
    int result = std::stoi(value);
    if (result <= 0) {
        throw std::invalid_argument("Value must be positive");
    }
    return result;
}

struct ModelBreakdown {
    // Placeholder for actual model breakdown data
};

struct Entry {
    std::string date;
    std::vector<ModelBreakdown> modelBreakdowns;
};

std::vector<Entry> filter_by_days(const std::vector<Entry>& entries, int days) {
    auto now = std::chrono::system_clock::now();
    auto cutoff_time = now - std::chrono::hours(24 * days);
    
    std::vector<Entry> filtered;
    for (const auto& entry : entries) {
        std::tm tm = {};
        std::istringstream ss(entry.date);
        ss >> std::get_time(&tm, "%Y-%m-%d");
        if (ss.fail()) {
            continue; // Skip invalid dates
        }
        
        auto entry_time = std::chrono::system_clock::from_time_t(std::mktime(&tm));
        if (entry_time >= cutoff_time) {
            filtered.push_back(entry);
        }
    }
    
    // Sort by date (ascending)
    std::sort(filtered.begin(), filtered.end(), [](const Entry& a, const Entry& b) {
        return a.date < b.date;
    });
    
    return filtered;
}

// Test framework implementation
class TestCase {
public:
    virtual void run() = 0;
    virtual std::string getName() const = 0;
    int getFailures() const { return failures; }
    
protected:
    int failures = 0;
    
    template<typename T, typename U>
    void assertEqual(const T& expected, const U& actual, const std::string& msg = "") {
        if (expected != actual) {
            std::cerr << "Assertion failed: " << msg << " Expected: " << expected << ", Got: " << actual << std::endl;
            failures++;
        }
    }
    
    template<typename T>
    void assertThrows(const std::function<void()>& func, const std::string& msg = "") {
        try {
            func();
            std::cerr << "Expected exception but none was thrown: " << msg << std::endl;
            failures++;
        } catch (...) {
            // Exception was thrown as expected
        }
    }
};

class TestModelUsage : public TestCase {
public:
    std::string getName() const override {
        return "TestModelUsage";
    }
    
    void test_positive_int_accepts_valid_numbers() {
        assertEqual(1, positive_int("1"), "positive_int should accept '1'");
        assertEqual(7, positive_int("7"), "positive_int should accept '7'");
    }
    
    void test_positive_int_rejects_zero_and_negative() {
        assertThrows([]() { positive_int("0"); }, "positive_int should reject '0'");
        assertThrows([]() { positive_int("-3"); }, "positive_int should reject '-3'");
    }
    
    void test_filter_by_days_keeps_recent_entries() {
        auto today = std::chrono::system_clock::now();
        std::time_t tt = std::chrono::system_clock::to_time_t(today);
        std::tm* tm = std::localtime(&tt);
        
        char buffer[11];
        strftime(buffer, sizeof(buffer), "%Y-%m-%d", tm);
        std::string today_str(buffer);
        
        auto yesterday = today - std::chrono::hours(24);
        tt = std::chrono::system_clock::to_time_t(yesterday);
        tm = std::localtime(&tt);
        strftime(buffer, sizeof(buffer), "%Y-%m-%d", tm);
        std::string yesterday_str(buffer);
        
        auto five_days_ago = today - std::chrono::hours(24*5);
        tt = std::chrono::system_clock::to_time_t(five_days_ago);
        tm = std::localtime(&tt);
        strftime(buffer, sizeof(buffer), "%Y-%m-%d", tm);
        std::string five_days_ago_str(buffer);
        
        std::vector<Entry> entries = {
            {five_days_ago_str, {}},
            {yesterday_str, {}},
            {today_str, {}}
        };
        
        auto filtered = filter_by_days(entries, 2);
        
        assertEqual(size_t(2), filtered.size(), "Filtered entries should contain 2 elements");
        if (filtered.size() >= 2) {
            assertEqual(yesterday_str, filtered[0].date, "First entry should be from yesterday");
            assertEqual(today_str, filtered[1].date, "Second entry should be from today");
        }
    }
    
    void run() override {
        test_positive_int_accepts_valid_numbers();
        test_positive_int_rejects_zero_and_negative();
        test_filter_by_days_keeps_recent_entries();
    }
};

int main() {
    TestModelUsage test;
    test.run();
    
    if (test.getFailures() == 0) {
        std::cout << "All tests passed!" << std::endl;
        return 0;
    } else {
        std::cerr << "Tests failed with " << test.getFailures() << " failures." << std::endl;
        return 1;
    }
}
