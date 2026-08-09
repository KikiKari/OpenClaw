#!/usr/bin/env tclsh
# index.html — portiert nach tcl
# Quelle: html, Projects@Weather-Check:Weather-Check/index.html
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

proc generate_html {filename} {
    set html [list]
    
    # DOCTYPE and html start tag
    lappend html {<!DOCTYPE html>}
    lappend html {<html lang="de">}
    
    # Head section
    lappend html {  <head>}
    lappend html {    <meta charset="UTF-8" />}
    lappend html {    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />}
    lappend html {    <meta name="theme-color" content="#0d1b2a" />}
    lappend html {    <meta name="description" content="Lokaler Regen-Check für die nächsten 30, 60 und 120 Minuten" />}
    lappend html {    <meta name="apple-mobile-web-app-capable" content="yes" />}
    lappend html {    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />}
    lappend html {    <meta name="apple-mobile-web-app-title" content="Weather" />}
    lappend html {    <link rel="manifest" href="./manifest.json" />}
    lappend html {    <link rel="apple-touch-icon" href="./icon-512.png" />}
    lappend html {    <title>Weather – Regen-Check</title>}
    lappend html {    <script type="module" crossorigin src="./assets/index-DGdzG44S.js"></script>}
    lappend html {    <link rel="stylesheet" crossorigin href="./assets/index-erFv57XC.css">}
    lappend html {  </head>}
    
    # Body section
    lappend html {  <body>}
    lappend html {    <div id="root"></div>}
    lappend html {  <script data-pplx-inline-edit>}
    
    # JavaScript content
    lappend html {(function () \{}
    lappend html {  if (window === window.top) return;}
    lappend html {}
    lappend html {  const allowedParentOrigins = \["https://www.perplexity.ai","https://perplexity.ai","https://testing.perplexity.ai","https://staging.perplexity.ai","https://*.preview.i.perplexity.ai","http://localhost:3000","http://127.0.0.1:3000","http://localhost:5173","http://127.0.0.1:5173"\];}
    lappend html {  const MAX_FONT_BYTES = 500 * 1024;}
    lappend html {  const MAX_TOTAL_FONT_BYTES = 2 * 1024 * 1024;}
    lappend html {  let scrollForwarding = false;}
    lappend html {  let scrollRaf = 0;}
    lappend html {  let trustedTopOrigin = null;}
    lappend html {}
    lappend html {  // Allow entries like "https://*.preview.i.perplexity.ai" — the wildcard}
    lappend html {  // matches a single DNS label (no dots), so "https://*.foo" cannot stretch}
    lappend html {  // across multiple labels.}
    lappend html {  function matchesAllowedOrigin(origin) \{}
    lappend html {    if (!origin) return false;}
    lappend html {    for (const entry of allowedParentOrigins) \{}
    lappend html {      if (!entry.includes("*")) \{}
    lappend html {        if (entry === origin) return true;}
    lappend html {        continue;}
    lappend html {      \}}
    lappend html {      const pattern = new RegExp(}
    lappend html {        "^" +}
    lappend html {          entry.replace(/\[\.+?^\$\{\}\(\)|\[\]\\\\\]/g, "\\\\\\$&").replace(/\*/g, "\[^.\]+") +}
    lappend html {          "$",}
    lappend html {      );}
    lappend html {      if (pattern.test(origin)) return true;}
    lappend html {    \}}
    lappend html {    return false;}
    lappend html {  \}}
    lappend html {}
    lappend html {  // Trust decision: when the sender is same-origin-visible (event.origin is a}
    lappend html {  // real origin like https://www.perplexity.ai) we trust event.origin directly.}
    lappend html {  // When event.origin is "null" (opaque broker srcdoc), we fall back to the}
    lappend html {  // broker's stamped `parentOrigin` to identify the top window. The fallback}
    lappend html {  // is claim-only — we rely on the browser's native `targetOrigin` enforcement}
    lappend html {  // on the response path (see postToTrustedTop) to ensure replies can't be}
    lappend html {  // delivered to anyone but the actual top window of that claimed origin.}
    lappend html {  function getTrustedParentOrigin(event) \{}
    lappend html {    const forwardedParentOrigin =}
    lappend html {      typeof event.data.parentOrigin === "string" ? event.data.parentOrigin : null;}
    lappend html {    const parentOrigin = event.origin === "null" ? forwardedParentOrigin : event.origin;}
    lappend html {    return matchesAllowedOrigin(parentOrigin) ? parentOrigin : null;}
    lappend html {  \}}
    lappend html {}
    lappend html {  // All responses go to window.top with targetOrigin = the allowlisted origin.}
    lappend html {  // An attacker that iframes us inside their own null-origin broker can claim}
    lappend html {  // any parentOrigin they like, but the browser will drop the reply whenever}
    lappend html {  // the real top's origin doesn't match — so the screenshot never leaves.}
    lappend html {  function postToTrustedTop(message) \{}
    lappend html {    if (!trustedTopOrigin) return;}
    lappend html {    try \{}
    lappend html {      window.top.postMessage(message, trustedTopOrigin);}
    lappend html {    \} catch (_error) \{\}}
    lappend html {  \}}
    lappend html {}
    lappend html {  function inlineAll(original, clone) \{}
    lappend html {    if (original.nodeType !== 1 || clone.nodeType !== 1) return;}
    lappend html {}
    lappend html {    try \{}
    lappend html {      const computedStyle = getComputedStyle(original);}
    lappend html {      // cssText on a computed style is the serialized declaration in modern}
    lappend html {      // Chromium/Safari — a single read beats enumerating ~400 longhand}
    lappend html {      // properties. Firefox returns "" here, so we fall back on empty.}
    lappend html {      const serialized = computedStyle.cssText;}
    lappend html {      if (serialized) \{}
    lappend html {        clone.style.cssText = serialized;}
    lappend html {      \} else \{}
    lappend html {        const parts = new Array(computedStyle.length);}
    lappend html {        for (let index = 0; index < computedStyle.length; index += 1) \{}
    lappend html {          const property = computedStyle\[index\];}
    lappend html {          parts\[index\] = `\$\{property\}:\$\{computedStyle.getPropertyValue(property)\};`;}
    lappend html {        \}}
    lappend html {        clone.style.cssText = parts.join("");}}
    lappend html {    \} catch (_error) \{\}}
    lappend html {}
    lappend html {    const originalChildren = original.children;}
    lappend html {    const clonedChildren = clone.children;}
    lappend html {    for (}
    lappend html {      let index = 0;}
    lappend html {      index < originalChildren.length && index < clonedChildren.length;}
    lappend html {      index += 1}
    lappend html {    ) \{}
    lappend html {      inlineAll(originalChildren\[index\], clonedChildren\[index\]);}
    lappend html {    \}}
    lappend html {  \}}
    lappend html {}
    lappend html {  function extractFontUrl(srcValue) \{}
    lappend html {    const matches = \[}
    lappend html {      ...srcValue.matchAll(}
    lappend html {        /url\(\["'\]?\(\[^"'\)\]+\)\["'\]?\)(?:\\s*format\(\["'\]?\(\[^"'\)\]+\)\["'\]?\))?/gi,}
    lappend html {      ),}
    lappend html {    \];}
    lappend html {    if (matches.length === 0) return null;}
    lappend html {    const woff2 = matches.find((m) => m\[2\] && m\[2\].toLowerCase().includes("woff2"));}
    lappend html {    if (woff2) return woff2\[1\];}
    lappend html {    const woff = matches.find((m) => m\[2\] && m\[2\].toLowerCase().includes("woff"));}
    lappend html {    if (woff) return woff\[1\];}
    lappend html {    return matches\[0\]\[1\];}
    lappend html {  \}}
    lappend html {}
    lappend html {  // Cache resolved font URL -> data URI across captures. Fonts on a page}
    lappend html {  // essentially never change, and a batch run emits multiple captures back to}
    lappend html {  // back to back — without this we'd refetch + re-base64 every time.}
    lappend html {  const fontDataUriCache = new Map();}
    lappend html {  const SRC_DECLARATION_RE = /src\\s*:\\s*\[^;\]\[0\]+/i;}
    lappend html {}
    lappend html {  async function fetchAsDataUri(url) \{}
    lappend html {    if (fontDataUriCache.has(url)) return fontDataUriCache.get(url);}
    lappend html {    let dataUri = null;}
    lappend html {    try \{}
    lappend html {      const response = await fetch(url, \{ mode: "cors", credentials: "omit" \});}
    lappend html {      if (response.ok) \{}
    lappend html {        const blob = await response.blob();}
    lappend html {        if (blob.size <= MAX_FONT_BYTES) \{}
    lappend html {          dataUri = await new Promise((resolve) => \{}
    lappend html {            const reader = new FileReader();}
    lappend html {            reader.onloadend = () =>}
    lappend html {              resolve(typeof reader.result === "string" ? reader.result : null);}
    lappend html {            reader.onerror = () => resolve(null);}
    lappend html {            reader.readAsDataURL(blob);}
    lappend html {          \});}
    lappend html {        \}}
    lappend html {      \}}
    lappend html {    \} catch (_error) \{}
    lappend html {      dataUri = null;}
    lappend html {    \}}
    lappend html {    fontDataUriCache.set(url, dataUri);}
    lappend html {    return dataUri;}
    lappend html {  \}}
    lappend html {}
    lappend html {  function collectFontFaceRuleTexts() \{}
    lappend html {    const rules = \[\];}
    lappend html {    for (const sheet of document.styleSheets) \{}
    lappend html {      let cssRules;}
    lappend html {      try \{}
    lappend html {        cssRules = sheet.cssRules;}
    lappend html {      \} catch (_error) \{}
    lappend html {        continue;}
    lappend html {      \}}
    lappend html {      if (!cssRules) continue;}
    lappend html {      for (const rule of cssRules) \{}
    lappend html {        const cssText = rule.cssText || "";}
    lappend html {        if (cssText.startsWith("@font-face")) rules.push(cssText);}
    lappend html {      \}}
    lappend html {    \}}
    lappend html {    return rules;}
    lappend html {  \}}
    lappend html {}
    lappend html {  async function buildInlinedFontCss() \{}
    lappend html {    const ruleTexts = collectFontFaceRuleTexts();}
    lappend html {    if (ruleTexts.length === 0) return null;}
    lappend html {}
    lappend html {    const resolved = ruleTexts.map((cssText) => \{}
    lappend html {      if (!SRC_DECLARATION_RE.test(cssText)) return null;}
    lappend html {      const srcMatch = cssText.match(/src\\s*:\\s*\(\[^;\]\[0\]+\)\[;\]\[0\]/i);}
    lappend html {      if (!srcMatch) return null;}
    lappend html {      const url = extractFontUrl(srcMatch\[1\]);}
    lappend html {      if (!url) return null;}
    lappend html {      try \{}
    lappend html {        return \{ cssText, url: new URL(url, document.baseURI).href \};}
    lappend html {      \} catch (_error) \{}
    lappend html {        return null;}
    lappend html {      \}}
    lappend html {    \});}
    lappend html {}
    lappend html {    const dataUris = await Promise.all(}
    lappend html {      resolved.map((entry) => (entry ? fetchAsDataUri(entry.url) : Promise.resolve(null))),}
    lappend html {    );}
    lappend html {}
    lappend html {    const inlined = \[\];}
    lappend html {    let totalBytes = 0;}
    lappend html {    for (let index = 0; index < resolved.length; index += 1) \{}
    lappend html {      const entry = resolved\[index\];}
    lappend html {      const dataUri = dataUris\[index\];}
    lappend html {      if (!entry || !dataUri) continue;}
    lappend html {      const approxBytes = dataUri.length * 0.75;}
    lappend html {      if (totalBytes + approxBytes > MAX_TOTAL_FONT_BYTES) break;}
    lappend html {      totalBytes += approxBytes;}
    lappend html {      inlined.push(entry.cssText.replace(SRC_DECLARATION_RE, `src: url("\$\{dataUri\}")`));}
    lappend html {    \}}
    lappend html {    return inlined.length > 0 ? inlined.join("\\n") : null;}
    lappend html {  \}}
    lappend html {}
    lappend html {  function stripExternal(clone) \{}
    lappend html {    const images = clone.querySelectorAll("img");}
    lappend html {    for (let index = 0; index < images.length; index += 1) \{}
    lappend html {      const src = images\[index\].getAttribute("src");}
    lappend html {      if (src && !src.startsWith("data:")) images\[index\].removeAttribute("src");}
    lappend html {    \}}
    lappend html {}
    lappend html {    const elements = clone.querySelectorAll("*");}
    lappend html {    for (let index = 0; index < elements.length; index += 1) \{}
    lappend html {      const style = elements\[index\].style.cssText;}
    lappend html {      if (style && style.includes("url(")) \{}
    lappend html {        elements\[index\].style.cssText = style.replace(}
    lappend html {          /url\(\["'\]?\(?!data:\)\[^)"'\]*\["'\]?\)/gi,}
    lappend html {          "none",}
    lappend html {        );}
    lappend html {      \}}
    lappend html {    \}}
    lappend html {  \}}
    lappend html {}
    lappend html {  function emitScroll() \{}
    lappend html {    scrollRaf = 0;}
    lappend html {    if (!scrollForwarding) return;}
    lappend html {    postToTrustedTop(\{}
    lappend html {      type: "INLINE_EDIT_SCROLL",}
    lappend html {      scrollX: window.scrollX,}
    lappend html {      scrollY: window.scrollY,}
    lappend html {    \});}
    lappend html {  \}}
    lappend html {}
    lappend html {  window.addEventListener(}
    lappend html {    "scroll",}
    lappend html {    function () \{}
    lappend html {      if (!scrollForwarding || scrollRaf) return;}
    lappend html {      scrollRaf = requestAnimationFrame(emitScroll);}
    lappend html {    \},}
    lappend html {    \{ passive: true, capture: true \},}
    lappend html {  );}
    lappend html {}
    lappend html {  async function handleCaptureRequest(event) \{}
    lappend html {    const requestId = event.data.requestId;}
    lappend html {    const scrollX = window.scrollX;}
    lappend html {    const scrollY = window.scrollY;}
    lappend html {    const width = window.innerWidth;}
    lappend html {    const height = window.innerHeight;}
    lappend html {}
    lappend html {    function postResult(dataUrl) \{}
    lappend html {      postToTrustedTop(\{}
    lappend html {        type: "INLINE_EDIT_SCREENSHOT_RESULT",}
    lappend html {        requestId,}
    lappend html {        dataUrl,}
    lappend html {        scrollX,}
    lappend html {        scrollY,}
    lappend html {      \});}
    lappend html {    \}}
    lappend html {}
    lappend html {    try \{}
    lappend html {      // Wait for any pending web fonts to resolve so both inline metrics and}
    lappend html {      // the @font-face inlining below see the same loaded faces.}
    lappend html {      if (document.fonts && document.fonts.ready) \{}
    lappend html {        try \{}
    lappend html {          await document.fonts.ready;}
    lappend html {        \} catch (_error) \{\}}
    lappend html {      \}}
    lappend html {}
    lappend html {      const clone = document.documentElement.cloneNode(true);}
    lappend html {      inlineAll(document.documentElement, clone);}
    lappend html {}
    lappend html {      const removedNodes = clone.querySelectorAll("script,link\[rel=\\"stylesheet\\"\],style");}
    lappend html {      for (let index = 0; index < removedNodes.length; index += 1) \{}
    lappend html {        removedNodes\[index\].remove();}
    lappend html {      \}}
    lappend html {}
    lappend html {      stripExternal(clone);}
    lappend html {}
    lappend html {      // Re-embed web fonts as data-URI @font-face rules so the SVG rasterizer}
    lappend html {      // can resolve them — external font URLs aren't fetched during}
    lappend html {      // foreignObject rendering, which would otherwise force a fallback face}
    lappend html {      // and change text metrics.}
    lappend html {      const inlinedFontCss = await buildInlinedFontCss();}
    lappend html {      if (inlinedFontCss) \{}
    lappend html {        const styleEl = document.createElement("style");}
    lappend html {        styleEl.textContent = inlinedFontCss;}
    lappend html {        const head = clone.querySelector("head");}
    lappend html {        if (head) head.appendChild(styleEl);}
    lappend html {        else clone.insertBefore(styleEl, clone.firstChild);}
    lappend html {      \}}
    lappend html {}
    lappend html {      const html = new XMLSerializer().serializeToString(clone);}
    lappend html {      const svg =}
    lappend html {        `<svg xmlns="http://www.w3.org/2000/svg" width="\$\{width\}" height="\$\{height\}">` +}
    lappend html {        '<foreignObject width="100%" height="100%">' +}
    lappend html {        `<div xmlns="http://www.w3.org/1999/xhtml" style="width:\$\{width\}px;height:\$\{height\}px;overflow:hidden">` +}
    lappend html {        `<div style="position:relative;left:-\$\{scrollX\}px;top:-\$\{scrollY\}px">` +}
    lappend html {        html +}
    lappend html {        "</div></div></foreignObject></svg>";}
    lappend html {      const svgUrl = `data:image/svg+xml;charset=utf-8,\$\{encodeURIComponent(svg)\}`;}
    lappend html {      const image = new Image();}
    lappend html {      image.onload = function () \{}
    lappend html {        const canvas = document.createElement("canvas");}
    lappend html {        canvas.width = width;}
    lappend html {        canvas.height = height;}
    lappend html {        canvas.getContext("2d").drawImage(image, 0, 0);}
    lappend html {        postResult(canvas.toDataURL("image/png"));}
    lappend html {      \};}
    lappend html {      image.onerror = function () \{}
    lappend html {        postResult(null);}
    lappend html {      \};}
    lappend html {      image.src = svgUrl;}
    lappend html {    \} catch (_error) \{}
    lappend html {      postResult(null);}
    lappend html {    \}}
    lappend html {  \}}
    lappend html {}
    lappend html {  window.addEventListener("message", function (event) \{}
    lappend html {    if (!event.data) return;}
    lappend html {    // Only accept messages from the direct parent frame. Blocks sibling /}
    lappend html {    // unrelated-window postMessage senders that could otherwise reach us.}
    lappend html {    if (event.source !== window.parent) return;}
    lappend html {}
    lappend html {    const trustedParentOrigin = getTrustedParentOrigin(event);}
    lappend html {    if (!trustedParentOrigin) return;}
    lappend html {    trustedTopOrigin = trustedParentOrigin;}
    lappend html {}
    lappend html {    if (event.data.type === "INLINE_EDIT_SCROLL_START") \{}
    lappend html {      scrollForwarding = true;}
    lappend html {      emitScroll();}
    lappend html {      return;}
    lappend html {    \}}
    lappend html {}
    lappend html {    if (event.data.type === "INLINE_EDIT_SCROLL_STOP") \{}
    lappend html {      scrollForwarding = false;}
    lappend html {      if (scrollRaf) cancelAnimationFrame(scrollRaf);}
    lappend html {      scrollRaf = 0;}
    lappend html {      return;}
    lappend html {    \}}
    lappend html {}
    lappend html {    if (event.data.type !== "INLINE_EDIT_CAPTURE_REQUEST") return;}
    lappend html {}
    lappend html {    handleCaptureRequest(event);}
    lappend html {  \});}
    lappend html {\})();}

    lappend html {}
    lappend html {</script></body>}
    lappend html {</html>}
    
    # Write to file
    set fh [open $filename w]
    puts $fh [join $html "\n"]
    close $fh
}

# Main execution
if {$argc != 1} {
    puts "Usage: $argv0 <output_filename>"
    exit 1
}

set output_file [lindex $argv 0]
generate_html $output_file
