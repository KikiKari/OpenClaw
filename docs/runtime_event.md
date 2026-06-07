# runtime_event.md

## Overview
The `runtime_event` module provides a type‑safe, central event system for OpenClaw. It defines a set of core events, payload structures, a `RuntimeEvent` container and a thread‑safe `EventDispatcher`.

## Core Event Enum
```cpp
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
};
```

## Payload Structures
- `PayloadGatewayStarted` – name, pid, port.
- `PayloadNodeConnected` – nodeId, ip, role.
- `PayloadNodeDisconnected` – nodeId, reason.
- `PayloadCronRunCompleted` – jobId, success.
- `PayloadTaskCompleted` – taskId, result.
- `PayloadHeartbeatMissing` – optional timestamp (payload may be nullptr).

All payloads inherit from `PayloadBase` and implement `std::type_index type() const`.

## Creating Events (Factory helpers)
```cpp
RuntimeEvent makeGatewayStartedEvent(const PayloadGatewayStarted& data);
RuntimeEvent makeNodeConnectedEvent(const PayloadNodeConnected& data);
```
(Additional `make…` helpers exist for every event.)

## Dispatching
```cpp
openclaw::EventDispatcher dispatcher;
dispatcher.enqueue(event);          // thread‑safe enqueue
dispatcher.dispatchAll();           // process all pending events
```

## Listener Registration
```cpp
dispatcher.addListener(Event::EVENT_GATEWAY_STARTED,
    [](const RuntimeEvent& ev) {
        const auto* p = dynamic_cast<const PayloadGatewayStarted*>(ev.payload.get());
        if (p) LOG_INFO("Gateway %s (pid %d) started on port %u",
                        p->name.c_str(), p->pid, p->port);
    });
```
Listeners are registered once (usually during initialization) and will be called for each matching event.

## Priority Handling (optional)
`enqueue(event, priority)` can be used where:
- `0` = critical (node loss, gateway shutdown)
- `5` = cron errors
- `10` = normal task completions
- `20` = informational events (e.g., `EVENT_GATEWAY_STARTED`)

Future versions may replace the FIFO queue with a `std::priority_queue`.

## Usage Example (Main loop)
```cpp
while (running) {
    // … OpenClaw work …
    dispatcher.dispatchAll();   // handle queued events
    std::this_thread::sleep_for(std::chrono::seconds(1));
}
```

## Integration Points
- **Gateway** – emit `EVENT_GATEWAY_STARTED` / `EVENT_GATEWAY_SHUTDOWN`.
- **Node‑Manager** – emit `EVENT_NODE_CONNECTED` / `EVENT_NODE_DISCONNECTED`.
- **Cron‑Runner** – emit `EVENT_CRON_RUN_COMPLETED`.
- **Task‑Executor** – emit `EVENT_TASK_COMPLETED`.
- **Heartbeat** – emit `EVENT_HEARTBEAT_MISSING` when a heartbeat is missed.

## Documentation
For full API details see `src/common/runtime_event.hpp` and `runtime_event.cpp`.
