#!/usr/bin/env node
// index.html — portiert nach javascript
// Quelle: html, OpenClaw@gateway1:skills/scripting-utils/references/eggdrop/index.html
// auch in: OpenClaw@gateway2:skills/scripting-utils/references/eggdrop/index.html
// Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

import { writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

function createHTMLElement(tag, attributes = {}, children = []) {
    const element = { tag, attributes, children };
    return element;
}

function addText(element, text) {
    element.children.push({ type: 'text', content: text });
}

function createElement(tag, attributes = {}, children = []) {
    return createHTMLElement(tag, attributes, children);
}

function createDocument() {
    const html = createElement('html', { lang: "en", "data-content_root": "./" });
    const head = createElement('head');
    const body = createElement('body');
    
    html.children = [head, body];
    
    return { html, head, body };
}

function generateIndexHTML() {
    const doc = createDocument();
    const { html, head, body } = doc;

    // Head content
    head.children.push(createElement('meta', { charset: "utf-8" }));
    head.children.push(createElement('meta', { name: "viewport", content: "width=device-width, initial-scale=1.0" }));
    head.children.push(createElement('meta', { name: "viewport", content: "width=device-width, initial-scale=1" }));
    head.children.push(createElement('title', {}, [{ type: 'text', content: "Eggdrop, an open source IRC bot \u2014 Eggdrop 1.10.1 documentation" }]));
    head.children.push(createElement('link', { rel: "stylesheet", type: "text/css", href: "_static/pygments.css?v=03e43079" }));
    head.children.push(createElement('link', { rel: "stylesheet", type: "text/css", href: "_static/eggdrop.css?v=ab48a1b6" }));
    head.children.push(createElement('script', { src: "_static/documentation_options.js?v=290de6c6" }));
    head.children.push(createElement('script', { src: "_static/doctools.js?v=9bcbadda" }));
    head.children.push(createElement('script', { src: "_static/sphinx_highlight.js?v=dc90522c" }));
    head.children.push(createElement('link', { rel: "search", title: "Search", href: "search.html" }));
    head.children.push(createElement('link', { rel: "next", title: "README", href: "install/readme.html" }));

    // Body content
    const headerWrapper = createElement('div', { class: "header-wrapper", role: "banner" });
    const header = createElement('div', { class: "header" });
    const headertitle = createElement('div', { class: "headertitle" });
    const headertitleLink = createElement('a', { href: "#" }, [{ type: 'text', content: "Eggdrop 1.10.1 documentation" }]);
    headertitle.children.push(headertitleLink);
    
    const relNav = createElement('div', { class: "rel", role: "navigation", "aria-label": "related navigation" });
    const nextLink = createElement('a', { 
        href: "install/readme.html", 
        title: "README",
        accesskey: "N"
    }, [{ type: 'text', content: "next" }]);
    relNav.children.push(nextLink);
    
    header.children.push(headertitle, relNav);
    headerWrapper.children.push(header);
    body.children.push(headerWrapper);

    const contentWrapper = createElement('div', { class: "content-wrapper" });
    const content = createElement('div', { class: "content" });
    
    // Sidebar
    const sidebar = createElement('div', { class: "sidebar" });
    
    // Table of Contents
    sidebar.children.push(createElement('h3', {}, [{ type: 'text', content: "Table of Contents" }]));
    
    // Installing Eggdrop section
    const installCaption = createElement('p', { class: "caption", role: "heading" });
    const installCaptionSpan = createElement('span', { class: "caption-text" }, [{ type: 'text', content: "Installing Eggdrop" }]);
    installCaption.children.push(installCaptionSpan);
    sidebar.children.push(installCaption);
    
    const installUl = createElement('ul');
    const readmeLi = createElement('li', { class: "toctree-l1" });
    const readmeLink = createElement('a', { class: "reference internal", href: "install/readme.html" }, [{ type: 'text', content: "README" }]);
    readmeLi.children.push(readmeLink);
    installUl.children.push(readmeLi);
    
    const installLi = createElement('li', { class: "toctree-l1" });
    const installLink = createElement('a', { class: "reference internal", href: "install/install.html" }, [{ type: 'text', content: "Installing Eggdrop" }]);
    installLi.children.push(installLink);
    installUl.children.push(installLi);
    
    const upgradingLi = createElement('li', { class: "toctree-l1" });
    const upgradingLink = createElement('a', { class: "reference internal", href: "install/upgrading.html" }, [{ type: 'text', content: "Upgrading Eggdrop" }]);
    upgradingLi.children.push(upgradingLink);
    installUl.children.push(upgradingLi);
    
    sidebar.children.push(installUl);
    
    // Using Eggdrop section
    const usingCaption = createElement('p', { class: "caption", role: "heading" });
    const usingCaptionSpan = createElement('span', { class: "caption-text" }, [{ type: 'text', content: "Using Eggdrop" }]);
    usingCaption.children.push(usingCaptionSpan);
    sidebar.children.push(usingCaption);
    
    const usingUl = createElement('ul');
    const featuresLi = createElement('li', { class: "toctree-l1" });
    const featuresLink = createElement('a', { class: "reference internal", href: "using/features.html" }, [{ type: 'text', content: "Eggdrop Features" }]);
    featuresLi.children.push(featuresLink);
    usingUl.children.push(featuresLi);
    
    const coreLi = createElement('li', { class: "toctree-l1" });
    const coreLink = createElement('a', { class: "reference internal", href: "using/core.html" }, [{ type: 'text', content: "Eggdrop Core Settings" }]);
    coreLi.children.push(coreLink);
    usingUl.children.push(coreLi);
    
    const partylineLi = createElement('li', { class: "toctree-l1" });
    const partylineLink = createElement('a', { class: "reference internal", href: "using/partyline.html" }, [{ type: 'text', content: "The Party Line" }]);
    partylineLi.children.push(partylineLink);
    usingUl.children.push(partylineLi);
    
    const autoscriptsLi = createElement('li', { class: "toctree-l1" });
    const autoscriptsLink = createElement('a', { class: "reference internal", href: "using/autoscripts.html" }, [{ type: 'text', content: "Eggdrop Autoscripts" }]);
    autoscriptsLi.children.push(autoscriptsLink);
    usingUl.children.push(autoscriptsLi);
    
    const usersLi = createElement('li', { class: "toctree-l1" });
    const usersLink = createElement('a', { class: "reference internal", href: "using/users.html" }, [{ type: 'text', content: "Users and Flags" }]);
    usersLi.children.push(usersLink);
    usingUl.children.push(usersLi);
    
    const bansLi = createElement('li', { class: "toctree-l1" });
    const bansLink = createElement('a', { class: "reference internal", href: "using/bans.html" }, [{ type: 'text', content: "Bans, Invites, and Exempts" }]);
    bansLi.children.push(bansLink);
    usingUl.children.push(bansLi);
    
    const botnetLi = createElement('li', { class: "toctree-l1" });
    const botnetLink = createElement('a', { class: "reference internal", href: "using/botnet.html" }, [{ type: 'text', content: "Botnet Sharing and Linking" }]);
    botnetLi.children.push(botnetLink);
    usingUl.children.push(botnetLi);
    
    const ipv6Li = createElement('li', { class: "toctree-l1" });
    const ipv6Link = createElement('a', { class: "reference internal", href: "using/ipv6.html" }, [{ type: 'text', content: "IPv6 support" }]);
    ipv6Li.children.push(ipv6Link);
    usingUl.children.push(ipv6Li);
    
    const tlsLi = createElement('li', { class: "toctree-l1" });
    const tlsLink = createElement('a', { class: "reference internal", href: "using/tls.html" }, [{ type: 'text', content: "TLS support" }]);
    tlsLi.children.push(tlsLink);
    usingUl.children.push(tlsLi);
    
    const ircv3Li = createElement('li', { class: "toctree-l1" });
    const ircv3Link = createElement('a', { class: "reference internal", href: "using/ircv3.html" }, [{ type: 'text', content: "IRCv3 support" }]);
    ircv3Li.children.push(ircv3Link);
    usingUl.children.push(ircv3Li);
    
    const accountsLi = createElement('li', { class: "toctree-l1" });
    const accountsLink = createElement('a', { class: "reference internal", href: "using/accounts.html" }, [{ type: 'text', content: "Account tracking in Eggdrop" }]);
    accountsLi.children.push(accountsLink);
    usingUl.children.push(accountsLi);
    
    const pbkdf2infoLi = createElement('li', { class: "toctree-l1" });
    const pbkdf2infoLink = createElement('a', { class: "reference internal", href: "using/pbkdf2info.html" }, [{ type: 'text', content: "Encryption/Hashing" }]);
    pbkdf2infoLi.children.push(pbkdf2infoLink);
    usingUl.children.push(pbkdf2infoLi);
    
    const pythonLi = createElement('li', { class: "toctree-l1" });
    const pythonLink = createElement('a', { class: "reference internal", href: "using/python.html" }, [{ type: 'text', content: "Using the Python Module" }]);
    pythonLi.children.push(pythonLink);
    usingUl.children.push(pythonLi);
    
    const twitchinfoLi = createElement('li', { class: "toctree-l1" });
    const twitchinfoLink = createElement('a', { class: "reference internal", href: "using/twitchinfo.html" }, [{ type: 'text', content: "Twitch" }]);
    twitchinfoLi.children.push(twitchinfoLink);
    usingUl.children.push(twitchinfoLi);
    
    const tricksLi = createElement('li', { class: "toctree-l1" });
    const tricksLink = createElement('a', { class: "reference internal", href: "using/tricks.html" }, [{ type: 'text', content: "Advanced Tips" }]);
    tricksLi.children.push(tricksLink);
    usingUl.children.push(tricksLi);
    
    const textSubLi = createElement('li', { class: "toctree-l1" });
    const textSubLink = createElement('a', { class: "reference internal", href: "using/text-sub.html" }, [{ type: 'text', content: "Textfile Substitutions" }]);
    textSubLi.children.push(textSubLink);
    usingUl.children.push(textSubLi);
    
    const tclCommandsLi = createElement('li', { class: "toctree-l1" });
    const tclCommandsLink = createElement('a', { class: "reference internal", href: "using/tcl-commands.html" }, [{ type: 'text', content: "Eggdrop Tcl Commands" }]);
    tclCommandsLi.children.push(tclCommandsLink);
    usingUl.children.push(tclCommandsLi);
    
    const twitchTclCommandsLi = createElement('li', { class: "toctree-l1" });
    const twitchTclCommandsLink = createElement('a', { class: "reference internal", href: "using/twitch-tcl-commands.html" }, [{ type: 'text', content: "Eggdrop Twitch Tcl Commands" }]);
    twitchTclCommandsLi.children.push(twitchTclCommandsLink);
    usingUl.children.push(twitchTclCommandsLi);
    
    const patchLi = createElement('li', { class: "toctree-l1" });
    const patchLink = createElement('a', { class: "reference internal", href: "using/patch.html" }, [{ type: 'text', content: "Patching Eggdrop" }]);
    patchLi.children.push(patchLink);
    usingUl.children.push(patchLi);
    
    sidebar.children.push(usingUl);
    
    // Tutorials section
    const tutorialsCaption = createElement('p', { class: "caption", role: "heading" });
    const tutorialsCaptionSpan = createElement('span', { class: "caption-text" }, [{ type: 'text', content: "Tutorials" }]);
    tutorialsCaption.children.push(tutorialsCaptionSpan);
    sidebar.children.push(tutorialsCaption);
    
    const tutorialsUl = createElement('ul');
    const setupLi = createElement('li', { class: "toctree-l1" });
    const setupLink = createElement('a', { class: "reference internal", href: "tutorials/setup.html" }, [{ type: 'text', content: "Setting Up Eggdrop" }]);
    setupLi.children.push(setupLink);
    tutorialsUl.children.push(setupLi);
    
    const firststepsLi = createElement('li', { class: "toctree-l1" });
    const firststepsLink = createElement('a', { class: "reference internal", href: "tutorials/firststeps.html" }, [{ type: 'text', content: "Common First Steps" }]);
    firststepsLi.children.push(firststepsLink);
    tutorialsUl.children.push(firststepsLi);
    
    const tlssetupLi = createElement('li', { class: "toctree-l1" });
    const tlssetupLink = createElement('a', { class: "reference internal", href: "tutorials/tlssetup.html" }, [{ type: 'text', content: "Enabling TLS Security on Eggdrop" }]);
    tlssetupLi.children.push(tlssetupLink);
    tutorialsUl.children.push(tlssetupLi);
    
    const userfilesharingLi = createElement('li', { class: "toctree-l1" });
    const userfilesharingLink = createElement('a', { class: "reference internal", href: "tutorials/userfilesharing.html" }, [{ type: 'text', content: "Sharing Userfiles" }]);
    userfilesharingLi.children.push(userfilesharingLink);
    tutorialsUl.children.push(userfilesharingLi);
    
    const firstscriptLi = createElement('li', { class: "toctree-l1" });
    const firstscriptLink = createElement('a', { class: "reference internal", href: "tutorials/firstscript.html" }, [{ type: 'text', content: "Writing an Eggdrop Tcl Script" }]);
    firstscriptLi.children.push(firstscriptLink);
    tutorialsUl.children.push(firstscriptLi);
    
    const moduleLi = createElement('li', { class: "toctree-l1" });
    const moduleLink = createElement('a', { class: "reference internal", href: "tutorials/module.html" }, [{ type: 'text', content: "Writing a Basic Eggdrop Module" }]);
    moduleLi.children.push(moduleLink);
    tutorialsUl.children.push(moduleLi);
    
    sidebar.children.push(tutorialsUl);
    
    // Eggdrop Modules section
    const modulesCaption = createElement('p', { class: "caption", role: "heading" });
    const modulesCaptionSpan = createElement('span', { class: "caption-text" }, [{ type: 'text', content: "Eggdrop Modules" }]);
    modulesCaption.children.push(modulesCaptionSpan);
    sidebar.children.push(modulesCaption);
    
    const modulesUl = createElement('ul');
    const indexLi = createElement('li', { class: "toctree-l1" });
    const indexLink = createElement('a', { class: "reference internal", href: "modules/index.html" }, [{ type: 'text', content: "Eggdrop Module Information" }]);
    indexLi.children.push(indexLink);
    modulesUl.children.push(indexLi);
    
    const includedLi = createElement('li', { class: "toctree-l1" });
    const includedLink = createElement('a', { class: "reference internal", href: "modules/included.html" }, [{ type: 'text', content: "Modules included with Eggdrop" }]);
    includedLi.children.push(includedLink);
    modulesUl.children.push(includedLi);
    
    const writingLi = createElement('li', { class: "toctree-l1" });
    const writingLink = createElement('a', { class: "reference internal", href: "modules/writing.html" }, [{ type: 'text', content: "How to Write an Eggdrop Module" }]);
    writingLi.children.push(writingLink);
    modulesUl.children.push(writingLi);
    
    const internalsLi = createElement('li', { class: "toctree-l1" });
    const internalsLink = createElement('a', { class: "reference internal", href: "modules/internals.html" }, [{ type: 'text', content: "Eggdrop Bind Internals" }]);
    internalsLi.children.push(internalsLink);
    modulesUl.children.push(internalsLi);
    
    sidebar.children.push(modulesUl);
    
    // About Eggdrop section
    const aboutCaption = createElement('p', { class: "caption", role: "heading" });
    const aboutCaptionSpan = createElement('span', { class: "caption-text" }, [{ type: 'text', content: "About Eggdrop" }]);
    aboutCaption.children.push(aboutCaptionSpan);
    sidebar.children.push(aboutCaption);
    
    const aboutUl = createElement('ul');
    const aboutLi = createElement('li', { class: "toctree-l1" });
    const aboutLink = createElement('a', { class: "reference internal", href: "about/about.html" }, [{ type: 'text', content: "About Eggdrop" }]);
    aboutLi.children.push(aboutLink);
    aboutUl.children.push(aboutLi);
    
    const legalLi = createElement('li', { class: "toctree-l1" });
    const legalLink = createElement('a', { class: "reference internal", href: "about/legal.html" }, [{ type: 'text', content: "Boring legal stuff" }]);
    legalLi.children.push(legalLink);
    aboutUl.children.push(legalLi);
    
    sidebar.children.push(aboutUl);
    
    // Search form
    const searchDiv = createElement('div', { role: "search" });
    searchDiv.children.push(createElement('h3', { style: "margin-top: 1.5em;" }, [{ type: 'text', content: "Search" }]));
    
    const searchForm = createElement('form', { class: "search", action: "search.html", method: "get" });
    searchForm.children.push(createElement('input', { type: "text", name: "q" }));
    searchForm.children.push(createElement('input', { type: "submit", value: "Go" }));
    searchDiv.children.push(searchForm);
    sidebar.children.push(searchDiv);
    
    // Document content
    const documentDiv = createElement('div', { class: "document" });
    const documentWrapper = createElement('div', { class: "documentwrapper" });
    const bodyWrapper = createElement('div', { class: "bodywrapper" });
    const bodyContent = createElement('div', { class: "body", role: "main" });
    
    // Main content sections
    const mainSection = createElement('section', { id: "eggdrop-an-open-source-irc-bot" });
    mainSection.children.push(createElement('h1', { class: "headerlink", href: "#eggdrop-an-open-source-irc-bot", title: "Link to this heading" }, [
        { type: 'text', content: "Eggdrop, an open source IRC bot" },
        { type: 'text', content: "\u00B6" }
    ]));
    
    mainSection.children.push(createElement('p', {}, [{ type: 'text', content: "Eggdrop is a free, open source software program built to assist in managing an IRC channel. It is the world\u2019s oldest actively-maintained IRC bot and was designed to be easily used and expanded on via it\u2019s ability to run Tcl scripts. Eggdrop can join IRC channels and perorm automated tasks such as protecting the channel from abuse, assisting users obtain their op/voice status, provide information and greetings, host games, etc." }]));
    
    // Some things you can do section
    const thingsSection = createElement('section', { id: "some-things-you-can-do-with-eggdrop" });
    thingsSection.children.push(createElement('h2', { class: "headerlink", href: "#some-things-you-can-do-with-eggdrop", title: "Link to this heading" }, [
        { type: 'text', content: "Some things you can do with Eggdrop" },
        { type: 'text', content: "\u00B6" }
    ]));
    
    thingsSection.children.push(createElement('p', {}, [{ type: 'text', content: "Eggdrop has a large number of features, such as:" }]));
    
    const featuresList = createElement('ul', { class: "simple" });
    const channelLi = createElement('li');
    const channelLink = createElement('a', { class: "reference external", href: "using/users.html" }, [{ type: 'text', content: "Channel Management" }]);
    channelLi.children.push(channelLink);
    featuresList.children.push(channelLi);
    
    const tclLi = createElement('li');
    tclLi.children.push({ type: 'text', content: "Running Tcl Scripts" });
    featuresList.children.push(tclLi);
    
    const ircv3Li2 = createElement('li');
    const ircv3Link2 = createElement('a', { class: "reference external", href: "using/ircv3.html" }, [{ type: 'text', content: "Integration of the most current IRCv3 capabilities" }]);
    ircv3Li2.children.push(ircv3Link2);
    featuresList.children.push(ircv3Li2);
    
    const botnetLi2 = createElement('li');
    const botnetLink2 = createElement('a', { class: "reference external", href: "using/botnet.html" }, [{ type: 'text', content: "The ability to link multiple Eggdrops together and share userfiles" }]);
    botnetLi2.children.push(botnetLink2);
    featuresList.children.push(botnetLi2);
    
    const tlsLi2 = createElement('li');
    const tlsLink2 = createElement('a', { class: "reference external", href: "using/tls.html" }, [{ type: 'text', content: "TLS Support" }]);
    tlsLi2.children.push(tlsLink2);
    featuresList.children.push(tlsLi2);
    
    const ipv6Li2 = createElement('li');
    const ipv6Link2 = createElement('a', { class: "reference external", href: "using/ipv6.html" }, [{ type: 'text', content: "IPv6 Support" }]);
    ipv6Li2.children.push(ipv6Link2);
    featuresList.children.push(ipv6Li2);
    
    const twitchLi = createElement('li');
    const twitchLink = createElement('a', { class: "reference external", href: "using/twitchinfo.html" }, [{ type: 'text', content: "Twitch Support" }]);
    twitchLi.children.push(twitchLink);
    featuresList.children.push(twitchLi);
    
    const moreLi = createElement('li');
    moreLi.children.push({ type: 'text', content: "\u2026 and much much more!" });
    featuresList.children.push(moreLi);
    
    thingsSection.children.push(featuresList);
    mainSection.children.push(thingsSection);
    
    // How to get Eggdrop section
    const getSection = createElement('section', { id: "how-to-get-eggdrop" });
    getSection.children.push(createElement('h2', { class: "headerlink", href: "#how-to-get-eggdrop", title: "Link to this heading" }, [
        { type: 'text', content: "How to get Eggdrop" },
        { type: 'text', content: "\u00B6" }
    ]));
    
    getSection.children.push(createElement('p', {}, [
        { type: 'text', content: "The Eggdrop project source code is hosted at " },
        createElement('a', { class: "reference external", href: "https://github.com/eggheads/eggdrop" }, [{ type: 'text', content: "https://github.com/eggheads/eggdrop" }]),
        { type: 'text', content: ". You can clone it via git, or alternatively a copy of the current stable snapshot is located at " },
        createElement('a', { class: "reference external", href: "https://geteggdrop.com" }, [{ type: 'text', content: "https://geteggdrop.com" }]),
        { type: 'text', content: ". Additional information can be found on the official Eggdrop webpage at " },
        createElement('a', { class: "reference external", href: "https://www.eggheads.org" }, [{ type: 'text', content: "https://www.eggheads.org" }]),
        { type: 'text', content: ". For more information, see " },
        createElement('a', { class: "reference external", href: "install/install.html" }, [{ type: 'text', content: "Installing Eggdrop" }])
    ]));
    
    mainSection.children.push(getSection);
    
    // How to install Eggdrop section
    const installSection = createElement('section', { id: "how-to-install-eggdrop" });
    installSection.children.push(createElement('h2', { class: "headerlink", href: "#how-to-install-eggdrop", title: "Link to this heading" }, [
        { type: 'text', content: "How to install Eggdrop" },
        { type: 'text', content: "\u00B6" }
    ]));
    
    const prereqSection = createElement('section', { id: "installation-pre-requisites" });
    prereqSection.children.push(createElement('h3', { class: "headerlink", href: "#installation-pre-requisites", title: "Link to this heading" }, [
        { type: 'text', content: "Installation Pre-requisites" },
        { type: 'text', content: "\u00B6" }
    ]));
    
    prereqSection.children.push(createElement('p', {}, [{ type: 'text', content: "Eggdrop requires Tcl (and its development header files) to be present on the system it is compiled on. It is also strongly encouraged to install openssl (and its development header files) to enable TLS-protected network communication." }]));
    installSection.children.push(prereqSection);
    
    const installationSection = createElement('section', { id: "installation" });
    installationSection.children.push(createElement('h3', { class: "headerlink", href: "#installation", title: "Link to this heading" }, [
        { type: 'text', content: "Installation" },
        { type: 'text', content: "\u00B6" }
    ]));
    
    installationSection.children.push(createElement('p', {}, [{ type: 'text', content: "A guide to quickly installing Eggdrop can be found here." }]));
    installSection.children.push(installationSection);
    
    mainSection.children.push(installSection);
    
    // Where to find more help section
    const helpSection = createElement('section', { id: "where-to-find-more-help" });
    helpSection.children.push(createElement('h2', { class: "headerlink", href: "#where-to-find-more-help", title: "Link to this heading" }, [
        { type: 'text', content: "Where to find more help" },
        { type: 'text', content: "\u00B6" }
    ]));
    
    helpSection.children.push(createElement('p', {}, [{ type: 'text', content: "The Eggheads development team can be found lurking on #eggdrop on the Libera network (irc.libera.chat)." }]));
    
    // Installing Eggdrop TOC
    const installTocWrapper = createElement('div', { class: "toctree-wrapper compound" });
    const installTocCaption = createElement('p', { class: "caption", role: "heading" });
    const installTocCaptionSpan = createElement('span', { class: "caption-text" }, [{ type: 'text', content: "Installing Eggdrop" }]);
    installTocCaption.children.push(installTocCaptionSpan);
    installTocWrapper.children.push(installTocCaption);
    
    const installTocUl = createElement('ul');
    
    const readmeTocLi = createElement('li', { class: "toctree-l1" });
    const readmeTocLink = createElement('a', { class: "reference internal", href: "install/readme.html" }, [{ type: 'text', content: "README" }]);
    readmeTocLi.children.push(readmeTocLink);
    
    const readmeSubUl = createElement('ul');
    const noticeLi = createElement('li', { class: "toctree-l2" });
    const noticeLink = createElement('a', { class: "reference internal", href: "install/readme.html#notice" }, [{ type: 'text', content: "Notice" }]);
    noticeLi.children.push(noticeLink);
    readmeSubUl.children.push(noticeLi);
    
    const whatIsLi = createElement('li', { class: "toctree-l2" });
    const whatIsLink = createElement('a', { class: "reference internal", href: "install/readme.html#what-is-eggdrop" }, [{ type: 'text', content: "What is Eggdrop?" }]);
    whatIsLi.children.push(whatIsLink);
    readmeSubUl.children.push(whatIsLi);
    
    const howToGetLi = createElement('li', { class: "toctree-l2" });
    const howToGetLink = createElement('a', { class: "reference internal", href: "install/readme.html#how-to-get-eggdrop" }, [{ type: 'text', content: "How to Get Eggdrop" }]);
    howToGetLi.children.push(howToGetLink);
    readmeSubUl.children.push(howToGetLi);
    
    const systemPreReqLi = createElement('li', { class: "toctree-l2" });
    const systemPreReqLink = createElement('a', { class: "reference internal", href: "install/readme.html#system-pre-requisites" }, [{ type: 'text', content: "System Pre-Requisites" }]);
    systemPreReqLi.children.push(systemPreReqLink);
    readmeSubUl.children.push(systemPreReqLi);
    
    const minReqLi = createElement('li', { class: "toctree-l2" });
    const minReqLink = createElement('a', { class: "reference internal", href: "install/readme.html#minimum-requirements" }, [{ type: 'text', content: "Minimum Requirements" }]);
    minReqLi.children.push(minReqLink);
    readmeSubUl.children.push(minReqLi);
    
    const quickStartupLi = createElement('li', { class: "toctree-l2" });
    const quickStartupLink = createElement('a', { class: "reference internal", href: "install/readme.html#quick-startup" }, [{ type: 'text', content: "Quick Startup" }]);
    quickStartupLi.children.push(quickStartupLink);
    readmeSubUl.children.push(quickStartupLi);
    
    const upgradingTocLi = createElement('li', { class: "toctree-l2" });
    const upgradingTocLink = createElement('a', { class: "reference internal", href: "install/readme.html#upgrading" }, [{ type: 'text', content: "Upgrading" }]);
    upgradingTocLi.children.push(upgradingTocLink);
    readmeSubUl.children.push(upgradingTocLi);
    
    const commandLineLi = createElement('li', { class: "toctree-l2" });
    const commandLineLink = createElement('a', { class: "reference internal", href: "install/readme.html#command-line" }, [{ type: 'text', content: "Command Line" }]);
    commandLineLi.children.push(commandLineLink);
    readmeSubUl.children.push(commandLineLi);
    
    const autoStartLi = createElement('li', { class: "toctree-l2" });
    const autoStartLink = createElement('a', { class: "reference internal", href: "install/readme.html#auto-starting-eggdrop" }, [{ type: 'text', content: "Auto-starting Eggdrop" }]);
    autoStartLi.children.push(autoStartLink);
    readmeSubUl.children.push(autoStartLi);
    
    const documentationLi = createElement('li', { class: "toctree-l2" });
    const documentationLink = createElement('a', { class: "reference internal", href: "install/readme.html#documentation" }, [{ type: 'text', content: "Documentation" }]);
    documentationLi.children.push(documentationLink);
    readmeSubUl.children.push(documentationLi);
    
    const obtainingHelpLi = createElement('li', { class: "toctree-l2" });
    const obtainingHelpLink = createElement('a', { class: "reference internal", href: "install/readme.html#obtaining-help" }, [{ type: 'text', content: "Obtaining Help" }]);
    obtainingHelpLi.children.push(obtainingHelpLink);
    readmeSubUl.children.push(obtainingHelpLi);
    
    readmeTocLi.children.push(readmeSubUl);
    installTocUl.children.push(readmeTocLi);
    
    const installTocLi = createElement('li', { class: "toctree-l1" });
    const installTocLink = createElement('a', { class: "reference internal", href: "install/install.html" }, [{ type: 'text', content: "Installing Eggdrop" }]);
    installTocLi.children.push(installTocLink);
    
    const installSubUl = createElement('ul');
    const quickStartupTocLi = createElement('li', { class: "toctree-l2" });
    const quickStartupTocLink = createElement('a', { class: "reference internal", href: "install/install.html#quick-startup" }, [{ type: 'text', content: "Quick Startup" }]);
    quickStartupTocLi.children.push(quickStartupTocLink);
    installSubUl.children.push(quickStartupTocLi);
    
    const cygwinLi = createElement('li', { class: "toctree-l2" });
    const cygwinLink = createElement('a', { class: "reference internal", href: "install/install.html#cygwin-requirements-windows" }, [{ type: 'text', content: "Cygwin Requirements (Windows)" }]);
    cygwinLi.children.push(cygwinLink);
    installSubUl.children.push(cygwinLi);
    
    const modulesTocLi = createElement('li', { class: "toctree-l2" });
    const modulesTocLink = createElement('a', { class: "reference internal", href: "install/install.html#modules" }, [{ type: 'text', content: "Modules" }]);
    modulesTocLi.children.push(modulesTocLink);
    installSubUl.children.push(modulesTocLi);
    
    installTocLi.children.push(installSubUl);
    installTocUl.children.push(installTocLi);
    
    const upgradingDocLi = createElement('li', { class: "toctree-l1" });
    const upgradingDocLink = createElement('a', { class: "reference internal", href: "install/upgrading.html" }, [{ type: 'text', content: "Upgrading Eggdrop" }]);
    upgradingDocLi.children.push(upgradingDocLink);
    
    const upgradingSubUl = createElement('ul');
    const howToUpgradeLi = createElement('li', { class: "toctree-l2" });
    const how
