#!/usr/bin/env tclsh
# about.html — portiert nach tcl
# Quelle: html, OpenClaw@gateway1:skills/scripting-utils/references/powershell/about.html
# auch in: OpenClaw@gateway2:skills/scripting-utils/references/powershell/about.html
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

proc generateHTML {filename} {
    set fp [open $filename w]
    
    puts $fp {<!DOCTYPE html>}
    puts $fp {<html class="layout layout-holy-grail   show-table-of-contents conceptual show-breadcrumb default-focus" lang="en-us" dir="ltr" data-authenticated="false" data-auth-status-determined="false" data-target="docs" x-ms-format-detection="none">}
    puts $fp {<head>}
    puts $fp {<title>About topics - PowerShell | Microsoft Learn</title>}
    puts $fp {<meta charset="utf-8" />}
    puts $fp {<meta name="viewport" content="width=device-width, initial-scale=1.0" />}
    puts $fp {<meta name="color-scheme" content="light dark" />}
    puts $fp {<meta name="description" content="About topics cover a range of concepts about PowerShell." />}
    puts $fp {<meta name="canonical" content="https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about?view=powershell-7.6" />}
    puts $fp {<meta name="twitter:card" content="summary" />}
    puts $fp {<meta name="twitter:site" content="@MicrosoftLearn" />}
    puts $fp {<meta property="og:type" content="website" />}
    puts $fp {<meta property="og:image:alt" content="About topics - PowerShell | Microsoft Learn" />}
    puts $fp {<meta property="og:image" content="https://learn.microsoft.com/media/logos/logo-powershell-social.png" />}
    puts $fp {<meta property="og:title" content="About topics - PowerShell" />}
    puts $fp {<meta property="og:url" content="https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about?view=powershell-7.6" />}
    puts $fp {<meta property="og:description" content="About topics cover a range of concepts about PowerShell." />}
    puts $fp {<meta name="platform_id" content="5035edbf-6e09-a6fa-a98d-bb2adc6ab1e0" />}
    puts $fp {<meta name="scope" content="PowerShell" />}
    puts $fp {<meta name="locale" content="en-us" />}
    puts $fp {<meta name="uhfHeaderId" content="MSDocsHeader-Powershell" />}
    puts $fp {<meta name="page_type" content="conceptual" />}
    puts $fp {<meta name="ROBOTS" content="INDEX, FOLLOW" />}
    puts $fp {<meta name="apiPlatform" content="powershell" />}
    puts $fp {<meta name="archive_url" content="https://learn.microsoft.com/previous-versions/powershell/scripting/overview" />}
    puts $fp {<meta name="breadcrumb_path" content="/powershell/scripting/bread/toc.json" />}
    puts $fp {<meta name="feedback_product_url" content="https://github.com/PowerShell/PowerShell/issues/new/choose" />}
    puts $fp {<meta name="feedback_help_link_url" content="https://learn.microsoft.com/powershell/scripting/community/community-support" />}
    puts $fp {<meta name="feedback_help_link_type" content="ask-the-community" />}
    puts $fp {<meta name="feedback_system" content="OpenSource" />}
    puts $fp {<meta name="hideScope" content="false" />}
    puts $fp {<meta name="author" content="sdwheeler" />}
    puts $fp {<meta name="ms.author" content="sewhee" />}
    puts $fp {<meta name="manager" content="jasongroce" />}
    puts $fp {<meta name="ms.devlang" content="powershell" />}
    puts $fp {<meta name="ms.service" content="powershell" />}
    puts $fp {<meta name="ms.tgt_pltfr" content="windows, macos, linux" />}
    puts $fp {<meta name="ms.update-cycle" content="365-days" />}
    puts $fp {<meta name="toc_preview" content="true" />}
    puts $fp {<meta name="ms.topic" content="reference" />}
    puts $fp {<meta name="products" content="https://authoring-docs-microsoft.poolparty.biz/devrel/2bdae855-045f-4535-b365-7b2e23824328" />}
    puts $fp {<meta name="products" content="https://authoring-docs-microsoft.poolparty.biz/devrel/8bce367e-2e90-4b56-9ed5-5e4e9f3a2dc3" />}
    puts $fp {<meta name="Locale" content="en-US" />}
    puts $fp {<meta name="ms.date" content="2026-01-18T00:00:00Z" />}
    puts $fp {<meta name="document_id" content="6d07e1b4-9109-26f3-5a6a-20b41b4c66a5" />}
    puts $fp {<meta name="document_version_independent_id" content="2bf88889-d533-2316-9add-a385ebbd4259" />}
    puts $fp {<meta name="updated_at" content="2026-04-02T22:11:00Z" />}
    puts $fp {<meta name="original_content_git_url" content="https://github.com/MicrosoftDocs/PowerShell-Docs/blob/live/reference/7.6/Microsoft.PowerShell.Core/About/About.md" />}
    puts $fp {<meta name="gitcommit" content="https://github.com/MicrosoftDocs/PowerShell-Docs/blob/7baf66776aea350bef39470600f075e85f30d7ef/reference/7.6/Microsoft.PowerShell.Core/About/About.md" />}
    puts $fp {<meta name="git_commit_id" content="7baf66776aea350bef39470600f075e85f30d7ef" />}
    puts $fp {<meta name="monikers" content="powershell-7.6" />}
    puts $fp {<meta name="default_moniker" content="powershell-7.6" />}
    puts $fp {<meta name="site_name" content="Docs" />}
    puts $fp {<meta name="depot_name" content="PowerShell.PowerShell_PowerShell-docs_reference" />}
    puts $fp {<meta name="schema" content="Conceptual" />}
    puts $fp {<meta name="toc_rel" content="../../psdocs/toc.json" />}
    puts $fp {<meta name="word_count" content="1965" />}
    puts $fp {<meta name="config_moniker_range" content="powershell-7.6" />}
    puts $fp {<meta name="asset_id" content="module/microsoft.powershell.core/about/about" />}
    puts $fp {<meta name="moniker_range_name" content="9b5469a01154ce5be5ffa44dbe12b832" />}
    puts $fp {<meta name="item_type" content="Content" />}
    puts $fp {<meta name="source_path" content="reference/7.6/Microsoft.PowerShell.Core/About/About.md" />}
    puts $fp {<meta name="previous_tlsh_hash" content="A12B7262301D8F2E7BE20B1A341CEF4F17F0448C116A19D0012D2537977E1D634728A866C7361B692370488BB39F759D46E8CE22829C53AA1F9127FE495D6A4EE2CDB7B6FC" />}
    puts $fp {<meta name="github_feedback_content_git_url" content="https://github.com/MicrosoftDocs/PowerShell-Docs/blob/main/reference/7.6/Microsoft.PowerShell.Core/About/About.md" />}
    puts $fp {<meta name="markdown_url" content="https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about?view=powershell-7.6&amp;accept=text/markdown" />}
    puts $fp {<link rel="stylesheet" href="/static/assets/0.4.03391.7726-67491f8e/styles/site.css" />}
    puts $fp {<script src="https://wcpstatic.microsoft.com/mscc/lib/v2/wcp-consent.js"></script>}
    puts $fp {<script src="https://js.monitor.azure.com/scripts/c/ms.jsll-4.min.js"></script>}
    puts $fp {<script src="/_themes/docs.theme/master/en-us/_themes/global/deprecation.js"></script>}
    puts $fp {<script id="msdocs-script">}
    puts $fp {var msDocs = \{}
    puts $fp {  "environment": \{}
    puts $fp {    "accessLevel": "online",}
    puts $fp {    "azurePortalHostname": "portal.azure.com",}
    puts $fp {    "reviewFeatures": false,}
    puts $fp {    "supportLevel": "production",}
    puts $fp {    "systemContent": true,}
    puts $fp {    "siteName": "learn",}
    puts $fp {    "legacyHosting": false}
    puts $fp {  \},}
    puts $fp {  "data": \{}
    puts $fp {    "contentLocale": "en-us",}
    puts $fp {    "contentDir": "ltr",}
    puts $fp {    "userLocale": "en-us",}
    puts $fp {    "userDir": "ltr",}
    puts $fp {    "pageTemplate": "Conceptual",}
    puts $fp {    "brand": "",}
    puts $fp {    "context": \{\},}
    puts $fp {    "standardFeedback": false,}
    puts $fp {    "showFeedbackReport": false,}
    puts $fp {    "feedbackHelpLinkType": "ask-the-community",}
    puts $fp {    "feedbackHelpLinkUrl": "https://learn.microsoft.com/powershell/scripting/community/community-support",}
    puts $fp {    "feedbackSystem": "OpenSource",}
    puts $fp {    "feedbackGitHubRepo": "",}
    puts $fp {    "feedbackProductUrl": "https://github.com/PowerShell/PowerShell/issues/new/choose",}
    puts $fp {    "extendBreadcrumb": false,}
    puts $fp {    "isEditDisplayable": true,}
    puts $fp {    "isPrivateUnauthorized": false,}
    puts $fp {    "hideViewSource": false,}
    puts $fp {    "isPermissioned": false,}
    puts $fp {    "hasRecommendations": false,}
    puts $fp {    "contributors": [}
    puts $fp {      \{}
    puts $fp {        "name": "sdwheeler",}
    puts $fp {        "url": "https://github.com/sdwheeler"}
    puts $fp {      \},}
    puts $fp {      \{}
    puts $fp {        "name": "SufficientDaikon",}
    puts $fp {        "url": "https://github.com/SufficientDaikon"}
    puts $fp {      \},}
    puts $fp {      \{}
    puts $fp {        "name": "surfingoldelephant",}
    puts $fp {        "url": "https://github.com/surfingoldelephant"}
    puts $fp {      \}}
    puts $fp {    ],}
    puts $fp {    "openSourceFeedbackIssueUrl": "https://github.com/MicrosoftDocs/PowerShell-Docs/issues/new?template=04-customer-feedback.yml",}
    puts $fp {    "openSourceFeedbackIssueTitle": "",}
    puts $fp {    "openSourceFeedbackIssueLabels": "needs-triage"}
    puts $fp {  \},}
    puts $fp {  "functions": \{\}}
    puts $fp {\};;}
    puts $fp {</script>}
    puts $fp {<script src="/static/assets/0.4.03391.7726-67491f8e/scripts/en-us/index-docs.js"></script>}
    puts $fp {</head>}
    puts $fp {<body id="body" data-bi-name="body" class="layout-body " lang="en-us" dir="ltr">}
    puts $fp {<header class="layout-body-header">}
    puts $fp {<div class="header-holder has-default-focus">}
    puts $fp {<a href="#main" style="z-index: 1070" class="outline-color-text visually-hidden-until-focused position-fixed inner-focus focus-visible top-0 left-0 right-0 padding-xs text-align-center background-color-body" >}
    puts $fp {Skip to main content}
    puts $fp {</a>}
    puts $fp {<a href="#" data-skip-to-ask-learn style="z-index: 1070" class="outline-color-text visually-hidden-until-focused position-fixed inner-focus focus-visible top-0 left-0 right-0 padding-xs text-align-center background-color-body" hidden>}
    puts $fp {Skip to Ask Learn chat experience}
    puts $fp {</a>}
    puts $fp {<div hidden id="cookie-consent-holder" data-test-id="cookie-consent-container"></div>}
    puts $fp {<div id="unsupported-browser" style="background-color: white; color: black; padding: 16px; border-bottom: 1px solid grey;" hidden>}
    puts $fp {<div style="max-width: 800px; margin: 0 auto;">}
    puts $fp {<p style="font-size: 24px">This browser is no longer supported.</p>}
    puts $fp {<p style="font-size: 16px; margin-top: 16px;">}
    puts $fp {Upgrade to Microsoft Edge to take advantage of the latest features, security updates, and technical support.}
    puts $fp {</p>}
    puts $fp {<div style="margin-top: 12px;">}
    puts $fp {<a href="https://go.microsoft.com/fwlink/p/?LinkID=2092881 " style="background-color: #0078d4; border: 1px solid #0078d4; color: white; padding: 6px 12px; border-radius: 2px; display: inline-block;">}
    puts $fp {Download Microsoft Edge}
    puts $fp {</a>}
    puts $fp {<a href="https://learn.microsoft.com/en-us/lifecycle/faq/internet-explorer-microsoft-edge" style="background-color: white; padding: 6px 12px; border: 1px solid #505050; color: #171717; border-radius: 2px; display: inline-block;">}
    puts $fp {More info about Internet Explorer and Microsoft Edge}
    puts $fp {</a>}
    puts $fp {</div>}
    puts $fp {</div>}
    puts $fp {</div>}
    puts $fp {<div id="ms--site-header" data-test-id="site-header-wrapper" itemscope="itemscope" itemtype="http://schema.org/Organization">}
    puts $fp {<div id="ms--mobile-nav" class="site-header display-none-tablet padding-inline-none gap-none" data-bi-name="mobile-header" data-test-id="mobile-header"></div>}
    puts $fp {<div id="ms--primary-nav" class="site-header display-none display-flex-tablet" data-bi-name="L1-header" data-test-id="primary-header"></div>}
    puts $fp {<div id="ms--secondary-nav" class="site-header display-none display-flex-tablet" data-bi-name="L2-header" data-test-id="secondary-header"></div>}
    puts $fp {</div>}
    puts $fp {<div data-banner>}
    puts $fp {<div id="disclaimer-holder"></div>}
    puts $fp {</div>}
    puts $fp {</div>}
    puts $fp {</header>}
    puts $fp {<section id="layout-body-menu" class="layout-body-menu display-flex" data-bi-name="menu">}
    puts $fp {<div id="left-container" class="left-container display-none display-block-tablet padding-inline-sm padding-bottom-sm width-full" data-toc-container="true">}
    puts $fp {<div id="ms--toc-content" class="height-full">}
    puts $fp {<nav id="affixed-left-container" class="margin-top-sm-tablet position-sticky display-flex flex-direction-column" aria-label="Primary" data-bi-name="left-toc" role="navigation"></nav>}
    puts $fp {</div>}
    puts $fp {<div id="ms--toc-content-collapsible" class="height-full" hidden>}
    puts $fp {<nav id="affixed-left-container" class="margin-top-sm-tablet position-sticky display-flex flex-direction-column" aria-label="Primary" data-bi-name="left-toc" role="navigation">}
    puts $fp {<div id="ms--collapsible-toc-header" class="display-flex flex-direction-row-reverse justify-content-space-between align-items-center margin-bottom-xxs">}
    puts $fp {<button type="button" class="button button-clear inner-focus" data-collapsible-toc-toggle aria-expanded="true" aria-controls="ms--collapsible-toc-content" aria-label="Table of contents">}
    puts $fp {<span class="icon font-size-xxl" aria-hidden="true">}
    puts $fp {<span class="docon docon-panel-left-contract"></span>}
    puts $fp {</span>}
    puts $fp {</button>}
    puts $fp {<div id="ms--collapsible-toc-moniker-slot" class="flex-grow-1"></div>}
    puts $fp {</div>}
    puts $fp {</nav>}
    puts $fp {</div>}
    puts $fp {</div>}
    puts $fp {</section>}
    puts $fp {<main id="main" role="main" class="layout-body-main " data-bi-name="content" lang="en-us" dir="ltr">}
    puts $fp {<div id="ms--content-header" class="content-header default-focus border-bottom-none" data-bi-name="content-header">}
    puts $fp {<div class="content-header-controls margin-xxs margin-inline-sm-tablet">}
    puts $fp {<button type="button" class="contents-button button button-sm margin-right-xxs" data-bi-name="contents-expand" aria-haspopup="true" data-contents-button>}
    puts $fp {<span class="icon" aria-hidden="true"><span class="docon docon-menu"></span></span>}
    puts $fp {<span class="contents-expand-title"> Table of contents </span>}
    puts $fp {</button>}
    puts $fp {<button type="button" class="ap-collapse-behavior ap-expanded button button-sm" data-bi-name="ap-collapse" aria-controls="action-panel">}
    puts $fp {<span class="icon" aria-hidden="true"><span class="docon docon-exit-mode"></span></span>}
    puts $fp {<span>Exit editor mode</span>}
    puts $fp {</button>}
    puts $fp {</div>}
    puts $fp {</div>}
    puts $fp {<div data-main-column class="padding-sm padding-top-none padding-top-sm-tablet">}
    puts $fp {<div>}
    puts $fp {<div id="article-header" class="background-color-body margin-bottom-xs display-none-print">}
    puts $fp {<div class="display-flex align-items-center justify-content-space-between">}
    puts $fp {<details id="article-header-breadcrumbs-overflow-popover" class="popover" data-for="article-header-breadcrumbs">}
    puts $fp {<summary class="button button-clear button-primary button-sm inner-focus" aria-label="All breadcrumbs">}
    puts $fp {<span class="icon" aria-hidden="true">}
    puts $fp {<span class="docon docon-more"></span>}
    puts $fp {</span>}
    puts $fp {</summary>}
    puts $fp {<div id="article-header-breadcrumbs-overflow" class="popover-content padding-none"></div>}
    puts $fp {</details>}
    puts $fp {<bread-crumbs id="article-header-breadcrumbs" role="group" aria-label="Breadcrumbs" data-test-id="article-header-breadcrumbs" class="overflow-hidden flex-grow-1 margin-right-sm margin-right-md-tablet margin-right-lg-desktop margin-left-negative-xxs padding-left-xxs"></bread-crumbs>}
    puts $fp {<div id="article-header-page-actions" class="opacity-none margin-left-auto display-flex flex-wrap-no-wrap align-items-stretch">}
    puts $fp {<button class="button button-sm border-none inner-focus display-none-tablet flex-shrink-0 " data-bi-name="ask-learn-assistant-entry" data-test-id="ask-learn-assistant-modal-entry-mobile" data-ask-learn-modal-entry type="button" style="min-width: max-content;" aria-expanded="false" aria-label="Ask Learn" hidden>}
    puts $fp {<span class="icon font-size-lg" aria-hidden="true">}
    puts $fp {<span class="docon docon-chat-sparkle-fill gradient-ask-learn-logo"></span>}
    puts $fp {</span>}
    puts $fp {</button>}
    puts $fp {<button class="button button-sm display-none display-inline-flex-tablet display-none-desktop flex-shrink-0 margin-right-xxs border-color-ask-learn " data-bi-name="ask-learn-assistant-entry" data-test-id="ask-learn-assistant-modal-entry-tablet" data-ask-learn-modal-entry type="button" style="min-width: max-content;" aria-expanded="false" hidden>}
    puts $fp {<span class="icon font-size-lg" aria-hidden="true">}
    puts $fp {<span class="docon docon-chat-sparkle-fill gradient-ask-learn-logo"></span>}
    puts $fp {</span>}
    puts $fp {<span>Ask Learn</span>}
    puts $fp {</button>}
    puts $fp {<button class="button button-sm display-none flex-shrink-0 display-inline-flex-desktop margin-right-xxs border-color-ask-learn " data-bi-name="ask-learn-assistant-entry" data-test-id="ask-learn-assistant-flyout-entry" data-ask-learn-flyout-entry data-flyout-button="toggle" type="button" style="min-width: max-content;" aria-expanded="false" aria-controls="ask-learn-flyout" hidden>}
    puts $fp {<span class="icon font-size-lg" aria-hidden="true">}
    puts $fp {<span class="docon docon-chat-sparkle-fill gradient-ask-learn-logo"></span>}
    puts $fp {</span>}
    puts $fp {<span>Ask Learn</span>}
    puts $fp {</button>}
    puts $fp {<button type="button" id="ms--focus-mode-button" data-focus-mode data-bi-name="focus-mode-entry" class="button button-sm flex-shrink-0 margin-right-xxs display-none display-inline-flex-desktop">}
    puts $fp {<span class="icon font-size-lg" aria-hidden="true">}
    puts $fp {<span class="docon docon-glasses"></span>}
    puts $fp {</span>}
    puts $fp {<span>Focus mode</span>}
    puts $fp {</button>}
    puts $fp {<details class="popover popover-right" id="article-header-page-actions-overflow">}
    puts $fp {<summary class="justify-content-flex-start button button-clear button-sm button-primary inner-focus" aria-label="More actions" title="More actions">}
    puts $fp {<span class="icon" aria-hidden="true">}
    puts $fp {<span class="docon docon-more-vertical"></span>}
    puts $fp {</span>}
    puts $fp {</summary>}
    puts $fp {<div class="popover-content">}
    puts $fp {<button data-page-action-item="overflow-mobile" type="button" class="button-block button-sm inner-focus button button-clear display-none-tablet justify-content-flex-start text-align-left" data-bi-name="contents-expand" data-contents-button data-popover-close>}
    puts $fp {<span class="icon" aria-hidden="true"><span class="docon docon-editor-list-bullet"></span></span>}
    puts $fp {<span class="contents-expand-title">Table of contents</span>}
    puts $fp {</button>}
    puts $fp {<a id="lang-link-overflow" class="button-sm inner-focus button button-clear button-block justify-content-flex-start text-align-left" data-bi-name="language-toggle" data-page-action-item="overflow-all" data-check-hidden="true" data-read-in-link href="#" hidden>}
    puts $fp {<span class="icon" aria-hidden="true" data-read-in-link-icon>}
    puts $fp {<span class="docon docon-locale-globe"></span>}
    puts $fp {</span>}
    puts $fp {<span data-read-in-link-text>Read in English</span>}
    puts $fp {</a>}
    puts $fp {<button type="button" class="collection button button-clear button-sm button-block justify-content-flex-start text-align-left inner-focus" data-list-type="collection" data-bi-name="collection" data-page-action-item="overflow-all" data-check-hidden="true" data-popover-close>}
    puts $fp {<span class="icon" aria-hidden="true">}
    puts $fp {<span class="docon docon-circle-addition"></span>}
    puts $fp {</span>}
    puts $fp {<span class="collection-status">Add</span>}
    puts $fp {</button>}
    puts $fp {<button type="button" class="collection button button-block button-clear button-sm justify-content-flex-start text-align-left inner-focus" data-list-type="plan" data-bi-name="plan" data-page-action-item="overflow-all" data-check-hidden="true" data-popover-close hidden>}
    puts $fp {<span class="icon" aria-hidden="true">}
    puts $fp {<span class="docon docon-circle-addition"></span>}
    puts $fp {</span>}
    puts $fp {<span class="plan-status">Add to plan</span>}
    puts $fp {</button>}
    puts $fp {<a data-contenteditbtn class="button button-clear button-block button-sm inner-focus justify-content-flex-start text-align-left text-decoration-none" data-bi-name="edit" href="https://github.com/MicrosoftDocs/PowerShell-Docs/blob/main/reference/7.6/Microsoft.PowerShell.Core/About/About.md" data-original_content_git_url="https://github.com/MicrosoftDocs/PowerShell-Docs/blob/live/reference/7.6/Microsoft.PowerShell.Core/About/About.md" data-original_content_git_url_template="{repo}/blob/{branch}/reference/7.6/Microsoft.PowerShell.Core/About/About.md" data-pr_repo="" data-pr_branch="">}
    puts $fp {<span class="icon" aria-hidden="true">}
    puts $fp {<span class="docon docon-edit-outline"></span>}
    puts $fp {</span>}
    puts $fp {<span>Edit</span>}
    puts $fp {</a>}
    puts $fp {<hr class="margin-block-xxs" />}
    puts $fp {<h4 class="font-size-sm padding-left-xxs">Share via</h4>}
    puts $fp {<a class="button button-clear button-sm inner-focus button-block justify-content-flex-start text-align-left text-decoration-none share-facebook" data-bi-name="facebook" data-page-action-item="overflow-all" href="#">}
    puts $fp {<span class="icon color-primary" aria-hidden="true">}
    puts $fp {<span class="docon docon-facebook-share"></span>}
    puts $fp {</span>}
    puts $fp {<span>Facebook</span>}
    puts $fp {</a>}
    puts $fp {<a href="#" class="button button-clear button-sm inner-focus button-block justify-content-flex-start text-align-left text-decoration-none share-twitter" data-bi-name="twitter" data-page-action-item="overflow-all">}
    puts $fp {<span class="icon color-text" aria-hidden="true">}
    puts $fp {<span class="docon docon-xlogo-share"></span>}
    puts $fp {</span>}
    puts $fp {<span>x.com</span>}
    puts $fp {</a>}
    puts $fp {<a href="#" class="button button-clear button-sm inner-focus button-block justify-content-flex-start text-align-left text-decoration-none share-linkedin" data-bi-name="linkedin" data-page-action-item="overflow-all">}
    puts $fp {<span class="icon color-primary" aria-hidden="true">}
    puts $fp {<span class="docon docon-linked-in-logo"></span>}
    puts $fp {</span>}
    puts $fp {<span>LinkedIn</span>}
    puts $fp {</a>}
    puts $fp {<a href="#" class="button button-clear button-sm inner-focus button-block justify-content-flex-start text-align-left text-decoration-none share-email" data-bi-name="email" data-page-action-item="overflow-all">}
    puts $fp {<span class="icon color-primary" aria-hidden="true">}
    puts $fp {<span class="docon docon-mail-message"></span>}
    puts $fp {</span>}
    puts $fp {<span>Email</span>}
    puts $fp {</a>}
    puts $fp {<hr class="margin-block-xxs" />}
    puts $fp {<button class="button button-block button-clear button-sm justify-content-flex-start text-align-left inner-focus" type="button" data-bi-name="copy-markdown" data-page-action-item="overflow-all" data-copy-markdown data-copy-state="idle" data-check-hidden="true">}
    puts $fp {<span class="icon color-primary" aria-hidden="true">}
    puts $fp {<span data-show-when="idle" class="docon docon-code-lang"></span>}
    puts $fp {<span data-show-when="loading" class="loader" hidden></span>}
    puts $fp {<span data-show-when="success" class="docon docon-check-mark" hidden></span>}
    puts $fp {</span>}
    puts $fp {<span>Copy Markdown</span>}
    puts $fp {</button>}
    puts $fp {<button class="button button-block button-clear button-sm justify-content-flex-start text-align-left inner-focus" type="button" data-bi-name="print" data-page-action-item="overflow-all" data-popover-close data-print-page data-check-hidden="true">}
    puts $fp {<span class="icon color-primary" aria-hidden="true">}
    puts $fp {<span class="docon docon-print"></span>}
    puts $fp {</span>}
    puts $fp {<span>Print</span>}
    puts $fp {</button>}
    puts $fp {</div>}
    puts $fp {</details>}
    puts $fp {</div>}
    puts $fp {</div>}
    puts $fp {</div>}
    puts $fp {<div unauthorized-private-section data-bi-name="permission-content-unauthorized-private" hidden>}
    puts $fp {<hr class="hr margin-top-xs margin-bottom-sm" />}
    puts $fp {<div class="notification notification-info">}
    puts $fp {<div class="notification-content">}
    puts $fp {<p class="margin-top-none notification-title">}
    puts $fp {<span class="icon" aria-hidden="true"><span class="docon docon-exclamation-circle-solid"></span></span>}
    puts $fp {<span>Note</span>}
    puts $fp {</p>}
    puts $fp {<p class="margin-top-none authentication-determined not-authenticated">}
    puts $fp {Access to this page requires authorization. You can try <a class="docs-sign-in" href="#" data-bi-name="permission-content-sign-in">signing in</a> or <a  class="docs-change-directory" data-bi-name="permisson-content-change-directory">changing directories</a>.}
    puts $fp {</p>}
    puts $fp {<p class="margin-top-none authentication-determined authenticated">}
    puts $fp {Access to this page requires authorization. You can try <a class="docs-change-directory" data-bi-name="permisson-content-change-directory">changing directories</a>.}
    puts $fp {</p>}
    puts $fp {</div>}
    puts $fp {</div>}
    puts $fp {</div>}
    puts $fp {<div class="content"><h1 id="about-topics">About topics</h1></div>}
    puts $fp {<div id="article-metadata" data-bi-name="article-metadata" data-test-id="article-metadata" class="page-metadata-container display-flex gap-xxs justify-content-space-between align-items-center flex-wrap-wrap">}
    puts $fp {<div id="user-feedback" class="margin-block-xxs display-none display-none-print" hidden data-hide-on-archived>}
    puts $fp {<button id="user-feedback-button" data-test-id="conceptual-feedback-button" class="button button-sm button-clear button-primary display-none" type="button" data-bi-name="user-feedback-button" data-user-feedback-button hidden>}
    puts $fp {<span class="icon" aria-hidden="true">}
    puts $fp {<span class="docon docon-like"></span>}
    puts $fp {</span>}
    puts $fp {<span>Feedback</span>}
    puts $fp {</button>}
    puts $fp {</div>}
    puts $fp {</div>}
    puts $fp {<div data-id="ai-summary" class="display-none-print">}
    puts $fp {<div id="ms--ai-summary-cta" class="margin-top-xs display-flex align-items-center">}
    puts $fp {<span class="icon" aria-hidden="true">}
    puts $fp {<span class="docon docon-sparkle-fill gradient-text-vivid"></span>}
    puts $fp {</span>}
    puts $fp {<button id="ms--ai-summary" type="button" class="tag tag-sm tag-suggestion margin-left-xxs" data-test-id="ai-summary-cta" data-bi-name="ai-summary-cta" data-an="ai-summary">}
    puts $fp {<span class="ai-summary-cta-text">}
    puts $fp {Summarize this article for me}
    puts $fp {</span>}
    puts $fp {</button>}
    puts $fp {</div>}
    puts $fp {<div id="ms--ai-summary-header" class="margin-top-xs"></div>}
    puts $fp {</div>}
    puts $fp {<nav id="center-doc-outline" class="doc-outline display-none-desktop display-none-print margin-bottom-sm" data-bi-name="intopic
