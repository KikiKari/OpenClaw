<?php
// abstraction-provenance: {"artifact_sha256": "77bcb2aea496ebee469e714746f0b84977e6789d7b7d7940efbb1726792de1bc", "source_sha256": "be7071091b8a4e461f665879c436317756f6591f0bcf132f78e03c8b0bb8eb0d", "target_language": "php"}
// grouped.css — portiert nach php
// Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat/grouped.css
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py
class GroupedCSSGenerator {
    private $cssRules = [];
    
    public function __construct() {
        $this->initializeCSSRules();
    }
    
    private function initializeCSSRules() {
        // Chat Group Layout - default (assistant/other on left)
        $this->cssRules['.chat-group'] = [
            'display' => 'flex',
            'gap' => '10px',
            'align-items' => 'flex-start',
            'margin-bottom' => '14px',
            'margin-left' => '4px',
            'margin-right' => '16px'
        ];

        // User messages on right
        $this->cssRules['.chat-group.user'] = [
            'flex-direction' => 'row-reverse',
            'justify-content' => 'flex-start'
        ];

        $this->cssRules['.chat-group-messages'] = [
            'display' => 'flex',
            'flex-direction' => 'column',
            'gap' => '2px',
            'flex' => '1 1 auto',
            'max-width' => 'min(900px, 68%)',
            'align-items' => 'flex-start'
        ];

        // User messages align content right
        $this->cssRules['.chat-group.user .chat-group-messages'] = [
            'align-items' => 'flex-end'
        ];

        $this->cssRules['.chat-group.user .chat-group-footer'] = [
            'justify-content' => 'flex-end'
        ];

        // Footer at bottom of message group (role + time)
        $this->cssRules['.chat-group-footer'] = [
            'display' => 'flex',
            'gap' => '8px',
            'align-items' => 'baseline',
            'margin-top' => '6px'
        ];

        $this->cssRules['.chat-sender-name'] = [
            'font-weight' => '500',
            'font-size' => '12px',
            'color' => 'var(--muted)'
        ];

        $this->cssRules['.chat-group-timestamp'] = [
            'font-size' => '11px',
            'color' => 'var(--muted)',
            'opacity' => '0.7'
        ];

        // Group footer action buttons (TTS, delete)
        $this->cssRules['.chat-group-footer button'] = [
            'background' => 'none',
            'border' => 'none',
            'cursor' => 'pointer',
            'padding' => '4px',
            'min-width' => '24px',
            'min-height' => '24px',
            'border-radius' => 'var(--radius-sm, 4px)',
            'color' => 'var(--muted)',
            'opacity' => '0',
            'pointer-events' => 'none',
            'transition' => "opacity 120ms ease-out,\ncolor 120ms ease-out,\nbackground 120ms ease-out",
            'display' => 'inline-flex',
            'align-items' => 'center',
            'justify-content' => 'center'
        ];

        $this->cssRules['.chat-group:hover .chat-group-footer button'] = [
            'opacity' => '0.6',
            'pointer-events' => 'auto'
        ];

        $this->cssRules['.chat-group-footer button:hover'] = [
            'opacity' => '1 !important',
            'background' => 'var(--bg-hover, rgba(255, 255, 255, 0.08)'
        ];

        $this->cssRules['.chat-group-footer button svg'] = [
            'width' => '14px',
            'height' => '14px',
            'fill' => 'none',
            'stroke' => 'currentColor',
            'stroke-width' => '2',
            'stroke-linecap' => 'round',
            'stroke-linejoin' => 'round'
        ];

        $this->cssRules['.chat-tts-btn--active'] = [
            'opacity' => '1 !important',
            'pointer-events' => 'auto !important',
            'color' => 'var(--accent)'
        ];

        $this->cssRules['.chat-group-delete:hover'] = [
            'color' => 'var(--danger) !important'
        ];

        // Chat divider (e.g., compaction marker)
        $this->cssRules['.chat-divider'] = [
            'display' => 'flex',
            'align-items' => 'center',
            'gap' => '10px',
            'margin' => '18px 8px',
            'color' => 'var(--muted)',
            'font-size' => '11px',
            'letter-spacing' => '0.08em',
            'text-transform' => 'uppercase',
            'user-select' => 'none'
        ];

        $this->cssRules['.chat-divider__line'] = [
            'flex' => '1 1 0',
            'height' => '1px',
            'background' => 'var(--border)',
            'opacity' => '0.9'
        ];

        $this->cssRules['.chat-divider__label'] = [
            'padding' => '2px 10px',
            'border' => '1px solid var(--border)',
            'border-radius' => 'var(--radius-full)',
            'background' => 'rgba(255, 255, 255, 0.02)'
        ];

        // Avatar Styles
        $this->cssRules['.chat-avatar'] = [
            'width' => '36px',
            'height' => '36px',
            'border-radius' => 'var(--radius-md)',
            'background' => 'var(--panel-strong)',
            'display' => 'grid',
            'place-items' => 'center',
            'font-weight' => '600',
            'font-size' => '13px',
            'flex-shrink' => '0',
            'align-self' => 'flex-end',
            'margin-bottom' => '4px',
            'border' => '1px solid var(--border)'
        ];

        $this->cssRules['.chat-avatar.user'] = [
            'background' => 'var(--accent-subtle)',
            'color' => 'var(--accent)',
            'border-color' => 'color-mix(in srgb, var(--accent) 20%, transparent)'
        ];

        $this->cssRules['.chat-avatar.assistant'] = [
            'background' => 'var(--secondary)',
            'color' => 'var(--muted)'
        ];

        $this->cssRules['.chat-avatar.other'] = [
            'background' => 'var(--secondary)',
            'color' => 'var(--muted)'
        ];

        $this->cssRules['.chat-avatar.tool'] = [
            'background' => 'var(--secondary)',
            'color' => 'var(--muted)'
        ];

        // Image avatar support
        $this->cssRules['img.chat-avatar'] = [
            'display' => 'block',
            'object-fit' => 'cover',
            'object-position' => 'center'
        ];

        // Minimal Bubble Design - dynamic width based on content
        $this->cssRules['.chat-bubble'] = [
            'position' => 'relative',
            'display' => 'block',
            'border' => '1px solid var(--border)',
            'background' => 'var(--card)',
            'border-radius' => 'var(--radius-lg)',
            'padding' => '10px 14px',
            'box-shadow' => 'none',
            'transition' => "background var(--duration-fast) ease-out,\nborder-color var(--duration-fast) ease-out",
            'width' => 'auto',
            'max-width' => '100%',
            'box-sizing' => 'border-box',
            'word-wrap' => 'break-word'
        ];

        $this->cssRules['.chat-bubble.has-copy'] = [
            'padding-right' => '70px'
        ];

        $this->cssRules['.chat-bubble-actions'] = [
            'position' => 'absolute',
            'top' => '6px',
            'right' => '8px',
            'display' => 'flex',
            'gap' => '4px',
            'opacity' => '0',
            'pointer-events' => 'none',
            'transition' => 'opacity 120ms ease-out'
        ];

        $this->cssRules['.chat-bubble:hover .chat-bubble-actions'] = [
            'opacity' => '1',
            'pointer-events' => 'auto'
        ];

        $this->cssRules['@media (hover: none)'] = [
            '.chat-bubble-actions' => [
                'opacity' => '1',
                'pointer-events' => 'auto'
            ]
        ];

        $this->cssRules['.chat-copy-btn, .chat-expand-btn'] = [
            'background' => 'var(--bg)',
            'color' => 'var(--muted)'
        ];

        $this->cssRules['.chat-copy-btn__icon'] = [
            'display' => 'inline-flex',
            'width' => '14px',
            'height' => '14px',
            'position' => 'relative'
        ];

        $this->cssRules['.chat-copy-btn__icon svg, .chat-expand-btn__icon svg'] = [
            'width' => '14px',
            'height' => '14px'
        ];

        $this->cssRules['.chat-copy-btn__icon-copy, .chat-copy-btn__icon-check'] = [
            'position' => 'absolute',
            'top' => '0',
            'left' => '0',
            'transition' => 'opacity 150ms ease'
        ];

        $this->cssRules['.chat-copy-btn__icon-check'] = [
            'opacity' => '0'
        ];

        $this->cssRules['.chat-copy-btn[data-copied="1"] .chat-copy-btn__icon-copy'] = [
            'opacity' => '0'
        ];

        $this->cssRules['.chat-copy-btn[data-copied="1"] .chat-copy-btn__icon-check'] = [
            'opacity' => '1'
        ];

        $this->cssRules['.chat-copy-btn[data-copying="1"]'] = [
            'opacity' => '0',
            'pointer-events' => 'none'
        ];

        $this->cssRules['.chat-copy-btn[data-error="1"]'] = [
            'border-color' => 'var(--danger-subtle)',
            'background' => 'var(--danger-subtle)',
            'color' => 'var(--danger)'
        ];

        $this->cssRules['.chat-copy-btn[data-copied="1"]'] = [
            'border-color' => 'var(--ok-subtle)',
            'background' => 'var(--ok-subtle)',
            'color' => 'var(--ok)'
        ];

        $this->cssRules['.chat-copy-btn:focus-visible, .chat-expand-btn:focus-visible'] = [
            'outline' => '2px solid var(--accent)',
            'outline-offset' => '2px'
        ];

        $this->cssRules['.chat-expand-btn__icon'] = [
            'display' => 'inline-flex',
            'width' => '14px',
            'height' => '14px'
        ];

        // Light mode: restore borders
        $this->cssRules[':root[data-theme-mode="light"] .chat-bubble'] = [
            'border-color' => 'var(--border)',
            'box-shadow' => 'inset 0 1px 0 var(--card-highlight)'
        ];

        $this->cssRules['.chat-bubble:hover'] = [
            'background' => 'var(--bg-hover)'
        ];

        // User bubbles have different styling
        $this->cssRules['.chat-group.user .chat-bubble'] = [
            'background' => 'var(--accent-subtle)',
            'border-color' => 'transparent'
        ];

        $this->cssRules[':root[data-theme-mode="light"] .chat-group.user .chat-bubble'] = [
            'border-color' => 'color-mix(in srgb, var(--accent) 20%, transparent)',
            'background' => 'var(--accent-subtle)'
        ];

        $this->cssRules['.chat-group.user .chat-bubble:hover'] = [
            'background' => 'color-mix(in srgb, var(--accent) 20%, transparent)'
        ];

        // Streaming animation
        $this->cssRules['.chat-bubble.streaming'] = [
            'animation' => 'pulsing-border 1.5s ease-out infinite'
        ];

        $this->cssRules['@keyframes pulsing-border'] = [
            '0%, 100%' => [
                'border-color' => 'var(--border)'
            ],
            '50%' => [
                'border-color' => 'var(--accent)'
            ]
        ];

        // Fade-in animation for new messages
        $this->cssRules['.chat-bubble.fade-in'] = [
            'animation' => 'fade-in 200ms ease-out'
        ];

        $this->cssRules['@keyframes fade-in'] = [
            'from' => [
                'opacity' => '0',
                'transform' => 'translateY(4px)'
            ],
            'to' => [
                'opacity' => '1',
                'transform' => 'translateY(0)'
            ]
        ];

        // Message metadata (tokens, cost, model, context %)
        $this->cssRules['.msg-meta'] = [
            'display' => 'inline-flex',
            'align-items' => 'center',
            'gap' => '8px',
            'font-size' => '11px',
            'line-height' => '1',
            'color' => 'var(--muted)',
            'margin-top' => '4px',
            'flex-wrap' => 'wrap'
        ];

        $this->cssRules['.msg-meta__tokens, .msg-meta__cache, .msg-meta__cost, .msg-meta__ctx, .msg-meta__model'] = [
            'display' => 'inline-flex',
            'align-items' => 'center',
            'gap' => '2px',
            'white-space' => 'nowrap'
        ];

        $this->cssRules['.msg-meta__model'] = [
            'background' => 'var(--bg-hover, rgba(255, 255, 255, 0.06))',
            'padding' => '1px 6px',
            'border-radius' => 'var(--radius-sm, 4px)',
            'font-family' => 'var(--font-mono, monospace)'
        ];

        $this->cssRules['.msg-meta__cost'] = [
            'color' => 'var(--ok)'
        ];

        $this->cssRules['.msg-meta__ctx--warn'] = [
            'color' => 'var(--warn)'
        ];

        $this->cssRules['.msg-meta__ctx--danger'] = [
            'color' => 'var(--danger)'
        ];

        // Delete confirmation popover
        $this->cssRules['.chat-delete-wrap'] = [
            'position' => 'relative',
            'display' => 'inline-flex'
        ];

        $this->cssRules['.chat-delete-confirm'] = [
            'position' => 'absolute',
            'bottom' => 'calc(100% + 6px)',
            'background' => 'var(--card, #1a1a1a)',
            'border' => '1px solid var(--border, rgba(255, 255, 255, 0.1))',
            'border-radius' => 'var(--radius-md, 8px)',
            'padding' => '12px',
            'min-width' => '200px',
            'max-width' => 'calc(100vw - 48px)',
            'box-shadow' => '0 8px 24px rgba(0, 0, 0, 0.4)',
            'z-index' => '100',
            'animation' => 'scale-in 0.15s ease-out'
        ];

        $this->cssRules['.chat-delete-confirm--left'] = [
            'right' => '0'
        ];

        $this->cssRules['.chat-delete-confirm--right'] = [
            'left' => '0'
        ];

        $this->cssRules['.chat-delete-confirm__text'] = [
            'margin' => '0 0 8px',
            'font-size' => '13px',
            'font-weight' => '500',
            'color' => 'var(--fg, #fff)'
        ];

        $this->cssRules['.chat-delete-confirm__remember'] = [
            'display' => 'flex',
            'align-items' => 'center',
            'gap' => '6px',
            'font-size' => '11px',
            'color' => 'var(--muted, #888)',
            'margin-bottom' => '10px',
            'cursor' => 'pointer',
            'user-select' => 'none'
        ];

        $this->cssRules['.chat-delete-confirm__check'] = [
            'width' => '14px',
            'height' => '14px',
            'accent-color' => 'var(--accent)',
            'cursor' => 'pointer'
        ];

        $this->cssRules['.chat-delete-confirm__actions'] = [
            'display' => 'flex',
            'gap' => '6px',
            'justify-content' => 'flex-end'
        ];

        $this->cssRules['.chat-delete-confirm__cancel, .chat-delete-confirm__yes'] = [
            'border' => 'none',
            'border-radius' => 'var(--radius-sm, 4px)',
            'padding' => '4px 12px',
            'font-size' => '12px',
            'font-weight' => '500',
            'cursor' => 'pointer',
            'transition' => 'background 120ms ease-out'
        ];

        $this->cssRules['.chat-delete-confirm__cancel'] = [
            'background' => 'var(--bg-hover, rgba(255, 255, 255, 0.08))',
            'color' => 'var(--muted, #888)'
        ];

        $this->cssRules['.chat-delete-confirm__cancel:hover'] = [
            'background' => 'rgba(255, 255, 255, 0.12)'
        ];

        $this->cssRules['.chat-delete-confirm__yes'] = [
            'background' => 'var(--danger)',
            'color' => '#fff'
        ];

        $this->cssRules['.chat-delete-confirm__yes:hover'] = [
            'background' => '#dc2626'
        ];

        // Media queries
        $this->cssRules['@media (max-width: 768px)'] = [
            '.chat-group' => [
                'margin-left' => '0',
                'margin-right' => '0'
            ],
            '.chat-group-messages' => [
                'max-width' => '82%'
            ]
        ];

        $this->cssRules['@media (max-width: 400px)'] = [
            '.chat-group-messages' => [
                'max-width' => '100%'
            ],
            '.chat-avatar, img.chat-avatar' => [
                'display' => 'none'
            ]
        ];
    }

    private function formatCSSRule($selector, $properties) {
        $css = "$selector {\n";
        foreach ($properties as $property => $value) {
            $css .= "  $property: $value;\n";
        }
        $css .= "}\n\n";
        return $css;
    }

    private function generateCSS() {
        $css = "/* =============================================\n";
        $css .= "   GROUPED CHAT LAYOUT (Slack-style)\n";
        $css .= "   ============================================= */\n\n";

        foreach ($this->cssRules as $selector => $properties) {
            if (is_array($properties)) {
                if (strpos($selector, '@media') === 0 || strpos($selector, '@keyframes') === 0) {
                    $css .= "$selector {\n";
                    foreach ($properties as $subSelector => $subProperties) {
                        if (is_array($subProperties)) {
                            $css .= "  $subSelector {\n";
                            foreach ($subProperties as $property => $value) {
                                $css .= "    $property: $value;\n";
                            }
                            $css .= "  }\n";
                        } else {
                            $css .= "  $subSelector: $subProperties;\n";
                        }
                    }
                    $css .= "}\n\n";
                } else {
                    $css .= $this->formatCSSRule($selector, $properties);
                }
            }
        }

        return $css;
    }

    public function saveToFile($filename) {
        $cssContent = $this->generateCSS();
        return file_put_contents($filename, $cssContent) !== false;
    }
}

// Hauptprogramm
if (isset($argv[1])) {
    $generator = new GroupedCSSGenerator();
    if ($generator->saveToFile($argv[1])) {
        echo "CSS erfolgreich in {$argv[1]} gespeichert.\n";
    } else {
        echo "Fehler beim Speichern der CSS-Datei.\n";
        exit(1);
    }
} else {
    echo "Verwendung: php script.php <dateiname>\n";
    exit(1);
}
?>
