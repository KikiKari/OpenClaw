#!/usr/bin/env tclsh
# sidepanel.html — portiert nach tcl
# Quelle: html, Projects@TikTok-Live-Companion:plugin-source/browser-extension/sidepanel.html
# Erzeugt: 2026-11-01 durch ABSTRACTIONS_MANAGER.py

# Tcl/Tk Port von sidepanel.html
package require Tk

# Hauptfenster konfigurieren
wm title . "TikTok LIVE Companion"
wm resizable . false false

# CSS-ähnliche Stildefinitionen (als Tcl-Prozeduren)
proc createStyle {} {
    # Diese Prozedur würde im echten Tcl-Code die Stildefinitionen enthalten
    # Für diese Konvertierung konzentrieren wir uns auf die Struktur
}

# Hilfsprozedur zum Erstellen von Sections
proc createSection {parent id heading actionsWidgets} {
    set frame [ttk::frame $parent.$id]
    
    # Titelzeile mit Aktionen
    set titleFrame [ttk::frame $frame.title]
    ttk::label $titleFrame.heading -text $heading
    
    # Aktionselemente hinzufügen
    foreach widget $actionsWidgets {
        eval $widget
    }
    
    pack $titleFrame.heading -side left -padx 5
    pack $titleFrame -fill x -pady 2
    
    pack $frame -fill both -expand true -pady 2
    return $frame
}

# Dokumentstruktur erstellen
proc buildDocument {} {
    # Kopfbereich (versteckt)
    label .pageTitle -text "" -hidden true
    pack .pageTitle
    
    # Hauptbereich
    set main [ttk::frame .main]
    pack $main -fill both -expand true -padx 5 -pady 5
    
    # Chat Section
    set chatSection [createSection $main chat "Chat" {
        ttk::label .chatLed -text "●" -foreground gray
        button .chatCount -text "0" -command {}
        button .refreshChat -text "Reset" -command {}
        button .toggleSpeech -text "On" -command {}
        ttk::label .speechLed -text "●" -foreground gray
    }]
    
    # Chat Liste
    text .chatList -height 5 -state disabled -wrap word
    .chatList insert end "Noch keine Chatnachrichten erkannt."
    pack .chatList -fill x -pady 5
    
    # Sprachstatus
    label .speechStatus -text "Vorlesen ist ausgeschaltet."
    pack .speechStatus
    
    # Lautstärkeregler
    frame .volumeControl
    label .volumeLabel -text "Vorleselautstärke"
    scale .speechVolume -from 0 -to 100 -orient horizontal -resolution 5 -variable speechVol
    label .volumeOutput -textvariable speechVol -text "100%"
    pack .volumeLabel .speechVolume .volumeOutput -side left -padx 5
    pack .volumeControl -fill x
    
    # Steuerbuttons
    frame .speechButtons
    button .serviceAction -text "Sprachdienst" -command {}
    button .sherpaAction -text "Sherpa" -command {}
    button .openSpeechSettings -text "Einstellungen" -command {}
    pack .serviceAction .sherpaAction .openSpeechSettings -side left -padx 5
    pack .speechButtons -pady 5
    
    # Servicestatus
    label .serviceStatus -text "Lokaler Sprachdienst noch nicht geprüft."
    pack .serviceStatus
    
    # Setup Button (versteckt)
    button .copyServiceSetup -text "Installation abschließen!" -command {}
    .copyServiceSetup configure -hidden true
    pack .copyServiceSetup
    
    # LIVE-Information Section
    set statsSection [createSection $main stats "LIVE-Information" {
        label .statsLive -text "warte"
    }]
    
    # Status Grid
    frame .liveStats
    pack .liveStats -fill both -expand true -pady 5
    
    # Stats Status
    label .statsStatus -text ""
    pack .statsStatus
    
    # PROFIL-Information Section
    set pageInfoSection [createSection $main pageInfo "PROFIL-Information" {
        label .pageInfoSource -text "Metadaten"
        button .refreshPageInfo -text "Refresh" -command {}
        button .forcePageInfo -text "Force" -command {}
    }]
    
    # Profilinformationen
    frame .profileInfo -hidden true
    pack .profileInfo -fill x
    
    # Zusammenfassung
    frame .summaryInfo
    pack .summaryInfo -fill x
    
    # Connection Section
    set hookSection [createSection $main hook "Connection" {
        button .resetTab -text "Reset" -command {}
        checkbutton .hookAutostart -text "" -variable hookAuto
        ttk::label .hookLed -text "●" -foreground gray
    }]
    
    # Connection Buttons
    frame .hookButtons
    button .toggleHook -text "On" -command {}
    button .openConnectionSettings -text "Einstellungen" -command {}
    button .openEmbedLive -text "Embed" -command {}
    button .openNormalLive -text "Browser" -command {}
    button .playerVlcFrame -text "Player" -command {}
    pack .toggleHook .openConnectionSettings .openEmbedLive .openNormalLive .playerVlcFrame -side left -padx 2
    pack .hookButtons -pady 5
    
    # Connection Status
    frame .connectionStatus
    ttk::label .connLed -text "●" -foreground gray
    label .hookStatus -text ""
    pack .connLed .hookStatus -side left -padx 5
    pack .connectionStatus
    
    # Embed Status
    label .embedStartupStatus -text "" -hidden true
    button .cancelEmbedStartup -text "Embed-Start abbrechen" -hidden true -command {}
    pack .embedStartupStatus .cancelEmbedStartup -pady 2
    
    # Reconnect Status
    label .hookReconnectStatus -text "Hook-Reconnect: aus"
    label .playerRecoveryStatus -text "Player-Recovery: aus"
    pack .hookReconnectStatus .playerRecoveryStatus -pady 2
    
    # Player Section
    set playerSection [createSection $main player "Player" {
        button .playerReplay -text "Neu laden" -command {}
        checkbutton .limiterEnabled -text "" -variable limiterOn
        ttk::label .limiterLed -text "●" -foreground gray
    }]
    
    # Player Controls
    frame .playerControls
    button .playerPlay -text "Play" -command {}
    button .playerMute -text "Mute" -command {}
    button .playerPip -text "Bild-in-Bild" -command {}
    button .playerFullscreen -text "Vollbild" -command {}
    button .playerReport -text "Meldung" -command {}
    pack .playerPlay .playerMute .playerPip .playerFullscreen .playerReport -side left -padx 2
    pack .playerControls -pady 5
    
    # Audio Controls
    frame .audioControls
    
    # Volume Control
    frame .volControl
    label .playerVolumeLabel -text "Lautstärke"
    scale .playerVolume -from 0 -to 100 -orient horizontal -resolution 1 -variable playerVol
    label .playerVolumeOutput -textvariable playerVol -text "–"
    pack .playerVolumeLabel .playerVolume .playerVolumeOutput -side left -padx 5
    pack .volControl -pady 2
    
    # Peak Meter
    frame .peakRow
    label .peakLabel -text "Spitzenpegel"
    label .playerPeak -text "–" -font {Helvetica 10 bold}
    pack .peakLabel .playerPeak -side left -padx 5
    pack .peakRow -pady 2
    
    # Limiter Strength
    frame .limiterControl
    label .limiterStrengthLabel -text "Schutzstärke"
    scale .limiterStrength -from 0 -to 100 -orient horizontal -resolution 1 -variable limiterStrength
    label .limiterStrengthOutput -textvariable limiterStrength -text "30"
    pack .limiterStrengthLabel .limiterStrength .limiterStrengthOutput -side left -padx 5
    pack .limiterControl -pady 2
    
    pack .audioControls -fill x
    
    # Multi-Guest Status
    label .multiGuestStatus -text "Verbundene Streams: noch nicht erkannt."
    pack .multiGuestStatus -pady 2
    
    # Player Status
    label .playerStatus -text "Warte auf den TikTok-Player."
    pack .playerStatus
    
    # Player Time (versteckt)
    label .playerTime -text "–" -hidden true
    pack .playerTime
    
    # Top-Chatter Section
    set topChattersSection [createSection $main topChatters "Top-Chatter" {
        button .openAudience -text "Zuschauer*innen" -command {}
    }]
    
    # Team Tag Status
    label .teamTagStatus -text "Teamkürzel: noch nicht erkannt."
    pack .teamTagStatus -pady 2
    
    # Top Chatters List
    text .topChatters -height 4 -state disabled -wrap word
    .topChatters insert end "Noch keine Personen im Chat beobachtet."
    pack .topChatters -fill x
    
    # Top Chatters Actions
    frame .topChattersActions -hidden true
    button .topChattersReset -text "Reset" -command {}
    button .topChattersMore -text "mehr…" -command {}
    pack .topChattersReset .topChattersMore -side left -padx 5
    pack .topChattersActions -pady 2
    
    # LIVE-Empfehlungen Section
    set recommendationsSection [createSection $main recommendations "LIVE-Empfehlungen" {
        label .recommendationStatus -text "bereit"
    }]
    
    # Recommendation Controls
    frame .recommendationControls
    # Anzahl
    frame .recLimit
    label .limitLabel -text "Anzahl"
    entry .recommendationLimit -textvariable recLimit -width 5
    set recLimit 20
    pack .limitLabel .recommendationLimit -side left -padx 5
    # Sortierung
    frame .recSort
    label .sortLabel -text "Sortierung"
    ttk::combobox .recommendationSort -values {"TikTok-Reihenfolge" "Zuschauer*innen"} -state readonly
    pack .sortLabel .recommendationSort -side left -padx 5
    pack .recLimit .recSort -side left -padx 10
    pack .recommendationControls -pady 5
    
    # Recommendation Buttons
    frame .recButtons
    button .scanRecommendations -text "Empfehlungen scannen" -command {}
    button .cancelRecommendations -text "Abbrechen" -hidden true -command {}
    pack .scanRecommendations .cancelRecommendations -side left -padx 5
    pack .recButtons -pady 5
    
    # Recommendation Progress
    label .recommendationProgress -text "Noch kein Scan gestartet."
    pack .recommendationProgress -pady 2
    
    # Recommendation List
    text .recommendationList -height 4 -state disabled -wrap word
    .recommendationList insert end "Noch keine Empfehlungen erfasst."
    pack .recommendationList -fill x
    
    # Recommendation Actions
    frame .recommendationActions -hidden true
    button .recommendationMore -text "mehr…" -command {}
    pack .recommendationMore -pady 2
    pack .recommendationActions
    
    # STATUS-Monitor Section
    set overviewSection [createSection $main overview "STATUS-Monitor" {
        button .overviewSettings -text "Monitor Einstellungen" -command {}
        button .overviewReset -text "Streamnamen leeren" -command {}
        checkbutton .overviewEnabled -text "" -variable overviewOn
        ttk::label .overviewLed -text "●" -foreground gray
    }]
    
    # Overview Rows
    frame .overviewRows
    pack .overviewRows -fill both -expand true -pady 5
    
    # Overview Actions
    frame .overviewActions
    button .overviewCheck -text "Jetzt prüfen" -command {}
    button .overviewCopy -text "Alle kopieren" -command {}
    button .overviewOpen -text "Overview" -command {}
    pack .overviewCheck .overviewCopy .overviewOpen -side left -padx 5
    pack .overviewActions -pady 5
    
    # Overview More Actions
    frame .overviewMoreActions
    button .overviewCollapse -text "Reset" -hidden true -command {}
    button .overviewMoreBtn -text "mehr…" -command {}
    pack .overviewCollapse .overviewMoreBtn -side left -padx 5
    pack .overviewMoreActions -pady 2
    
    # Overview Message
    label .overviewMessage -text "" -hidden true
    pack .overviewMessage
    
    # Titel Section
    set captionSection [createSection $main caption "Titel" {
        button .scanButton -text "Status" -command {}
    }]
    
    # Caption Status Grid
    frame .captionStatus
    pack .captionStatus -fill both -expand true -pady 5
    
    # Enable Captions Button
    button .enableCaptions -text "Untertitel" -command {}
    pack .enableCaptions -pady 5
    
    # Caption Action Status
    label .captionActionStatus -text ""
    pack .captionActionStatus
    
    # Songs Section
    set songSection [createSection $main songs "Songs" {
        checkbutton .songEnabled -text "" -variable songOn
        ttk::label .songLed -text "●" -foreground gray
    }]
    
    # Recognize Song Button
    button .recognizeSong -text "Jetzt erkennen" -state disabled -command {}
    pack .recognizeSong -pady 5
    
    # Song Status
    label .songStatus -text ""
    pack .songStatus
    
    # Song Result (versteckt)
    frame .songResult -hidden true
    pack .songResult
    
    # HAR-Logs Section
    set linksSection [createSection $main harLogs "HAR-Logs" {
        label .mediaCount -text "0"
    }]
    
    # Media List
    text .mediaList -height 4 -state disabled -wrap word
    .mediaList insert end "Noch keine FLV-/HLS-Links erkannt."
    pack .mediaList -fill x
    
    # LIVE-Logs Section
    set logSection [createSection $main liveLogs "LIVE-Logs" {
        ttk::label .logLed -text "●" -foreground gray
        label .captionCount -text "0"
        button .clearLog -text "Reset" -command {}
        checkbutton .liveLogsEnabled -text "" -variable logsOn
        ttk::label .logsLed -text "●" -foreground gray
    }]
    
    # Log Export Buttons
    frame .logButtons
    button .exportLog -text "JSON-L-Export" -command {}
    button .exportCaptionRaw -text "RAW-JSON-Export" -command {}
    pack .exportLog .exportCaptionRaw -side left -padx 5
    pack .logButtons -pady 5
    
    # Caption List
    text .captionList -height 4 -state disabled -wrap word
    .captionList insert end "Noch keine CaptionMessages empfangen."
    pack .captionList -fill x
    
    # Debugmodus Section
    set debugSection [createSection $main debug "Debugmodus" {
        ttk::label .debugLed -text "●" -foreground gray
        label .debugCount -text "0"
        button .clearDebug -text "Reset" -command {}
        checkbutton .debugEnabled -text "" -variable debugOn
        ttk::label .debugStatusLed -text "●" -foreground gray
    }]
    
    # Debug Export Button
    button .exportDebug -text "Debug exportieren" -command {}
    pack .exportDebug -pady 5
    
    # Empty paragraph for spacing
    label .emptyPara -text ""
    pack .emptyPara
    
    # Audience Modal
    frame .audienceModal -hidden true
    frame .audienceModal.content
    frame .audienceModal.content.title
    label .audienceModal.content.title.heading -text "Im Chat beobachtete Personen"
    button .closeAudience -text "Schließen" -command {}
    pack .audienceModal.content.title.heading .closeAudience -side left -padx 5
    pack .audienceModal.content.title -fill x -pady 2
    
    label .audienceLimit -text ""
    pack .audienceLimit -pady 2
    
    frame .audienceList
    pack .audienceList -fill both -expand true
    
    pack .audienceModal.content -fill both -expand true -padx 10 -pady 10
    pack .audienceModal -fill both -expand true
    
    # Speech Settings Modal
    frame .speechSettingsModal -hidden true
    frame .speechSettingsModal.content
    frame .speechSettingsModal.content.title
    label .speechSettingsModal.content.title.heading -text "Erweiterte Einstellungen"
    button .closeSpeechSettings -text "Schließen" -command {}
    pack .speechSettingsModal.content.title.heading .closeSpeechSettings -side left -padx 5
    pack .speechSettingsModal.content.title -fill x -pady 2
    
    # Settings Grid
    frame .settingsGrid
    
    # Icon Style Setting
    frame .iconStyleSetting
    label .iconStyleLabel -text "Icon-Stil"
    ttk::combobox .iconStyle -values {"3D / Plastisch" "Glass / Realistisch" "Minimal / Linear"} -state readonly
    pack .iconStyleLabel .iconStyle -side left -padx 5
    pack .iconStyleSetting -pady 2
    
    # Language Setting
    frame .languageSetting
    label .languageLabel -text "Sprache"
    ttk::combobox .speechLanguage -values {"Auto" "Deutsch" "Englisch" "Russisch" "Ukrainisch" "Bulgarisch" "Serbisch" "Kasachisch" "Chinesisch" "Japanisch" "Koreanisch" "Arabisch" "Persisch" "Urdu" "Hindi" "Nepali" "Malayalam"} -state readonly
    pack .languageLabel .speechLanguage -side left -padx 5
    pack .languageSetting -pady 2
    
    # Voice Setting
    frame .voiceSetting
    label .voiceLabel -text "Stimme"
    ttk::combobox .speechVoice -values {"Standard"} -state readonly
    pack .voiceLabel .speechVoice -side left -padx 5
    pack .voiceSetting -pady 2
    
    # AudD Token Setting
    frame .auddTokenSetting
    label .auddTokenLabel -text "AudD API-Token (optional - https://AudD.io Trial/Paid)"
    entry .auddToken -show "*" -takefocus 0
    pack .auddTokenLabel -pady 2
    pack .auddToken -fill x
    pack .auddTokenSetting -pady 2
    
    # Pairing Code Setting
    frame .pairingCodeSetting
    label .pairingCodeLabel -text "Pairing-Code"
    entry .pairingCode -show "*" -takefocus 0
    pack .pairingCodeLabel -pady 2
    pack .pairingCode -fill x
    pack .pairingCodeSetting -pady 2
    
    # Universal API Key
    frame .apiKeySetting
    label .apiKeyLabel -text "Universal API-Key"
    entry .universalCaptionApiKey -show "*" -takefocus 0
    pack .apiKeyLabel -pady 2
    pack .universalCaptionApiKey -fill x
    pack .apiKeySetting -pady 2
    
    pack .iconStyleSetting .languageSetting .voiceSetting .auddTokenSetting .pairingCodeSetting .apiKeySetting -fill x -pady 2
    pack .settingsGrid -fill both -expand true -pady 5
    
    # Option Rows
    frame .options
    
    # Speak Names
    frame .speakNamesOption
    checkbutton .speakNames -text "Chatnamen sprechen" -variable speakNamesVar -onvalue 1 -offvalue 0
    set speakNamesVar 1
    pack .speakNames -side left
    pack .speakNamesOption -anchor w -pady 2
    
    # Shorten Names
    frame .shortenNamesOption
    checkbutton .shortenNames -text "Chatnamen kürzen" -variable shortenNamesVar -onvalue 1 -offvalue 0
    pack .shortenNames -side left
    pack .shortenNamesOption -anchor w -pady 2
    
    # Auto Chat Refresh
    frame .autoChatRefreshOption
    checkbutton .autoChatRefresh -text "Auto-Chat Refresh" -variable autoRefreshVar -onvalue 1 -offvalue 0
    entry .autoChatRefreshMinutes -textvariable refreshMinutes -width 5
    set refreshMinutes 5
    label .minutesLabel -text "min."
    pack .autoChatRefresh .autoChatRefreshMinutes .minutesLabel -side left -padx 5
    pack .autoChatRefreshOption -anchor w -pady 2
    
    # Game Mode
    frame .gameModeOption
    checkbutton .gameMode -text "Game-Mode (Spam-, Emoji, usw. Chatfilter)" -variable gameModeVar -onvalue 1 -offvalue 0
    pack .gameMode -side left
    pack .gameModeOption -anchor w -pady 2
    
    # External Speech Triggers
    frame .externalTriggersOption
    frame .triggerFilter
    checkbutton .filterExternalSpeechTriggers -text "Trigger filtern (ext. Sprachdienste)" -variable filterTriggersVar -onvalue 1 -offvalue 0
    pack .filterExternalSpeechTriggers -side left
    pack .triggerFilter -anchor w
    
    entry .externalSpeechTriggerCharacters -textvariable triggerChars -width 10
    set triggerChars "."
    label .charsLabel -text "Triggerzeichen, maximal fünf Sonderzeichen"
    pack .externalSpeechTriggerCharacters .charsLabel -side left -padx 5
    pack .externalTriggersOption -anchor w -pady 2
    
    # Keep Speech Active
    frame .keepSpeechActiveOption
    checkbutton .keepSpeechActive -text "Vorlesen dauerhaft" -variable keepSpeechVar -onvalue 1 -offvalue 0
    pack .keepSpeechActive -side left
    pack .keepSpeechActiveOption -anchor w -pady 2
    
    pack .options -fill x
    
    pack .speechSettingsModal.content -fill both -expand true -padx 10 -pady 10
    pack .speechSettingsModal -fill both -expand true
    
    # Chat History Modal
    frame .chatHistoryModal -hidden true
    frame .chatHistoryModal.content
    frame .chatHistoryModal.content.title
    label .chatHistoryModal.content.title.heading -text "Gesammelte Chatnachrichten"
    button .closeChatHistory -text "Schließen" -command {}
    pack .chatHistoryModal.content.title.heading .closeChatHistory -side left -padx 5
    pack .chatHistoryModal.content.title -fill x -pady 2
    
    label .chatHistoryLimit -text ""
    pack .chatHistoryLimit -pady 2
    
    frame .chatHistoryList
    pack .chatHistoryList -fill both -expand true
    
    pack .chatHistoryModal.content -fill both -expand true -padx 10 -pady 10
    pack .chatHistoryModal -fill both -expand true
    
    # Recommendation Modal
    frame .recommendationModal -hidden true
    frame .recommendationModal.content
    frame .recommendationModal.content.title
    label .recommendationModal.content.title.heading -text "Gescannte LIVE-Empfehlungen"
    button .closeRecommendations -text "Schließen" -command {}
    pack .recommendationModal.content.title.heading .closeRecommendations -side left -padx 5
    pack .recommendationModal.content.title -fill x -pady 2
    
    frame .recommendationModalList
    pack .recommendationModalList -fill both -expand true
    
    pack .recommendationModal.content -fill both -expand true -padx 10 -pady 10
    pack .recommendationModal -fill both -expand true
    
    # Notice Area
    label .notice -text "" -foreground red
    pack .notice -pady 5
    
    # Connection Settings Modal
    frame .connectionSettingsModal -hidden true
    frame .connectionSettingsModal.content
    frame .connectionSettingsModal.content.title
    label .connectionSettingsModal.content.title.heading -text "Connection-Einstellungen"
    button .closeConnectionSettings -text "Schließen" -command {}
    pack .connectionSettingsModal.content.title.heading .closeConnectionSettings -side left -padx 5
    pack .connectionSettingsModal.content.title -fill x -pady 2
    
    # Top Setting
    frame .connectionTopOption
    checkbutton .connectionTop -text "Connection @ Top" -variable connTopVar -onvalue 1 -offvalue 0
    pack .connectionTop -side left
    pack .connectionTopOption -anchor w -pady 2
    
    # Hook Reconnect Setting
    frame .hookReconnectOption
    checkbutton .hookReconnect -text "Hook-Reconnect" -variable hookReconnectVar -onvalue 1 -offvalue 0
    entry .hookReconnectSeconds -textvariable reconnectSecs -width 5
    set reconnectSecs 3
    label .secsLabel -text "Sek."
    pack .hookReconnect .hookReconnectSeconds .secsLabel -side left -padx 5
    pack .hookReconnectOption -anchor w -pady 2
    
    # Quick Recover Setting
    frame .quickRecoverOption
    checkbutton .quickRecover -text "Player-Recovery" -variable quickRecoverVar -onvalue 1 -offvalue 0
    entry .quickRecoverSeconds -textvariable recoverSecs -width 5
    set recoverSecs 3
    label .recoverSecsLabel -text "Sek."
    pack .quickRecover .quickRecoverSeconds .recoverSecsLabel -side left -padx 5
    pack .quickRecoverOption -anchor w -pady 2
    
    pack .connectionSettingsModal.content -fill both -expand true -padx 10 -pady 10
    pack .connectionSettingsModal -fill both -expand true
    
    # Overview Settings Modal
    frame .overviewSettingsModal -hidden true
    frame .overviewSettingsModal.content
    frame .overviewSettingsModal.content.title
    label .overviewSettingsModal.content.title.heading -text "Monitor Einstellungen"
    button .overviewSettingsClose -text "Schließen" -command {}
    pack .overviewSettingsModal.content.title.heading .overviewSettingsClose -side left -padx 5
    pack .overviewSettingsModal.content.title -fill x -pady 2
    
    # Interval Setting
    frame .intervalSetting
    label .intervalLabel -text "Prüfintervall (Minuten)"
    entry .overviewInterval -textvariable overviewInterval -width 5
    set overviewInterval 5
    pack .intervalLabel .overviewInterval -side left -padx 5
    pack .intervalSetting -pady 2
    
    # Max Links Setting
    frame .maxLinksSetting
    label .maxLinksLabel -text "Maximale Links pro Stream"
    entry .overviewMaxLinks -textvariable maxLinks -width 5
    set maxLinks 5
    pack .maxLinksLabel .overviewMaxLinks -side left -padx 5
    pack .maxLinksSetting -pady 2
    
    # Overview Options
    frame .overviewOptions
    
    # Top Setting
    frame .overviewTopOption
    checkbutton .overviewTop -text "Monitor @ Top" -variable overviewTopVar -onvalue 1 -offvalue 0
    pack .overviewTop -side left
    pack .overviewTopOption -anchor w -pady 2
    
    # Show Links
    frame .showLinksOption
    checkbutton .overviewShowLinks -text "Streamlinks anzeigen" -variable showLinksVar -onvalue 1 -offvalue 0
    pack .overviewShowLinks -side left
    pack .showLinksOption -anchor w -pady 2
    
    # Auto Sort
    frame .autoSortOption
    checkbutton .overviewAutoSort -text "Online-Streams automatisch sortieren" -variable autoSortVar -onvalue 1 -offvalue 0
    pack .overviewAutoSort -side left
    pack .autoSortOption -anchor w -pady 2
    
    # Reverse
    frame .reverseOption
    checkbutton .overviewReverse -text "Übersicht von unten nach oben" -variable reverseVar -onvalue 1 -offvalue 0
    pack .overviewReverse -side left
    pack .reverseOption -anchor w -pady 2
    
    # Grid 2x2
    frame .grid2Option
    checkbutton .overviewGrid2 -text "Übersicht 2×2" -variable grid2Var -onvalue 1 -offvalue 0
    pack .overviewGrid2 -side left
    pack .grid2Option -anchor w -pady 2
    
    # Skip Online
    frame .skipOnlineOption
    checkbutton .overviewSkipOnline -text "Online-Streams nicht erneut prüfen" -variable skipOnlineVar -onvalue 1 -offvalue 0
    pack .overviewSkipOnline -side left
    pack .skipOnlineOption -anchor w -pady 2
    
    pack .overviewTopOption .showLinksOption .autoSortOption .reverseOption .grid2Option .skipOnlineOption -fill x
    pack .overviewOptions -fill x -pady 5
    
    pack .intervalSetting .maxLinksSetting .overviewOptions -fill x
    pack .overviewSettingsModal.content -fill both -expand true -padx 10 -pady 10
    pack .overviewSettingsModal -fill both -expand true
    
    # Overview Links Modal
    frame .overviewLinksModal -hidden true
    frame .overviewLinksModal.content
    frame .overviewLinksModal.content.title
    label .overviewLinksModal.content.title.heading -text "Streamlinks"
    button .overviewLinksClose -text "Schließen" -command {}
    pack .overviewLinksModal.content.title.heading .overviewLinksClose -side left -padx 5
    pack .overviewLinksModal.content.title -fill x -pady 2
    
    frame .overviewLinksList
    pack .overviewLinksList -fill both -expand true
    
    pack .overviewLinksModal.content -fill both -expand true -padx 10 -pady 10
    pack .overviewLinksModal -fill both -expand true
    
    # JavaScript References (als Kommentare)
    # <script src="content-core.js"></script>
    # <script src="sidepanel.js"></script>
    # <script src="status-overview-panel.js"></script>
    # <script src="icon-controls.js"></script>
}

# Hauptprogramm
proc main {args} {
    # Wenn ein Argument übergeben wurde, speichern wir die Ausgabe in eine Datei
    if {[llength $args] > 0} {
        set filename [lindex $args 0]
        set f [open $filename w]
        puts $f "<!doctype html>"
        puts $f "<html lang=\"de\">"
        puts $f "<head>"
        puts $f "  <meta charset=\"utf-8\">"
        puts $f "  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
        puts $f "  <title>TikTok LIVE Companion</title>"
        puts $f "  <link rel=\"stylesheet\" href=\"sidepanel.css\">"
        puts $f "  <link rel=\"stylesheet\" href=\"icon-controls.css\">"
        puts $f "  <link rel=\"stylesheet\" href=\"status-overview-panel.css\">"
        puts $f "</head>"
        puts $f "<body>"
        puts $f "  <p id=\"page-title\" hidden></p>"
        puts $f ""
        puts $f "  <main>"
        
        # Chat Section
        puts $f "    <section aria-labelledby=\"chat-heading\">"
        puts $f "      <div class=\"section-title\">"
        puts $f "        <h2 id=\"chat-heading\">Chat</h2>"
        puts $f "        <div class=\"title-actions\">"
        puts $f "          <span id=\"chat-led\" class=\"status-led off\" role=\"status\" aria-label=\"Chat inaktiv\" title=\"Chat inaktiv\"></span>"
        puts $f "          <button id=\"chat-count\" class=\"count count-button\" type=\"button\" aria-haspopup=\"dialog\" title=\"Gesammelte Chatzeilen öffnen\">0</button>"
        puts $f "          <button id=\"refresh-chat\" class=\"secondary compact\" title=\"Chatanzeige leeren\">Reset</button>"
        puts $f "          <button id=\"toggle-speech\" class=\"secondary compact\" aria-pressed=\"false\" aria-label=\"Vorlesen\">On</button>"
        puts $f "          <span id=\"speech-led\" class=\"status-led off\" role=\"status\" aria-label=\"Vorlesen inaktiv\" title=\"Vorlesen inaktiv\"></span>"
        puts $f "        </div>"
        puts $f "      </div>"
        puts $f "      <div id=\"chat-list\" class=\"chat-list empty\" role=\"log\" aria-live=\"polite\" aria-relevant=\"additions\" aria-label=\"Die letzten fünf bereinigten Chatnachrichten\">Noch keine Chatnachrichten erkannt.</div>"
        puts $f "      <p id=\"speech-status\" role=\"status\" class=\"inline-status\">Vorlesen ist ausgeschaltet.</p>"
        puts $f "      <div class=\"control-label\"><label for=\"speech-volume\">Vorleselautstärke</label><output id=\"speech-volume-output\" for=\"speech-volume\">100%</output></div>"
        puts $f "      <input id=\"speech-volume\" type=\"range\" min=\"0\" max=\"100\" step=\"5\" value=\"50\">"
        puts $f "      <div class=\"button-row\">"
        puts $f "        <button id=\"service-action\" class=\"secondary\">Sprachdienst</button>"
        puts $f "        <button id=\"sherpa-action\" class=\"secondary\">Sherpa</button>"
        puts $f "        <button id=\"open-speech-settings\" class=\"secondary compact settings-button\" type=\"button\" aria-label=\"Erweiterte Einstellungen öffnen\" aria-haspopup=\"dialog\" title=\"Einstellungen\"></button>"
        puts $f "      </div>"
        puts $f "      <p id=\"service-status\" class=\"inline-status\">Lokaler Sprachdienst noch nicht geprüft.</p>"
        puts $f "      <div id=\"service-setup\" class=\"inline-status\" hidden>"
        puts $f "        <button id=\"copy-service-setup\" class=\"secondary compact\">Installation abschließen!</button>"
        puts $f "      </div>"
        puts $f "    </section>"
        puts $f ""
        
        # LIVE-Information Section
        puts $f "    <section aria-labelledby=\"stats-heading\">"
        puts $f "      <div class=\"section-title\">"
        puts $f "        <
