// abstraction-provenance: {"artifact_sha256": "f2a7be527eca8274ef8683cf09101d7d6d6f98f77bac6cfb9c92807d8e82112e", "source_sha256": "5e833080809c70bbbe1eee5fa14d9d07d639ca0b16c37253625f4dc46ca1e64f", "target_language": "cpp"}
// model_usage.py — portiert nach cpp
// Quelle: python, workspace@local:skills/github-clones/openclaw/skills/model-usage/scripts/model_usage.py
// Erzeugt: 2026-11-26 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <string>
#include <vector>
#include <map>
#include <optional>
#include <fstream>
#include <sstream>
#include <stdexcept>
#include <algorithm>
#include <chrono>
#include <iomanip>
#include <nlohmann/json.hpp>

using json = nlohmann::json;

struct ModelCost {
    std::string model;
    double cost;
};

struct CurrentResult {
    std::string provider;
    std::string mode = "current";
    std::string model;
    std::optional<std::string> latestModelDate;
    std::optional<double> totalCostUSD;
    std::optional<double> latestDayCostUSD;
    std::optional<std::string> latestDayCostDate;
    int dailyRowCount;
};

struct AllResult {
    std::string provider;
    std::string mode = "all";
    std::vector<ModelCost> models;
};

void eprint(const std::string& msg) {
    std::cerr << msg << std::endl;
}

std::string exec(const std::string& cmd) {
    std::array<char, 128> buffer;
    std::string result;
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd.c_str(), "r"), pclose);
    if (!pipe) {
        throw std::runtime_error("popen() failed!");
    }
    while (fgets(buffer.data(), buffer.size(), pipe.get()) != nullptr) {
        result += buffer.data();
    }
    return result;
}

std::vector<json> run_codexbar_cost(const std::string& provider) {
    std::string cmd = "codexbar cost --format json --provider " + provider;
    try {
        std::string output = exec(cmd);
        json payload = json::parse(output);
        if (!payload.is_array()) {
            throw std::runtime_error("Expected codexbar cost JSON array.");
        }
        return payload;
    } catch (const std::exception& e) {
        throw std::runtime_error(std::string("codexbar cost failed: ") + e.what());
    }
}

json load_payload(const std::optional<std::string>& input_path, const std::string& provider) {
    json data;
    if (input_path.has_value()) {
        if (input_path.value() == "-") {
            std::ostringstream oss;
            oss << std::cin.rdbuf();
            data = json::parse(oss.str());
        } else {
            std::ifstream file(input_path.value());
            std::stringstream buffer;
            buffer << file.rdbuf();
            data = json::parse(buffer.str());
        }
    } else {
        auto list_data = run_codexbar_cost(provider);
        for (const auto& entry : list_data) {
            if (entry.contains("provider") && entry["provider"] == provider) {
                return entry;
            }
        }
        throw std::runtime_error("Provider '" + provider + "' not found in codexbar payload.");
    }

    if (data.is_object()) {
        return data;
    }

    if (data.is_array()) {
        for (const auto& entry : data) {
            if (entry.is_object() && entry.contains("provider") && entry["provider"] == provider) {
                return entry;
            }
        }
        throw std::runtime_error("Provider '" + provider + "' not found in codexbar payload.");
    }

    throw std::runtime_error("Unsupported JSON input format.");
}

std::vector<json> parse_daily_entries(const json& payload) {
    std::vector<json> result;
    if (payload.contains("daily") && payload["daily"].is_array()) {
        for (const auto& entry : payload["daily"]) {
            if (entry.is_object()) {
                result.push_back(entry);
            }
        }
    }
    return result;
}

std::optional<std::tm> parse_date(const std::string& value) {
    std::tm tm = {};
    std::istringstream ss(value);
    ss >> std::get_time(&tm, "%Y-%m-%d");
    if (ss.fail()) {
        return std::nullopt;
    }
    return tm;
}

std::vector<json> filter_by_days(const std::vector<json>& entries, const std::optional<int>& days) {
    if (!days.has_value()) {
        return entries;
    }

    auto now = std::chrono::system_clock::now();
    auto days_ago = now - std::chrono::hours(24 * (days.value() - 1));
    auto cutoff_time_t = std::chrono::system_clock::to_time_t(days_ago);
    std::tm cutoff_tm = *std::localtime(&cutoff_time_t);

    std::vector<json> filtered;
    for (const auto& entry : entries) {
        if (!entry.contains("date") || !entry["date"].is_string()) {
            continue;
        }
        auto parsed_opt = parse_date(entry["date"]);
        if (!parsed_opt.has_value()) {
            continue;
        }
        auto parsed = parsed_opt.value();
        if (std::mktime(&parsed) >= std::mktime(&cutoff_tm)) {
            filtered.push_back(entry);
        }
    }
    return filtered;
}

std::map<std::string, double> aggregate_costs(const std::vector<json>& entries) {
    std::map<std::string, double> totals;
    for (const auto& entry : entries) {
        if (!entry.contains("modelBreakdowns") || !entry["modelBreakdowns"].is_array()) {
            continue;
        }
        for (const auto& item : entry["modelBreakdowns"]) {
            if (!item.is_object() || 
                !item.contains("modelName") || !item["modelName"].is_string() ||
                !item.contains("cost") || !item["cost"].is_number()) {
                continue;
            }
            std::string model = item["modelName"];
            double cost = item["cost"];
            totals[model] += cost;
        }
    }
    return totals;
}

std::pair<std::optional<std::string>, std::optional<std::string>> pick_current_model(const std::vector<json>& entries) {
    if (entries.empty()) {
        return {std::nullopt, std::nullopt};
    }

    std::vector<json> sorted_entries = entries;
    std::sort(sorted_entries.begin(), sorted_entries.end(), [](const json& a, const json& b) {
        std::string date_a = a.contains("date") ? a["date"].get<std::string>() : "";
        std::string date_b = b.contains("date") ? b["date"].get<std::string>() : "";
        return date_a < date_b;
    });

    for (auto it = sorted_entries.rbegin(); it != sorted_entries.rend(); ++it) {
        const auto& entry = *it;
        if (entry.contains("modelBreakdowns") && entry["modelBreakdowns"].is_array() && !entry["modelBreakdowns"].empty()) {
            std::vector<ModelCost> scored;
            for (const auto& item : entry["modelBreakdowns"]) {
                if (!item.is_object() || 
                    !item.contains("modelName") || !item["modelName"].is_string() ||
                    !item.contains("cost") || !item["cost"].is_number()) {
                    continue;
                }
                scored.push_back({item["modelName"], item["cost"]});
            }
            if (!scored.empty()) {
                std::sort(scored.begin(), scored.end(), [](const ModelCost& a, const ModelCost& b) {
                    return a.cost > b.cost;
                });
                std::optional<std::string> date_opt;
                if (entry.contains("date") && entry["date"].is_string()) {
                    date_opt = entry["date"];
                }
                return {scored[0].model, date_opt};
            }
        }
        if (entry.contains("modelsUsed") && entry["modelsUsed"].is_array() && !entry["modelsUsed"].empty()) {
            auto last = entry["modelsUsed"].back();
            if (last.is_string()) {
                std::optional<std::string> date_opt;
                if (entry.contains("date") && entry["date"].is_string()) {
                    date_opt = entry["date"];
                }
                return {last, date_opt};
            }
        }
    }
    return {std::nullopt, std::nullopt};
}

std::string usd(const std::optional<double>& value) {
    if (!value.has_value()) {
        return "—";
    }
    std::ostringstream oss;
    oss << "$" << std::fixed << std::setprecision(2) << value.value();
    return oss.str();
}

std::pair<std::optional<std::string>, std::optional<double>> latest_day_cost(const std::vector<json>& entries, const std::string& model) {
    if (entries.empty()) {
        return {std::nullopt, std::nullopt};
    }

    std::vector<json> sorted_entries = entries;
    std::sort(sorted_entries.begin(), sorted_entries.end(), [](const json& a, const json& b) {
        std::string date_a = a.contains("date") ? a["date"].get<std::string>() : "";
        std::string date_b = b.contains("date") ? b["date"].get<std::string>() : "";
        return date_a < date_b;
    });

    for (auto it = sorted_entries.rbegin(); it != sorted_entries.rend(); ++it) {
        const auto& entry = *it;
        if (!entry.contains("modelBreakdowns") || !entry["modelBreakdowns"].is_array()) {
            continue;
        }
        for (const auto& item : entry["modelBreakdowns"]) {
            if (item.is_object() && item.contains("modelName") && item["modelName"] == model) {
                std::optional<double> cost;
                if (item.contains("cost") && item["cost"].is_number()) {
                    cost = item["cost"];
                }
                std::optional<std::string> day;
                if (entry.contains("date") && entry["date"].is_string()) {
                    day = entry["date"];
                }
                return {day, cost};
            }
        }
    }
    return {std::nullopt, std::nullopt};
}

std::string render_text_current(
    const std::string& provider,
    const std::string& model,
    const std::optional<std::string>& latest_date,
    const std::optional<double>& total_cost,
    const std::optional<double>& latest_cost,
    const std::optional<std::string>& latest_cost_date,
    int entry_count
) {
    std::vector<std::string> lines = {
        "Provider: " + provider,
        "Current model: " + model
    };
    
    if (latest_date.has_value()) {
        lines.push_back("Latest model date: " + latest_date.value());
    }
    lines.push_back("Total cost (rows): " + usd(total_cost));
    if (latest_cost_date.has_value()) {
        lines.push_back("Latest day cost: " + usd(latest_cost) + " (" + latest_cost_date.value() + ")");
    }
    lines.push_back("Daily rows: " + std::to_string(entry_count));
    
    std::string result;
    for (size_t i = 0; i < lines.size(); ++i) {
        result += lines[i];
        if (i < lines.size() - 1) {
            result += "\n";
        }
    }
    return result;
}

std::string render_text_all(const std::string& provider, const std::map<std::string, double>& totals) {
    std::vector<std::pair<std::string, double>> sorted_totals(totals.begin(), totals.end());
    std::sort(sorted_totals.begin(), sorted_totals.end(), [](const auto& a, const auto& b) {
        return a.second > b.second;
    });

    std::string result = "Provider: " + provider + "\nModels:";
    for (const auto& pair : sorted_totals) {
        result += "\n- " + pair.first + ": " + usd(pair.second);
    }
    return result;
}

json build_json_current(
    const std::string& provider,
    const std::string& model,
    const std::optional<std::string>& latest_date,
    const std::optional<double>& total_cost,
    const std::optional<double>& latest_cost,
    const std::optional<std::string>& latest_cost_date,
    int entry_count
) {
    json j;
    j["provider"] = provider;
    j["mode"] = "current";
    j["model"] = model;
    if (latest_date.has_value()) {
        j["latestModelDate"] = latest_date.value();
    } else {
        j["latestModelDate"] = nullptr;
    }
    if (total_cost.has_value()) {
        j["totalCostUSD"] = total_cost.value();
    } else {
        j["totalCostUSD"] = nullptr;
    }
    if (latest_cost.has_value()) {
        j["latestDayCostUSD"] = latest_cost.value();
    } else {
        j["latestDayCostUSD"] = nullptr;
    }
    if (latest_cost_date.has_value()) {
        j["latestDayCostDate"] = latest_cost_date.value();
    } else {
        j["latestDayCostDate"] = nullptr;
    }
    j["dailyRowCount"] = entry_count;
    return j;
}

json build_json_all(const std::string& provider, const std::map<std::string, double>& totals) {
    std::vector<std::pair<std::string, double>> sorted_totals(totals.begin(), totals.end());
    std::sort(sorted_totals.begin(), sorted_totals.end(), [](const auto& a, const auto& b) {
        return a.second > b.second;
    });

    json j;
    j["provider"] = provider;
    j["mode"] = "all";
    j["models"] = json::array();
    
    for (const auto& pair : sorted_totals) {
        json model_entry;
        model_entry["model"] = pair.first;
        model_entry["totalCostUSD"] = pair.second;
        j["models"].push_back(model_entry);
    }
    return j;
}

int main(int argc, char* argv[]) {
    std::string provider = "codex";
    std::string mode = "current";
    std::optional<std::string> model_arg;
    std::optional<std::string> input;
    std::optional<int> days;
    std::string format = "text";
    bool pretty = false;

    // Simple argument parsing
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--provider" && i + 1 < argc) {
            provider = argv[++i];
        } else if (arg == "--mode" && i + 1 < argc) {
            mode = argv[++i];
        } else if (arg == "--model" && i + 1 < argc) {
            model_arg = argv[++i];
        } else if (arg == "--input" && i + 1 < argc) {
            input = argv[++i];
        } else if (arg == "--days" && i + 1 < argc) {
            try {
                days = std::stoi(argv[++i]);
                if (days.value() < 1) {
                    eprint("days must be >= 1");
                    return 1;
                }
            } catch (...) {
                eprint("days must be an integer");
                return 1;
            }
        } else if (arg == "--format" && i + 1 < argc) {
            format = argv[++i];
        } else if (arg == "--pretty") {
            pretty = true;
        }
    }

    try {
        json payload = load_payload(input, provider);
        std::vector<json> entries = parse_daily_entries(payload);
        entries = filter_by_days(entries, days);

        if (mode == "current") {
            std::string model;
            std::optional<std::string> latest_date;
            
            if (model_arg.has_value()) {
                model = model_arg.value();
            } else {
                auto result = pick_current_model(entries);
                model = result.first.value_or("");
                latest_date = result.second;
                if (model.empty()) {
                    eprint("No model data found in codexbar cost payload.");
                    return 2;
                }
            }
            
            auto totals = aggregate_costs(entries);
            std::optional<double> total_cost;
            if (totals.find(model) != totals.end()) {
                total_cost = totals[model];
            }
            
            auto latest_cost_result = latest_day_cost(entries, model);
            std::optional<std::string> latest_cost_date = latest_cost_result.first;
            std::optional<double> latest_cost = latest_cost_result.second;

            if (format == "json") {
                json payload_out = build_json_current(
                    provider,
                    model,
                    latest_date,
                    total_cost,
                    latest_cost,
                    latest_cost_date,
                    static_cast<int>(entries.size())
                );
                if (pretty) {
                    std::cout << payload_out.dump(2) << std::endl;
                } else {
                    std::cout << payload_out.dump() << std::endl;
                }
            } else {
                std::cout << render_text_current(
                    provider,
                    model,
                    latest_date,
                    total_cost,
                    latest_cost,
                    latest_cost_date,
                    static_cast<int>(entries.size())
                ) << std::endl;
            }
            return 0;
        }

        auto totals = aggregate_costs(entries);
        if (totals.empty()) {
            eprint("No model breakdowns found in codexbar cost payload.");
            return 2;
        }

        if (format == "json") {
            json payload_out = build_json_all(provider, totals);
            if (pretty) {
                std::cout << payload_out.dump(2) << std::endl;
            } else {
                std::cout << payload_out.dump() << std::endl;
            }
        } else {
            std::cout << render_text_all(provider, totals) << std::endl;
        }
        return 0;

    } catch (const std::exception& e) {
        eprint(e.what());
        return 1;
    }
}
