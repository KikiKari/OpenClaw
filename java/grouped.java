// abstraction-provenance: {"artifact_sha256": "0b15f128596fb7f83a4d8ccb20312462dd2a00db8643af642d213d90bd455b7d", "source_sha256": "be7071091b8a4e461f665879c436317756f6591f0bcf132f78e03c8b0bb8eb0d", "target_language": "java"}
// grouped.css — portiert nach java
// Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat/grouped.css
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

public class GroupedCSSGenerator {

    public static void main(String[] args) {
        if (args.length != 1) {
            System.err.println("Usage: java GroupedCSSGenerator <output-file>");
            System.exit(1);
        }

        String outputFile = args[0];
        List<CSSRule> rules = generateCSSRules();
        
        try {
            writeCSSFile(rules, outputFile);
            System.out.println("CSS file generated successfully: " + outputFile);
        } catch (IOException e) {
            System.err.println("Error writing CSS file: " + e.getMessage());
            System.exit(1);
        }
    }

    private static List<CSSRule> generateCSSRules() {
        List<CSSRule> rules = new ArrayList<>();

        // Chat Group Layout - default (assistant/other on left)
        CSSRule chatGroup = new CSSRule(".chat-group");
        chatGroup.addDeclaration("display", "flex");
        chatGroup.addDeclaration("gap", "10px");
        chatGroup.addDeclaration("align-items", "flex-start");
        chatGroup.addDeclaration("margin-bottom", "14px");
        chatGroup.addDeclaration("margin-left", "4px");
        chatGroup.addDeclaration("margin-right", "16px");
        rules.add(chatGroup);

        // User messages on right
        CSSRule chatGroupUser = new CSSRule(".chat-group.user");
        chatGroupUser.addDeclaration("flex-direction", "row-reverse");
        chatGroupUser.addDeclaration("justify-content", "flex-start");
        rules.add(chatGroupUser);

        CSSRule chatGroupMessages = new CSSRule(".chat-group-messages");
        chatGroupMessages.addDeclaration("display", "flex");
        chatGroupMessages.addDeclaration("flex-direction", "column");
        chatGroupMessages.addDeclaration("gap", "2px");
        chatGroupMessages.addDeclaration("flex", "1 1 auto");
        chatGroupMessages.addDeclaration("max-width", "min(900px, 68%)");
        chatGroupMessages.addDeclaration("align-items", "flex-start");
        rules.add(chatGroupMessages);

        // User messages align content right
        CSSRule chatGroupMessagesUser = new CSSRule(".chat-group.user .chat-group-messages");
        chatGroupMessagesUser.addDeclaration("align-items", "flex-end");
        rules.add(chatGroupMessagesUser);

        CSSRule chatGroupFooterUser = new CSSRule(".chat-group.user .chat-group-footer");
        chatGroupFooterUser.addDeclaration("justify-content", "flex-end");
        rules.add(chatGroupFooterUser);

        // Footer at bottom of message group (role + time)
        CSSRule chatGroupFooter = new CSSRule(".chat-group-footer");
        chatGroupFooter.addDeclaration("display", "flex");
        chatGroupFooter.addDeclaration("gap", "8px");
        chatGroupFooter.addDeclaration("align-items", "baseline");
        chatGroupFooter.addDeclaration("margin-top", "6px");
        rules.add(chatGroupFooter);

        CSSRule chatSenderName = new CSSRule(".chat-sender-name");
        chatSenderName.addDeclaration("font-weight", "500");
        chatSenderName.addDeclaration("font-size", "12px");
        chatSenderName.addDeclaration("color", "var(--muted)");
        rules.add(chatSenderName);

        CSSRule chatGroupTimestamp = new CSSRule(".chat-group-timestamp");
        chatGroupTimestamp.addDeclaration("font-size", "11px");
        chatGroupTimestamp.addDeclaration("color", "var(--muted)");
        chatGroupTimestamp.addDeclaration("opacity", "0.7");
        rules.add(chatGroupTimestamp);

        // Group footer action buttons (TTS, delete)
        CSSRule chatGroupFooterButton = new CSSRule(".chat-group-footer button");
        chatGroupFooterButton.addDeclaration("background", "none");
        chatGroupFooterButton.addDeclaration("border", "none");
        chatGroupFooterButton.addDeclaration("cursor", "pointer");
        chatGroupFooterButton.addDeclaration("padding", "4px");
        chatGroupFooterButton.addDeclaration("min-width", "24px");
        chatGroupFooterButton.addDeclaration("min-height", "24px");
        chatGroupFooterButton.addDeclaration("border-radius", "var(--radius-sm, 4px)");
        chatGroupFooterButton.addDeclaration("color", "var(--muted)");
        chatGroupFooterButton.addDeclaration("opacity", "0");
        chatGroupFooterButton.addDeclaration("pointer-events", "none");
        chatGroupFooterButton.addDeclaration("transition", "opacity 120ms ease-out, color 120ms ease-out, background 120ms ease-out");
        chatGroupFooterButton.addDeclaration("display", "inline-flex");
        chatGroupFooterButton.addDeclaration("align-items", "center");
        chatGroupFooterButton.addDeclaration("justify-content", "center");
        rules.add(chatGroupFooterButton);

        CSSRule chatGroupHoverFooterButton = new CSSRule(".chat-group:hover .chat-group-footer button");
        chatGroupHoverFooterButton.addDeclaration("opacity", "0.6");
        chatGroupHoverFooterButton.addDeclaration("pointer-events", "auto");
        rules.add(chatGroupHoverFooterButton);

        CSSRule chatGroupFooterButtonHover = new CSSRule(".chat-group-footer button:hover");
        chatGroupFooterButtonHover.addDeclaration("opacity", "1 !important");
        chatGroupFooterButtonHover.addDeclaration("background", "var(--bg-hover, rgba(255, 255, 255, 0.08))");
        rules.add(chatGroupFooterButtonHover);

        CSSRule chatGroupFooterButtonSvg = new CSSRule(".chat-group-footer button svg");
        chatGroupFooterButtonSvg.addDeclaration("width", "14px");
        chatGroupFooterButtonSvg.addDeclaration("height", "14px");
        chatGroupFooterButtonSvg.addDeclaration("fill", "none");
        chatGroupFooterButtonSvg.addDeclaration("stroke", "currentColor");
        chatGroupFooterButtonSvg.addDeclaration("stroke-width", "2");
        chatGroupFooterButtonSvg.addDeclaration("stroke-linecap", "round");
        chatGroupFooterButtonSvg.addDeclaration("stroke-linejoin", "round");
        rules.add(chatGroupFooterButtonSvg);

        CSSRule chatTtsBtnActive = new CSSRule(".chat-tts-btn--active");
        chatTtsBtnActive.addDeclaration("opacity", "1 !important");
        chatTtsBtnActive.addDeclaration("pointer-events", "auto !important");
        chatTtsBtnActive.addDeclaration("color", "var(--accent)");
        rules.add(chatTtsBtnActive);

        CSSRule chatGroupDeleteHover = new CSSRule(".chat-group-delete:hover");
        chatGroupDeleteHover.addDeclaration("color", "var(--danger) !important");
        rules.add(chatGroupDeleteHover);

        // Chat divider (e.g., compaction marker)
        CSSRule chatDivider = new CSSRule(".chat-divider");
        chatDivider.addDeclaration("display", "flex");
        chatDivider.addDeclaration("align-items", "center");
        chatDivider.addDeclaration("gap", "10px");
        chatDivider.addDeclaration("margin", "18px 8px");
        chatDivider.addDeclaration("color", "var(--muted)");
        chatDivider.addDeclaration("font-size", "11px");
        chatDivider.addDeclaration("letter-spacing", "0.08em");
        chatDivider.addDeclaration("text-transform", "uppercase");
        chatDivider.addDeclaration("user-select", "none");
        rules.add(chatDivider);

        CSSRule chatDividerLine = new CSSRule(".chat-divider__line");
        chatDividerLine.addDeclaration("flex", "1 1 0");
        chatDividerLine.addDeclaration("height", "1px");
        chatDividerLine.addDeclaration("background", "var(--border)");
        chatDividerLine.addDeclaration("opacity", "0.9");
        rules.add(chatDividerLine);

        CSSRule chatDividerLabel = new CSSRule(".chat-divider__label");
        chatDividerLabel.addDeclaration("padding", "2px 10px");
        chatDividerLabel.addDeclaration("border", "1px solid var(--border)");
        chatDividerLabel.addDeclaration("border-radius", "var(--radius-full)");
        chatDividerLabel.addDeclaration("background", "rgba(255, 255, 255, 0.02)");
        rules.add(chatDividerLabel);

        // Avatar Styles
        CSSRule chatAvatar = new CSSRule(".chat-avatar");
        chatAvatar.addDeclaration("width", "36px");
        chatAvatar.addDeclaration("height", "36px");
        chatAvatar.addDeclaration("border-radius", "var(--radius-md)");
        chatAvatar.addDeclaration("background", "var(--panel-strong)");
        chatAvatar.addDeclaration("display", "grid");
        chatAvatar.addDeclaration("place-items", "center");
        chatAvatar.addDeclaration("font-weight", "600");
        chatAvatar.addDeclaration("font-size", "13px");
        chatAvatar.addDeclaration("flex-shrink", "0");
        chatAvatar.addDeclaration("align-self", "flex-end");
        chatAvatar.addDeclaration("margin-bottom", "4px");
        chatAvatar.addDeclaration("border", "1px solid var(--border)");
        rules.add(chatAvatar);

        CSSRule chatAvatarUser = new CSSRule(".chat-avatar.user");
        chatAvatarUser.addDeclaration("background", "var(--accent-subtle)");
        chatAvatarUser.addDeclaration("color", "var(--accent)");
        chatAvatarUser.addDeclaration("border-color", "color-mix(in srgb, var(--accent) 20%, transparent)");
        rules.add(chatAvatarUser);

        CSSRule chatAvatarAssistant = new CSSRule(".chat-avatar.assistant");
        chatAvatarAssistant.addDeclaration("background", "var(--secondary)");
        chatAvatarAssistant.addDeclaration("color", "var(--muted)");
        rules.add(chatAvatarAssistant);

        CSSRule chatAvatarOther = new CSSRule(".chat-avatar.other");
        chatAvatarOther.addDeclaration("background", "var(--secondary)");
        chatAvatarOther.addDeclaration("color", "var(--muted)");
        rules.add(chatAvatarOther);

        CSSRule chatAvatarTool = new CSSRule(".chat-avatar.tool");
        chatAvatarTool.addDeclaration("background", "var(--secondary)");
        chatAvatarTool.addDeclaration("color", "var(--muted)");
        rules.add(chatAvatarTool);

        // Image avatar support
        CSSRule imgChatAvatar = new CSSRule("img.chat-avatar");
        imgChatAvatar.addDeclaration("display", "block");
        imgChatAvatar.addDeclaration("object-fit", "cover");
        imgChatAvatar.addDeclaration("object-position", "center");
        rules.add(imgChatAvatar);

        // Minimal Bubble Design - dynamic width based on content
        CSSRule chatBubble = new CSSRule(".chat-bubble");
        chatBubble.addDeclaration("position", "relative");
        chatBubble.addDeclaration("display", "block");
        chatBubble.addDeclaration("border", "1px solid var(--border)");
        chatBubble.addDeclaration("background", "var(--card)");
        chatBubble.addDeclaration("border-radius", "var(--radius-lg)");
        chatBubble.addDeclaration("padding", "10px 14px");
        chatBubble.addDeclaration("box-shadow", "none");
        chatBubble.addDeclaration("transition", "background var(--duration-fast) ease-out, border-color var(--duration-fast) ease-out");
        chatBubble.addDeclaration("width", "auto");
        chatBubble.addDeclaration("max-width", "100%");
        chatBubble.addDeclaration("box-sizing", "border-box");
        chatBubble.addDeclaration("word-wrap", "break-word");
        rules.add(chatBubble);

        CSSRule chatBubbleHasCopy = new CSSRule(".chat-bubble.has-copy");
        chatBubbleHasCopy.addDeclaration("padding-right", "70px");
        rules.add(chatBubbleHasCopy);

        CSSRule chatBubbleActions = new CSSRule(".chat-bubble-actions");
        chatBubbleActions.addDeclaration("position", "absolute");
        chatBubbleActions.addDeclaration("top", "6px");
        chatBubbleActions.addDeclaration("right", "8px");
        chatBubbleActions.addDeclaration("display", "flex");
        chatBubbleActions.addDeclaration("gap", "4px");
        chatBubbleActions.addDeclaration("opacity", "0");
        chatBubbleActions.addDeclaration("pointer-events", "none");
        chatBubbleActions.addDeclaration("transition", "opacity 120ms ease-out");
        rules.add(chatBubbleActions);

        CSSRule chatBubbleHoverActions = new CSSRule(".chat-bubble:hover .chat-bubble-actions");
        chatBubbleHoverActions.addDeclaration("opacity", "1");
        chatBubbleHoverActions.addDeclaration("pointer-events", "auto");
        rules.add(chatBubbleHoverActions);

        CSSRule mediaHoverNone = new CSSRule("@media (hover: none)", ".chat-bubble-actions");
        mediaHoverNone.addDeclaration("opacity", "1");
        mediaHoverNone.addDeclaration("pointer-events", "auto");
        rules.add(mediaHoverNone);

        CSSRule chatCopyBtn = new CSSRule(".chat-copy-btn, .chat-expand-btn");
        chatCopyBtn.addDeclaration("background", "var(--bg)");
        chatCopyBtn.addDeclaration("color", "var(--muted)");
        rules.add(chatCopyBtn);

        CSSRule chatCopyBtnIcon = new CSSRule(".chat-copy-btn__icon");
        chatCopyBtnIcon.addDeclaration("display", "inline-flex");
        chatCopyBtnIcon.addDeclaration("width", "14px");
        chatCopyBtnIcon.addDeclaration("height", "14px");
        chatCopyBtnIcon.addDeclaration("position", "relative");
        rules.add(chatCopyBtnIcon);

        CSSRule chatCopyBtnIconSvg = new CSSRule(".chat-copy-btn__icon svg, .chat-expand-btn__icon svg");
        chatCopyBtnIconSvg.addDeclaration("width", "14px");
        chatCopyBtnIconSvg.addDeclaration("height", "14px");
        rules.add(chatCopyBtnIconSvg);

        CSSRule chatCopyBtnIconCopy = new CSSRule(".chat-copy-btn__icon-copy, .chat-copy-btn__icon-check");
        chatCopyBtnIconCopy.addDeclaration("position", "absolute");
        chatCopyBtnIconCopy.addDeclaration("top", "0");
        chatCopyBtnIconCopy.addDeclaration("left", "0");
        chatCopyBtnIconCopy.addDeclaration("transition", "opacity 150ms ease");
        rules.add(chatCopyBtnIconCopy);

        CSSRule chatCopyBtnIconCheck = new CSSRule(".chat-copy-btn__icon-check");
        chatCopyBtnIconCheck.addDeclaration("opacity", "0");
        rules.add(chatCopyBtnIconCheck);

        CSSRule chatCopyBtnDataCopied = new CSSRule(".chat-copy-btn[data-copied=\"1\"] .chat-copy-btn__icon-copy");
        chatCopyBtnDataCopied.addDeclaration("opacity", "0");
        rules.add(chatCopyBtnDataCopied);

        CSSRule chatCopyBtnDataCopiedCheck = new CSSRule(".chat-copy-btn[data-copied=\"1\"] .chat-copy-btn__icon-check");
        chatCopyBtnDataCopiedCheck.addDeclaration("opacity", "1");
        rules.add(chatCopyBtnDataCopiedCheck);

        CSSRule chatCopyBtnDataCopying = new CSSRule(".chat-copy-btn[data-copying=\"1\"]");
        chatCopyBtnDataCopying.addDeclaration("opacity", "0");
        chatCopyBtnDataCopying.addDeclaration("pointer-events", "none");
        rules.add(chatCopyBtnDataCopying);

        CSSRule chatCopyBtnDataError = new CSSRule(".chat-copy-btn[data-error=\"1\"]");
        chatCopyBtnDataError.addDeclaration("border-color", "var(--danger-subtle)");
        chatCopyBtnDataError.addDeclaration("background", "var(--danger-subtle)");
        chatCopyBtnDataError.addDeclaration("color", "var(--danger)");
        rules.add(chatCopyBtnDataError);

        CSSRule chatCopyBtnDataCopiedStyle = new CSSRule(".chat-copy-btn[data-copied=\"1\"]");
        chatCopyBtnDataCopiedStyle.addDeclaration("border-color", "var(--ok-subtle)");
        chatCopyBtnDataCopiedStyle.addDeclaration("background", "var(--ok-subtle)");
        chatCopyBtnDataCopiedStyle.addDeclaration("color", "var(--ok)");
        rules.add(chatCopyBtnDataCopiedStyle);

        CSSRule chatCopyBtnFocusVisible = new CSSRule(".chat-copy-btn:focus-visible, .chat-expand-btn:focus-visible");
        chatCopyBtnFocusVisible.addDeclaration("outline", "2px solid var(--accent)");
        chatCopyBtnFocusVisible.addDeclaration("outline-offset", "2px");
        rules.add(chatCopyBtnFocusVisible);

        CSSRule chatExpandBtnIcon = new CSSRule(".chat-expand-btn__icon");
        chatExpandBtnIcon.addDeclaration("display", "inline-flex");
        chatExpandBtnIcon.addDeclaration("width", "14px");
        chatExpandBtnIcon.addDeclaration("height", "14px");
        rules.add(chatExpandBtnIcon);

        // Light mode: restore borders
        CSSRule rootLightMode = new CSSRule(":root[data-theme-mode=\"light\"] .chat-bubble");
        rootLightMode.addDeclaration("border-color", "var(--border)");
        rootLightMode.addDeclaration("box-shadow", "inset 0 1px 0 var(--card-highlight)");
        rules.add(rootLightMode);

        CSSRule chatBubbleHover = new CSSRule(".chat-bubble:hover");
        chatBubbleHover.addDeclaration("background", "var(--bg-hover)");
        rules.add(chatBubbleHover);

        // User bubbles have different styling
        CSSRule chatGroupUserBubble = new CSSRule(".chat-group.user .chat-bubble");
        chatGroupUserBubble.addDeclaration("background", "var(--accent-subtle)");
        chatGroupUserBubble.addDeclaration("border-color", "transparent");
        rules.add(chatGroupUserBubble);

        CSSRule rootLightModeUserBubble = new CSSRule(":root[data-theme-mode=\"light\"] .chat-group.user .chat-bubble");
        rootLightModeUserBubble.addDeclaration("border-color", "color-mix(in srgb, var(--accent) 20%, transparent)");
        rootLightModeUserBubble.addDeclaration("background", "var(--accent-subtle)");
        rules.add(rootLightModeUserBubble);

        CSSRule chatGroupUserBubbleHover = new CSSRule(".chat-group.user .chat-bubble:hover");
        chatGroupUserBubbleHover.addDeclaration("background", "color-mix(in srgb, var(--accent) 20%, transparent)");
        rules.add(chatGroupUserBubbleHover);

        // Streaming animation
        CSSRule chatBubbleStreaming = new CSSRule(".chat-bubble.streaming");
        chatBubbleStreaming.addDeclaration("animation", "pulsing-border 1.5s ease-out infinite");
        rules.add(chatBubbleStreaming);

        CSSRule keyframesPulsingBorder = new CSSRule("@keyframes pulsing-border");
        keyframesPulsingBorder.addDeclaration("0%, 100%", "border-color: var(--border);");
        keyframesPulsingBorder.addDeclaration("50%", "border-color: var(--accent);");
        rules.add(keyframesPulsingBorder);

        // Fade-in animation for new messages
        CSSRule chatBubbleFadeIn = new CSSRule(".chat-bubble.fade-in");
        chatBubbleFadeIn.addDeclaration("animation", "fade-in 200ms ease-out");
        rules.add(chatBubbleFadeIn);

        CSSRule keyframesFadeIn = new CSSRule("@keyframes fade-in");
        keyframesFadeIn.addDeclaration("from", "opacity: 0; transform: translateY(4px);");
        keyframesFadeIn.addDeclaration("to", "opacity: 1; transform: translateY(0);");
        rules.add(keyframesFadeIn);

        // Message metadata (tokens, cost, model, context %)
        CSSRule msgMeta = new CSSRule(".msg-meta");
        msgMeta.addDeclaration("display", "inline-flex");
        msgMeta.addDeclaration("align-items", "center");
        msgMeta.addDeclaration("gap", "8px");
        msgMeta.addDeclaration("font-size", "11px");
        msgMeta.addDeclaration("line-height", "1");
        msgMeta.addDeclaration("color", "var(--muted)");
        msgMeta.addDeclaration("margin-top", "4px");
        msgMeta.addDeclaration("flex-wrap", "wrap");
        rules.add(msgMeta);

        CSSRule msgMetaTokens = new CSSRule(".msg-meta__tokens, .msg-meta__cache, .msg-meta__cost, .msg-meta__ctx, .msg-meta__model");
        msgMetaTokens.addDeclaration("display", "inline-flex");
        msgMetaTokens.addDeclaration("align-items", "center");
        msgMetaTokens.addDeclaration("gap", "2px");
        msgMetaTokens.addDeclaration("white-space", "nowrap");
        rules.add(msgMetaTokens);

        CSSRule msgMetaModel = new CSSRule(".msg-meta__model");
        msgMetaModel.addDeclaration("background", "var(--bg-hover, rgba(255, 255, 255, 0.06))");
        msgMetaModel.addDeclaration("padding", "1px 6px");
        msgMetaModel.addDeclaration("border-radius", "var(--radius-sm, 4px)");
        msgMetaModel.addDeclaration("font-family", "var(--font-mono, monospace)");
        rules.add(msgMetaModel);

        CSSRule msgMetaCost = new CSSRule(".msg-meta__cost");
        msgMetaCost.addDeclaration("color", "var(--ok)");
        rules.add(msgMetaCost);

        CSSRule msgMetaCtxWarn = new CSSRule(".msg-meta__ctx--warn");
        msgMetaCtxWarn.addDeclaration("color", "var(--warn)");
        rules.add(msgMetaCtxWarn);

        CSSRule msgMetaCtxDanger = new CSSRule(".msg-meta__ctx--danger");
        msgMetaCtxDanger.addDeclaration("color", "var(--danger)");
        rules.add(msgMetaCtxDanger);

        // Delete confirmation popover
        CSSRule chatDeleteWrap = new CSSRule(".chat-delete-wrap");
        chatDeleteWrap.addDeclaration("position", "relative");
        chatDeleteWrap.addDeclaration("display", "inline-flex");
        rules.add(chatDeleteWrap);

        CSSRule chatDeleteConfirm = new CSSRule(".chat-delete-confirm");
        chatDeleteConfirm.addDeclaration("position", "absolute");
        chatDeleteConfirm.addDeclaration("bottom", "calc(100% + 6px)");
        chatDeleteConfirm.addDeclaration("background", "var(--card, #1a1a1a)");
        chatDeleteConfirm.addDeclaration("border", "1px solid var(--border, rgba(255, 255, 255, 0.1))");
        chatDeleteConfirm.addDeclaration("border-radius", "var(--radius-md, 8px)");
        chatDeleteConfirm.addDeclaration("padding", "12px");
        chatDeleteConfirm.addDeclaration("min-width", "200px");
        chatDeleteConfirm.addDeclaration("max-width", "calc(100vw - 48px)");
        chatDeleteConfirm.addDeclaration("box-shadow", "0 8px 24px rgba(0, 0, 0, 0.4)");
        chatDeleteConfirm.addDeclaration("z-index", "100");
        chatDeleteConfirm.addDeclaration("animation", "scale-in 0.15s ease-out");
        rules.add(chatDeleteConfirm);

        CSSRule chatDeleteConfirmLeft = new CSSRule(".chat-delete-confirm--left");
        chatDeleteConfirmLeft.addDeclaration("right", "0");
        rules.add(chatDeleteConfirmLeft);

        CSSRule chatDeleteConfirmRight = new CSSRule(".chat-delete-confirm--right");
        chatDeleteConfirmRight.addDeclaration("left", "0");
        rules.add(chatDeleteConfirmRight);

        CSSRule chatDeleteConfirmText = new CSSRule(".chat-delete-confirm__text");
        chatDeleteConfirmText.addDeclaration("margin", "0 0 8px");
        chatDeleteConfirmText.addDeclaration("font-size", "13px");
        chatDeleteConfirmText.addDeclaration("font-weight", "500");
        chatDeleteConfirmText.addDeclaration("color", "var(--fg, #fff)");
        rules.add(chatDeleteConfirmText);

        CSSRule chatDeleteConfirmRemember = new CSSRule(".chat-delete-confirm__remember");
        chatDeleteConfirmRemember.addDeclaration("display", "flex");
        chatDeleteConfirmRemember.addDeclaration("align-items", "center");
        chatDeleteConfirmRemember.addDeclaration("gap", "6px");
        chatDeleteConfirmRemember.addDeclaration("font-size", "11px");
        chatDeleteConfirmRemember.addDeclaration("color", "var(--muted, #888)");
        chatDeleteConfirmRemember.addDeclaration("margin-bottom", "10px");
        chatDeleteConfirmRemember.addDeclaration("cursor", "pointer");
        chatDeleteConfirmRemember.addDeclaration("user-select", "none");
        rules.add(chatDeleteConfirmRemember);

        CSSRule chatDeleteConfirmCheck = new CSSRule(".chat-delete-confirm__check");
        chatDeleteConfirmCheck.addDeclaration("width", "14px");
        chatDeleteConfirmCheck.addDeclaration("height", "14px");
        chatDeleteConfirmCheck.addDeclaration("accent-color", "var(--accent)");
        chatDeleteConfirmCheck.addDeclaration("cursor", "pointer");
        rules.add(chatDeleteConfirmCheck);

        CSSRule chatDeleteConfirmActions = new CSSRule(".chat-delete-confirm__actions");
        chatDeleteConfirmActions.addDeclaration("display", "flex");
        chatDeleteConfirmActions.addDeclaration("gap", "6px");
        chatDeleteConfirmActions.addDeclaration("justify-content", "flex-end");
        rules.add(chatDeleteConfirmActions);

        CSSRule chatDeleteConfirmCancel = new CSSRule(".chat-delete-confirm__cancel, .chat-delete-confirm__yes");
        chatDeleteConfirmCancel.addDeclaration("border", "none");
        chatDeleteConfirmCancel.addDeclaration("border-radius", "var(--radius-sm, 4px)");
        chatDeleteConfirmCancel.addDeclaration("padding", "4px 12px");
        chatDeleteConfirmCancel.addDeclaration("font-size", "12px");
        chatDeleteConfirmCancel.addDeclaration("font-weight", "500");
        chatDeleteConfirmCancel.addDeclaration("cursor", "pointer");
        chatDeleteConfirmCancel.addDeclaration("transition", "background 120ms ease-out");
        rules.add(chatDeleteConfirmCancel);

        CSSRule chatDeleteConfirmCancelStyle = new CSSRule(".chat-delete-confirm__cancel");
        chatDeleteConfirmCancelStyle.addDeclaration("background", "var(--bg-hover, rgba(255, 255, 255, 0.08))");
        chatDeleteConfirmCancelStyle.addDeclaration("color", "var(--muted, #888)");
        rules.add(chatDeleteConfirmCancelStyle);

        CSSRule chatDeleteConfirmCancelHover = new CSSRule(".chat-delete-confirm__cancel:hover");
        chatDeleteConfirmCancelHover.addDeclaration("background", "rgba(255, 255, 255, 0.12)");
        rules.add(chatDeleteConfirmCancelHover);

        CSSRule chatDeleteConfirmYes = new CSSRule(".chat-delete-confirm__yes");
        chatDeleteConfirmYes.addDeclaration("background", "var(--danger)");
        chatDeleteConfirmYes.addDeclaration("color", "#fff");
        rules.add(chatDeleteConfirmYes);

        CSSRule chatDeleteConfirmYesHover = new CSSRule(".chat-delete-confirm__yes:hover");
        chatDeleteConfirmYesHover.addDeclaration("background", "#dc2626");
        rules.add(chatDeleteConfirmYesHover);

        // Media queries
        CSSRule mediaMaxWidth768 = new CSSRule("@media (max-width: 768px)", ".chat-group");
        mediaMaxWidth768.addDeclaration("margin-left", "0");
        mediaMaxWidth768.addDeclaration("margin-right", "0");
        rules.add(mediaMaxWidth768);

        CSSRule mediaMaxWidth768Messages = new CSSRule("@media (max-width: 768px)", ".chat-group-messages");
        mediaMaxWidth768Messages.addDeclaration("max-width", "82%");
        rules.add(mediaMaxWidth768Messages);

        CSSRule mediaMaxWidth400 = new CSSRule("@media (max-width: 400px)", ".chat-group-messages");
        mediaMaxWidth400.addDeclaration("max-width", "100%");
        rules.add(mediaMaxWidth400);

        CSSRule mediaMaxWidth400Avatar = new CSSRule("@media (max-width: 400px)", ".chat-avatar, img.chat-avatar");
        mediaMaxWidth400Avatar.addDeclaration("display", "none");
        rules.add(mediaMaxWidth400Avatar);

        return rules;
    }

    private static void writeCSSFile(List<CSSRule> rules, String filename) throws IOException {
        StringBuilder cssContent = new StringBuilder();
        
        // Add comment header
        cssContent.append("/* =============================================\n");
        cssContent.append("   GROUPED CHAT LAYOUT (Slack-style)\n");
        cssContent.append("   ============================================= */\n\n");

        for (CSSRule rule : rules) {
            cssContent.append(rule.toString()).append("\n\n");
        }

        try (FileWriter writer = new FileWriter(filename)) {
            writer.write(cssContent.toString());
        }
    }

    static class CSSRule {
        private String selector;
        private String parentSelector; // For nested rules like media queries
        private List<String> declarations = new ArrayList<>();

        public CSSRule(String selector) {
            this.selector = selector;
        }

        public CSSRule(String parentSelector, String selector) {
            this.parentSelector = parentSelector;
            this.selector = selector;
        }

        public void addDeclaration(String property, String value) {
            declarations.add(property + ": " + value + ";");
        }

        public void addDeclaration(String declaration) {
            declarations.add(declaration);
        }

        @Override
        public String toString() {
            StringBuilder result = new StringBuilder();
            
            if (parentSelector != null && parentSelector.startsWith("@media")) {
                result.append(parentSelector).append(" {\n  ");
            } else if (parentSelector != null) {
                result.append(parentSelector).append(" ");
            }
            
            result.append(selector).append(" {\n");
            
            for (String declaration : declarations) {
                result.append("  ").append(declaration).append("\n");
            }
            
            result.append("}");
            
            if (parentSelector != null && parentSelector.startsWith("@media")) {
                result.append("\n}");
            }
            
            return result.toString();
        }
    }
}
