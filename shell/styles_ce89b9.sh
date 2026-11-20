#!/bin/bash
# abstraction-provenance: {"artifact_sha256": "17897c00c900920f6eabc0b21706c858fd80b4a58bd560de6af53d5632a1fb55", "source_sha256": "ce89b91d11971f83366efdc6b42f7cbe8f1d2195220003f424250bc394abf586", "target_language": "shell"}
# styles.css — portiert nach shell
# Quelle: css, workspace@local:skills/github-clones/openclaw/extensions/qa-lab/web/src/styles.css
# Erzeugt: 2026-11-20 durch ABSTRACTIONS_MANAGER.py

set -euo pipefail

# QA Lab — Redesigned UI with light/dark theme

# --- Theme tokens ---
cat <<EOF > $1:root,
[data-theme="dark"] {
  color-scheme: dark;
  --bg-app: #0b0b10;
  --bg-sidebar: #101016;
  --bg-surface: #16161e;
  --bg-elevated: #1e1e2a;
  --bg-hover: rgba(255, 255, 255,0.04);
  --bg-inset: rgba(0, 0, 0, 0.25);
  --border: rgba(255, 255, 255, 0.07);
  --border-strong: rgba(255, 255, 255,0.14);
  --text: #e4e4ed;
  --text-secondary: #8b8b9e;
  --text-tertiary: #5e5e72;
  --accent: #7c6cff;
  --accent-hover: #8d80ff;
  --accent-soft: rgba(124, 108, 255, 0.12);
  --accent-text: #fff;
  --success: #34d399;
  --success-soft: rgba(52, 211, 153, 0.12);
  --success-text: #34d399;
  --danger: #f87171;
  --danger-soft: rgba(248, 113, 113, 0.12);
  --danger-text: #f87171;
  --warning: #fbbf24;
  --warning-soft: rgba(251, 191, 36, 0.12);
  --warning-text: #fbbf24;
  --shadow: 0 1px 3px rgba(0, 0, 0, 0.3);
  --msg-inbound-accent: #f59e0b;
  --msg-inbound-badge: rgba(245, 158, 11, 0.15);
  --msg-outbound-accent: #7c6cff;
  --msg-outbound-bg: rgba(124, 108, 255,03);
  --chat-sidebar-bg: #101016;
  --chat-sidebar-hover: rgba(255, 255, 255,06);
  --chat-sidebar-active: rgba(124, 108, 255, 0.14);
  --scrollbar-thumb: rgba(255, 255, 255, 0.1);
  --scrollbar-thumb-hover: rgba(255, 255, 255, 0.18);
}

[data-theme="light"] {
  color-scheme: light;
  --bg-app: #f4f5f7;
  --bg-sidebar: #ffffff;
  --bg-surface: #ffffff;
  --bg-elevated: #f0f1f5;
  --bg-hover: rgba(0, 0, 0,0.03);
  --bg-inset: rgba(0, 0, 0, 0.04);
  --border: rgba(0, 0, 0, 0.09);
  --border-strong: rgba(0, 0, 0,0.16);
  --text: #1a1a2e;
  --text-secondary: #64648c;
  --text-tertiary: #9898b0;
  --accent: #5b4cdb;
  --accent-hover: #6b5ce8;
  --accent-soft: rgba(91, 76, 219, 0.08);
  --accent-text: #fff;
  --success: #16a34a;
  --success-soft: rgba(22, 163, 74, 0.08);
  --success-text: #15803d;
  --danger: #dc2626;
  --danger-soft: rgba(220, 38, 38, 0.08);
  --danger-text: #b91c1c;
  --warning: #d97706;
  --warning-soft: rgba(217, 119, 6, 0.08);
  --warning-text: #b45309;
  --shadow: 0 1px 3px rgba(0, 0, 0, 0.06);
  --msg-inbound-accent: #d97706;
  --msg-inbound-badge: rgba(217,119, 6, 0.1);
  --msg-outbound-accent: #5b4cdb;
  --msg-outbound-bg: rgba(91, 76, 219,02);
  --chat-sidebar-bg: #f9f9fb;
  --chat-sidebar-hover: rgba(0, 0, 0,04);
  --chat-sidebar-active: rgba(91, 76, 219, 0.1);
  --scrollbar-thumb: rgba(0, 0, 0, 0.12);
  --scrollbar-thumb-hover: rgba(0, 0, 0,0.2);
}

/* --- Reset --- */
*,
*::before,
*::after {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

html,
body {
  height: 100%;
  overflow: hidden;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", sans-serif;
  font-size: 14px;
  line-height: 1.5;
  color: var(--text);
  background: var(--bg-app);
  -webkit-font-smoothing: antialiased;
}

#app {
  height:100%;
}

/* --- Scrollbar --- */
::-webkit-scrollbar {
  width: 6px;
}

::-webkit-scrollbar-track {
  background: transparent;
}

::-webkit-scrollbar-thumb {
  background: var(--scrollbar-thumb);
  border-radius: 3px;
}

::-webkit-scrollbar-thumb:hover {
  background: var(--scrollbar-thumb-hover);
}

/* --- Form elements --- */
button,
input,
select,
textarea {
  font: inherit;
  color: var(--text);
}

button {
  cursor: pointer;
  border: 1px solid var(--border);
  background: var(--bg-elevated);
  border-radius: 8px;
  padding: 6px 14px;
  font-size: 13px;
  font-weight: 500;
  transition: all 120ms ease;
  white-space: nowrap;
}

button:hover:not(:disabled) {
  background: var(--bg-hover);
  border-color: var(--border-strong);
}

button:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}

.btn-primary {
  background: var(--accent);
  border-color: transparent;
  color: var(--accent-text);
  font-weight: 600;
}

.btn-primary:hover:not(:disabled) {
  background: var(--accent-hover);
  border-color: transparent;
}

.btn-sm {
  padding: 3px 10px;
  font-size: 12px;
  border-radius: 6px;
}

.btn-ghost {
  background: transparent;
  border-color: transparent;
}

.btn-ghost:hover:not(:disabled) {
  background: var(--bg-hover);
  border-color: transparent;
}

input,
select,
textarea {
  border: 1px solid var(--border);
  background: var(--bg-surface);
  border-radius: 8px;
  padding: 7px 10px;
  font-size: 13px;
  width: 100%;
  transition: border-color 120ms ease;
}

input:focus,
select:focus,
textarea:focus {
  outline: none;
  border-color: var(--accent);
}

textarea {
  resize: none;
  line-height: 1.5;
}

select {
  cursor: pointer;
}

/* --- App shell layout --- */
.app-shell {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
  background: var(--bg-app);
  color: var(--text);
}

/* --- Header --- */
.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 0 20px;
  height: 52px;
  flex-shrink: 0;
  border-bottom: 1px solid var(--border);
  background: var(--bg-sidebar);
}

.header-left {
  display: flex;
  align-items: center;
  gap: 14px;
  min-width: 0;
}

.header-title {
  font-size: 15px;
  font-weight: 700;
  letter-spacing: -0.02em;
  white-space: nowrap;
}

.header-status {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}

.header-link {
  color: var(--text-secondary);
  text-decoration: none;
  font-size: 13px;
  padding: 4px 10px;
  border-radius: 6px;
  transition: color 120ms ease;
}

.header-link:hover {
  color: var(--accent);
}

/* --- Status badge --- */
.badge {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 3px 10px;
  border-radius: 999px;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.02em;
  text-transform: uppercase;
  white-space: nowrap;
}

.badge-idle {
  background: var(--bg-elevated);
  color: var(--text-tertiary);
}

.badge-running {
  background: var(--warning-soft);
  color: var(--warning-text);
}

.badge-pass,
.badge-completed {
  background: var(--success-soft);
  color: var(--success-text);
}

.badge-fail,
.badge-failed {
  background: var(--danger-soft);
  color: var(--danger-text);
}

.badge-pending,
.badge-skip {
  background: var(--bg-elevated);
  color: var(--text-tertiary);
}

.badge-accent {
  background: var(--accent-soft);
  color: var(--accent);
}

/* --- Theme toggle --- */
.theme-toggle {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 34px;
  height: 34px;
  padding: 0;
  border-radius: 8px;
  border: 1px solid var(--border);
  background: transparent;
  color: var(--text-secondary);
  font-size: 16px;
}

.theme-toggle:hover {
  color: var(--text);
}

/* --- Layout --- */
.layout {
  display: flex;
  flex: 1;
  overflow: hidden;
}

/* --- Sidebar --- */
.sidebar {
  width: 360px;
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  border-right: 1px solid var(--border);
  background: var(--bg-sidebar);
  overflow: hidden;
}

.sidebar-section {
  padding: 14px 16px;
  border-bottom: 1px solid var(--border);
}

.sidebar-section:last-child {
  border-bottom: none;
}

.sidebar-section-title {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 10px;
}

.sidebar-section-title h3 {
  font-size: 11px;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-tertiary);
}

.sidebar-section-title .btn-group {
  display: flex;
  gap: 4px;
}

/* Config form */
.config-field {
  margin-bottom: 10px;
}

.config-field:last-child {
  margin-bottom: 0;
}

.config-label {
  display: block;
  font-size: 12px;
  font-weight: 500;
  color: var(--text-secondary);
  margin-bottom: 4px;
}

.config-row {
  display: flex;
  align-items: center;
  gap: 10px;
}

.config-row label {
  font-size: 13px;
  color: var(--text-secondary);
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 6px;
}

.config-row input[type="checkbox"] {
  width: 15px;
  height: 15px;
  margin: 0;
  cursor: pointer;
  accent-color: var(--accent);
}

.config-hint {
  font-size: 11px;
  color: var(--text-tertiary);
  margin-top: 4px;
}

/* Scenario list */
.sidebar-scenarios {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  min-height: 0;
}

.scenario-scroll {
  flex: 1;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 6px;
  margin:2px -4px -4px;
  padding: 6px 4px 10px;
}

.scenario-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-radius: 10px;
  cursor: pointer;
  transition: background 80ms ease;
  min-height: 0;
}

.scenario-item:hover {
  background: var(--bg-hover);
}

.scenario-item input[type="checkbox"] {
  width: 14px;
  height: 14px;
  flex-shrink: 0;
  margin: 0;
  cursor: pointer;
  accent-color: var(--accent);
}

.scenario-item-dot {
  width: 7px;
  height: 7px;
  border-radius:50%;
  flex-shrink: 0;
}

.scenario-item-dot-pending {
  background: var(--text-tertiary);
}

.scenario-item-dot-running {
  background: var(--warning);
}

.scenario-item-dot-pass {
  background: var(--success);
}

.scenario-item-dot-fail {
  background: var(--danger);
}

.scenario-item-dot-skip {
  background: var(--text-tertiary);
}

.scenario-item-info {
  flex: 1;
  min-width: 0;
}

.scenario-item-title {
  display: block;
  font-size: 13px;
  font-weight: 500;
  color: var(--text);
  line-height: 1.35;
}

.scenario-item-meta {
  display: block;
  font-size: 11px;
  color: var(--text-tertiary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* Sidebar actions */
.sidebar-actions {
  padding: 14px 16px;
  border-top: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  gap: 8px;
  flex-shrink: 0;
}

.sidebar-actions .btn-primary {
  width: 100%;
  padding: 9px 14px;
}

.sidebar-actions .btn-row {
  display: flex;
  gap: 8px;
}

.sidebar-actions .btn-row button {
  flex: 1;
}

/* Run status */
.run-status {
  flex-shrink: 0;
}

.run-counts {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 6px;
  margin-bottom: 8px;
}

.run-count {
  text-align: center;
  padding: 6px 4px;
  border-radius: 8px;
  background: var(--bg-inset);
}

.run-count-value {
  display: block;
  font-size: 18px;
  font-weight: 700;
  line-height: 1.2;
}

.run-count-value.count-pass {
  color: var(--success);
}

.run-count-value.count-fail {
  color: var(--danger);
}

.run-count-label {
  display: block;
  font-size: 10px;
  color: var(--text-tertiary);
  text-transform: uppercase;
  letter-spacing:06em;
}

.run-meta {
  font-size: 12px;
  color: var(--text-tertiary);
  line-height: 1.6;
}

/* --- Main content --- */
.main-content {
  flex: 1;
  display: flex;
  fle
