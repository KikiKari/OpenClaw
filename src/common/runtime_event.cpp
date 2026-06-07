#include "runtime_event.hpp"

namespace openclaw {

/* -------------------------------------------------------------
 *  EventDispatcher – Implementierung
 * ------------------------------------------------------------- */

void EventDispatcher::addListener(Event ev, Listener cb) {
    std::lock_guard<std::mutex> lock(mutex_);
    listeners_[ev].push_back(std::move(cb));
}

void EventDispatcher::enqueue(RuntimeEvent ev, int /*priority*/) {
    // Für die aktuelle Implementierung ignorieren wir die Priorität
    // und verwenden eine FIFO‑Queue.  Eine Prioritäts‑Queue kann später
    // leicht ergänzt werden, indem man hier std::priority_queue nutzt.
    std::lock_guard<std::mutex> lock(mutex_);
    queue_.push(std::move(ev));
}

void EventDispatcher::dispatchAll() {
    std::queue<RuntimeEvent> local;
    {
        std::lock_guard<std::mutex> lock(mutex_);
        std::swap(local, queue_);
    }
    while (!local.empty()) {
        const RuntimeEvent &ev = local.front();
        auto it = listeners_.find(ev.type);
        if (it != listeners_.end()) {
            for (auto &fn : it->second) {
                fn(ev);
            }
        }
        local.pop();
    }
}

} // namespace openclaw
