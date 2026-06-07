/********************************************************************
 *  OpenClaw – Runtime‑Event‑System (Core Header)
 *
 *  Dieses Header definiert ein generisches, typ‑sicheres Event‑
 *  Dispatcher‑Modul, das von den verschiedenen OpenClaw‑Komponenten
 *  (Gateway, Node‑Manager, Cron‑Runner, Heartbeat‑Loop usw.) genutzt
 *  werden kann, um entkoppelt Ereignisse auszutauschen.
 ********************************************************************/

#pragma once

#include <chrono>
#include <functional>
#include <memory>
#include <mutex>
#include <queue>
#include <string>
#include <unordered_map>
#include <vector>
#include <typeindex>

namespace openclaw {

using Timestamp = std::chrono::steady_clock::time_point;

/* -------------------------------------------------------------
 *  1️⃣ Event‑Enumeration – nur die tatsächlich gebrauchten Typen
 * ------------------------------------------------------------- */
enum class Event {
    // Core‑Lifecycle
    EVENT_GATEWAY_STARTED,
    EVENT_GATEWAY_SHUTDOWN,
    // Node‑Management
    EVENT_NODE_CONNECTED,
    EVENT_NODE_DISCONNECTED,
    // Cron‑/Task‑Tracking
    EVENT_CRON_RUN_COMPLETED,
    EVENT_TASK_COMPLETED,
    // Monitoring
    EVENT_HEARTBEAT_MISSING,
    // (weitere können beliebig ergänzt werden)
};

/* -------------------------------------------------------------
 *  2️⃣ Payload‑Basisklasse – Polymorphie via std::unique_ptr
 * ------------------------------------------------------------- */
struct PayloadBase {
    virtual ~PayloadBase() = default;
    virtual std::type_index type() const = 0;
};

/* -------------------------------------------------------------
 *  Beispiel‑Payloads – weitere Payload‑Strukturen analog
 * ------------------------------------------------------------- */
struct PayloadGatewayStarted : public PayloadBase {
    std::string name;   // z. B. "gateway‑1"
    int         pid;    // Prozess‑ID des Gateways
    uint16_t    port;   // Listening‑Port (z. B. 51820)

    std::type_index type() const override { return typeid(PayloadGatewayStarted); }
};

struct PayloadNodeConnected : public PayloadBase {
    std::string nodeId;
    std::string ip;
    std::string role;   // "worker", "relay" …

    std::type_index type() const override { return typeid(PayloadNodeConnected); }
};

/* Weitere Payload‑Strukturen können hier ergänzt werden */

/* -------------------------------------------------------------
 *  3️⃣ RuntimeEvent – das eigentliche Event‑Objekt
 * ------------------------------------------------------------- */
struct RuntimeEvent {
    Event                 type;
    Timestamp             ts;      // Erzeugungszeitpunkt
    std::unique_ptr<PayloadBase> payload; // nullptr für PayloadNone

    RuntimeEvent(Event t, std::unique_ptr<PayloadBase> p = nullptr)
        : type(t), ts(std::chrono::steady_clock::now()), payload(std::move(p)) {}
};

/* -------------------------------------------------------------
 *  4️⃣ Fabrik‑Hilfsfunktionen (optional, aber sehr praktisch)
 * ------------------------------------------------------------- */
inline RuntimeEvent makeGatewayStartedEvent(const PayloadGatewayStarted& data) {
    return RuntimeEvent(Event::EVENT_GATEWAY_STARTED,
                        std::make_unique<PayloadGatewayStarted>(data));
}

inline RuntimeEvent makeNodeConnectedEvent(const PayloadNodeConnected& data) {
    return RuntimeEvent(Event::EVENT_NODE_CONNECTED,
                        std::make_unique<PayloadNodeConnected>(data));
}

/* -------------------------------------------------------------
 *  5️⃣ Thread‑sicherer Dispatcher (deklariert, Implementierung in
 *      runtime_event.cpp)
 * ------------------------------------------------------------- */
class EventDispatcher {
public:
    using Listener = std::function<void(const RuntimeEvent&)>;

    // Listener‑Registrierung
    void addListener(Event ev, Listener cb);

    // Event in die interne Queue stellen (Standard‑Priorität 10)
    void enqueue(RuntimeEvent ev, int priority = 10);

    // Alle wartenden Events verarbeiten – Aufruf im Haupt‑Loop
    void dispatchAll();

private:
    std::mutex mutex_;
    // einfache FIFO‑Queue; Priorität kann später erweitert werden
    std::queue<RuntimeEvent> queue_;
    std::unordered_map<Event, std::vector<Listener>> listeners_;
};

} // namespace openclaw
