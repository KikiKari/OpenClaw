// abstraction-provenance: {"artifact_sha256": "978430574e66cab086bbac19151ea7201f61807c89d773dc648b427efe16cfba", "source_sha256": "50a5fc7035b85cbf01f8124bc348dfb04553256c185469e38845db8f79a95a89", "target_language": "java"}
// index.html — portiert nach java
// Quelle: html, workspace@local:skills/github-clones/openclaw/src/canvas-host/a2ui/index.html
// auch in: openclaw-css@local:workspace/skills/github-clones/openclaw/src/canvas-host/a2ui/index.html
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

import java.io.*;
import java.nio.file.*;
import java.util.*;

public class IndexGenerator {
    public static void main(String[] args) {
        if (args.length != 1) {
            System.err.println("Usage: java IndexGenerator <output-file>");
            System.exit(1);
        }
        
        String outputFile = args[0];
        
        try {
            String htmlContent = generateHTML();
            Files.write(Paths.get(outputFile), htmlContent.getBytes());
            System.out.println("HTML file generated successfully: " + outputFile);
        } catch (IOException e) {
            System.err.println("Error writing file: " + e.getMessage());
            System.exit(1);
        }
    }
    
    private static String generateHTML() {
        StringBuilder html = new StringBuilder();
        
        // DOCTYPE
        html.append("<!doctype html>\n");
        
        // HTML start
        html.append("<html>\n");
        
        // HEAD section
        html.append("  <head>\n");
        html.append("    <meta charset=\"utf-8\" />\n");
        html.append("    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />\n");
        html.append("    <title>OpenClaw Canvas</title>\n");
        
        // Script for platform detection
        html.append("    <script>\n");
        html.append("      (() => {\n");
        html.append("        const normalizeLower = (value) => {\n");
        html.append("          const trimmed = String(value || \"\").trim();\n");
        html.append("          return trimmed.toLocaleLowerCase();\n");
        html.append("        };\n");
        html.append("        try {\n");
        html.append("          const params = new URLSearchParams(window.location.search);\n");
        html.append("          const platform = normalizeLower(params.get(\"platform\"));\n");
        html.append("          if (platform) {\n");
        html.append("            document.documentElement.dataset.platform = platform;\n");
        html.append("            return;\n");
        html.append("          }\n");
        html.append("          if (/android/i.test(navigator.userAgent || \"\")) {\n");
        html.append("            document.documentElement.dataset.platform = \"android\";\n");
        html.append("          }\n");
        html.append("        } catch (_) {}\n");
        html.append("      })();\n");
        html.append("    </script>\n");
        
        // Styles
        html.append("    <style>\n");
        html.append("      :root {\n");
        html.append("        color-scheme: dark;\n");
        html.append("      }\n");
        html.append("      @media (prefers-reduced-motion: reduce) {\n");
        html.append("        body::before,\n");
        html.append("        body::after {\n");
        html.append("          animation: none !important;\n");
        html.append("        }\n");
        html.append("      }\n");
        html.append("      html,\n");
        html.append("      body {\n");
        html.append("        height: 100%;\n");
        html.append("        margin: 0;\n");
        html.append("      }\n");
        html.append("      body {\n");
        html.append("        font:\n");
        html.append("          14px system-ui,\n");
        html.append("          -apple-system,\n");
        html.append("          BlinkMacSystemFont,\n");
        html.append("          \"Roboto\",\n");
        html.append("          sans-serif;\n");
        html.append("        background:\n");
        html.append("          radial-gradient(1200px 900px at 15% 20%, rgba(42, 113, 255, 0.18), rgba(0, 0, 0, 0) 55%),\n");
        html.append("          radial-gradient(900px 700px at 85% 30%, rgba(255, 0, 138, 0.14), rgba(0, 0, 0, 0) 60%),\n");
        html.append("          radial-gradient(1000px 900px at 60% 90%, rgba(0, 209, 255, 0.1), rgba(0, 0, 0, 0) 60%),\n");
        html.append("          #000;\n");
        html.append("        color: #e5e7eb;\n");
        html.append("        overflow: hidden;\n");
        html.append("      }\n");
        html.append("      :root[data-platform=\"android\"] body {\n");
        html.append("        background:\n");
        html.append("          radial-gradient(1200px 900px at 15% 20%, rgba(42, 113, 255, 0.62), rgba(0, 0, 0, 0) 55%),\n");
        html.append("          radial-gradient(900px 700px at 85% 30%, rgba(255, 0, 138, 0.52), rgba(0, 0, 0, 0) 60%),\n");
        html.append("          radial-gradient(1000px 900px at 60% 90%, rgba(0, 209, 255, 0.48), rgba(0, 0, 0, 0) 60%),\n");
        html.append("          #0b1328;\n");
        html.append("      }\n");
        html.append("      body::before {\n");
        html.append("        content: \"\";\n");
        html.append("        position: fixed;\n");
        html.append("        inset: -20%;\n");
        html.append("        background:\n");
        html.append("          repeating-linear-gradient(\n");
        html.append("            0deg,\n");
        html.append("            rgba(255, 255, 255, 0.03) 0,\n");
        html.append("            rgba(255, 255, 255, 0.03) 1px,\n");
        html.append("            transparent 1px,\n");
        html.append("            transparent 48px\n");
        html.append("          ),\n");
        html.append("          repeating-linear-gradient(\n");
        html.append("            90deg,\n");
        html.append("            rgba(255, 255, 255, 0.03) 0,\n");
        html.append("            rgba(255, 255, 255, 0.03) 1px,\n");
        html.append("            transparent 1px,\n");
        html.append("            transparent 48px\n");
        html.append("          );\n");
        html.append("        transform: translate3d(0, 0, 0) rotate(-7deg);\n");
        html.append("        will-change: transform, opacity;\n");
        html.append("        -webkit-backface-visibility: hidden;\n");
        html.append("        backface-visibility: hidden;\n");
        html.append("        opacity: 0.45;\n");
        html.append("        pointer-events: none;\n");
        html.append("        animation: openclaw-grid-drift 140s ease-in-out infinite alternate;\n");
        html.append("      }\n");
        html.append("      :root[data-platform=\"android\"] body::before {\n");
        html.append("        opacity: 0.8;\n");
        html.append("      }\n");
        html.append("      body::after {\n");
        html.append("        content: \"\";\n");
        html.append("        position: fixed;\n");
        html.append("        inset: -35%;\n");
        html.append("        background:\n");
        html.append("          radial-gradient(900px 700px at 30% 30%, rgba(42, 113, 255, 0.16), rgba(0, 0, 0, 0) 60%),\n");
        html.append("          radial-gradient(800px 650px at 70% 35%, rgba(255, 0, 138, 0.12), rgba(0, 0, 0, 0) 62%),\n");
        html.append("          radial-gradient(900px 800px at 55% 75%, rgba(0, 209, 255, 0.1), rgba(0, 0, 0, 0) 62%);\n");
        html.append("        filter: blur(28px);\n");
        html.append("        opacity: 0.52;\n");
        html.append("        will-change: transform, opacity;\n");
        html.append("        -webkit-backface-visibility: hidden;\n");
        html.append("        backface-visibility: hidden;\n");
        html.append("        transform: translate3d(0, 0, 0);\n");
        html.append("        pointer-events: none;\n");
        html.append("        animation: openclaw-glow-drift 110s ease-in-out infinite alternate;\n");
        html.append("      }\n");
        html.append("      :root[data-platform=\"android\"] body::after {\n");
        html.append("        opacity: 0.85;\n");
        html.append("      }\n");
        html.append("      @supports (mix-blend-mode: screen) {\n");
        html.append("        body::after {\n");
        html.append("          mix-blend-mode: screen;\n");
        html.append("        }\n");
        html.append("      }\n");
        html.append("      @supports not (mix-blend-mode: screen) {\n");
        html.append("        body::after {\n");
        html.append("          opacity: 0.7;\n");
        html.append("        }\n");
        html.append("      }\n");
        html.append("      @keyframes openclaw-grid-drift {\n");
        html.append("        0% {\n");
        html.append("          transform: translate3d(-12px, 8px, 0) rotate(-7deg);\n");
        html.append("          opacity: 0.4;\n");
        html.append("        }\n");
        html.append("        50% {\n");
        html.append("          transform: translate3d(10px, -7px, 0) rotate(-6.6deg);\n");
        html.append("          opacity: 0.56;\n");
        html.append("        }\n");
        html.append("        100% {\n");
        html.append("          transform: translate3d(-8px, 6px, 0) rotate(-7.2deg);\n");
        html.append("          opacity: 0.42;\n");
        html.append("        }\n");
        html.append("      }\n");
        html.append("      @keyframes openclaw-glow-drift {\n");
        html.append("        0% {\n");
        html.append("          transform: translate3d(-18px, 12px, 0) scale(1.02);\n");
        html.append("          opacity: 0.4;\n");
        html.append("        }\n");
        html.append("        50% {\n");
        html.append("          transform: translate3d(14px, -10px, 0) scale(1.05);\n");
        html.append("          opacity: 0.52;\n");
        html.append("        }\n");
        html.append("        100% {\n");
        html.append("          transform: translate3d(-10px, 8px, 0) scale(1.03);\n");
        html.append("          opacity: 0.43;\n");
        html.append("        }\n");
        html.append("      }\n");
        html.append("      canvas {\n");
        html.append("        position: fixed;\n");
        html.append("        inset: 0;\n");
        html.append("        display: block;\n");
        html.append("        width: 100vw;\n");
        html.append("        height: 100vh;\n");
        html.append("        touch-action: none;\n");
        html.append("        z-index: 1;\n");
        html.append("      }\n");
        html.append("      :root[data-platform=\"android\"] #openclaw-canvas {\n");
        html.append("        background:\n");
        html.append("          radial-gradient(1100px 800px at 20% 15%, rgba(42, 113, 255, 0.78), rgba(0, 0, 0, 0) 58%),\n");
        html.append("          radial-gradient(900px 650px at 82% 28%, rgba(255, 0, 138, 0.66), rgba(0, 0, 0, 0) 62%),\n");
        html.append("          radial-gradient(1000px 900px at 60% 88%, rgba(0, 209, 255, 0.58), rgba(0, 0, 0, 0) 62%),\n");
        html.append("          #141c33;\n");
        html.append("      }\n");
        html.append("      #openclaw-status {\n");
        html.append("        position: fixed;\n");
        html.append("        inset: 0;\n");
        html.append("        display: none;\n");
        html.append("        align-items: center;\n");
        html.append("        justify-content: center;\n");
        html.append("        flex-direction: column;\n");
        html.append("        padding: 24px;\n");
        html.append("        box-sizing: border-box;\n");
        html.append("        pointer-events: none;\n");
        html.append("        z-index: 3;\n");
        html.append("      }\n");
        html.append("      #openclaw-status .card {\n");
        html.append("        width: min(560px, 88vw);\n");
        html.append("        text-align: left;\n");
        html.append("        padding: 14px 16px 12px;\n");
        html.append("        border-radius: 16px;\n");
        html.append("        background: linear-gradient(140deg, rgba(23, 24, 35, 0.78), rgba(18, 19, 28, 0.55));\n");
        html.append("        border: 1px solid rgba(255, 255, 255, 0.12);\n");
        html.append("        box-shadow:\n");
        html.append("          0 16px 46px rgba(0, 0, 0, 0.52),\n");
        html.append("          inset 0 1px 0 rgba(255, 255, 255, 0.06);\n");
        html.append("        -webkit-backdrop-filter: blur(18px) saturate(140%);\n");
        html.append("        backdrop-filter: blur(18px) saturate(140%);\n");
        html.append("      }\n");
        html.append("      #openclaw-status .title {\n");
        html.append("        font:\n");
        html.append("          600 12px/1.2 -apple-system,\n");
        html.append("          BlinkMacSystemFont,\n");
        html.append("          \"SF Pro Text\",\n");
        html.append("          system-ui,\n");
        html.append("          sans-serif;\n");
        html.append("        letter-spacing: 0.45px;\n");
        html.append("        text-transform: uppercase;\n");
        html.append("        color: rgba(255, 255, 255, 0.7);\n");
        html.append("      }\n");
        html.append("      #openclaw-status .subtitle {\n");
        html.append("        margin-top: 8px;\n");
        html.append("        font:\n");
        html.append("          500 13px/1.45 -apple-system,\n");
        html.append("          BlinkMacSystemFont,\n");
        html.append("          \"SF Pro Text\",\n");
        html.append("          system-ui,\n");
        html.append("          sans-serif;\n");
        html.append("        color: rgba(255, 255, 255, 0.9);\n");
        html.append("        white-space: pre-wrap;\n");
        html.append("        overflow-wrap: anywhere;\n");
        html.append("      }\n");
        html.append("      openclaw-a2ui-host {\n");
        html.append("        display: block;\n");
        html.append("        height: 100%;\n");
        html.append("        position: fixed;\n");
        html.append("        inset: 0;\n");
        html.append("        z-index: 4;\n");
        html.append("        --openclaw-a2ui-inset-top: 28px;\n");
        html.append("        --openclaw-a2ui-inset-right: 0px;\n");
        html.append("        --openclaw-a2ui-inset-bottom: 0px;\n");
        html.append("        --openclaw-a2ui-inset-left: 0px;\n");
        html.append("        --openclaw-a2ui-scroll-pad-bottom: 0px;\n");
        html.append("        --openclaw-a2ui-status-top: calc(50% - 18px);\n");
        html.append("        --openclaw-a2ui-empty-top: 18px;\n");
        html.append("      }\n");
        html.append("    </style>\n");
        html.append("  </head>\n");
        
        // BODY section
        html.append("  <body>\n");
        html.append("    <canvas id=\"openclaw-canvas\"></canvas>\n");
        html.append("    <div id=\"openclaw-status\" role=\"status\" aria-live=\"polite\">\n");
        html.append("      <section class=\"card\">\n");
        html.append("        <div class=\"title\" id=\"openclaw-status-title\">Ready</div>\n");
        html.append("        <div class=\"subtitle\" id=\"openclaw-status-subtitle\">Waiting for agent</div>\n");
        html.append("      </section>\n");
        html.append("    </div>\n");
        html.append("    <openclaw-a2ui-host></openclaw-a2ui-host>\n");
        html.append("    <script src=\"a2ui.bundle.js\"></script>\n");
        
        // Main script
        html.append("    <script>\n");
        html.append("      (() => {\n");
        html.append("        const canvas = document.getElementById(\"openclaw-canvas\");\n");
        html.append("        const ctx = canvas.getContext(\"2d\");\n");
        html.append("        const statusEl = document.getElementById(\"openclaw-status\");\n");
        html.append("        const titleEl = document.getElementById(\"openclaw-status-title\");\n");
        html.append("        const subtitleEl = document.getElementById(\"openclaw-status-subtitle\");\n");
        html.append("        const debugStatusEnabledByQuery = (() => {\n");
        html.append("          try {\n");
        html.append("            const params = new URLSearchParams(window.location.search);\n");
        html.append("            const raw = params.get(\"debugStatus\") ?? params.get(\"debug\");\n");
        html.append("            if (!raw) return false;\n");
        html.append("            const normalized = normalizeLower(raw);\n");
        html.append("            return normalized === \"1\" || normalized === \"true\" || normalized === \"yes\";\n");
        html.append("          } catch (_) {\n");
        html.append("            return false;\n");
        html.append("          }\n");
        html.append("        })();\n");
        html.append("        let debugStatusEnabled = debugStatusEnabledByQuery;\n");
        html.append("\n");
        html.append("        function resize() {\n");
        html.append("          const dpr = window.devicePixelRatio || 1;\n");
        html.append("          const w = Math.max(1, Math.floor(window.innerWidth * dpr));\n");
        html.append("          const h = Math.max(1, Math.floor(window.innerHeight * dpr));\n");
        html.append("          canvas.width = w;\n");
        html.append("          canvas.height = h;\n");
        html.append("          ctx.setTransform(dpr, 0, 0, dpr, 0, 0);\n");
        html.append("        }\n");
        html.append("\n");
        html.append("        window.addEventListener(\"resize\", resize);\n");
        html.append("        resize();\n");
        html.append("\n");
        html.append("        const setDebugStatusEnabled = (enabled) => {\n");
        html.append("          debugStatusEnabled = !!enabled;\n");
        html.append("          if (!statusEl) return;\n");
        html.append("          if (!debugStatusEnabled) {\n");
        html.append("            statusEl.style.display = \"none\";\n");
        html.append("          }\n");
        html.append("        };\n");
        html.append("\n");
        html.append("        if (statusEl && !debugStatusEnabled) {\n");
        html.append("          statusEl.style.display = \"none\";\n");
        html.append("        }\n");
        html.append("\n");
        html.append("        window.__openclaw = {\n");
        html.append("          canvas,\n");
        html.append("          ctx,\n");
        html.append("          setDebugStatusEnabled,\n");
        html.append("          setStatus: (title, subtitle) => {\n");
        html.append("            if (!statusEl || !debugStatusEnabled) return;\n");
        html.append("            if (!title && !subtitle) {\n");
        html.append("              statusEl.style.display = \"none\";\n");
        html.append("              return;\n");
        html.append("            }\n");
        html.append("            statusEl.style.display = \"flex\";\n");
        html.append("            if (titleEl && typeof title === \"string\") titleEl.textContent = title;\n");
        html.append("            if (subtitleEl && typeof subtitle === \"string\") subtitleEl.textContent = subtitle;\n");
        html.append("            if (!debugStatusEnabled) {\n");
        html.append("              clearTimeout(window.__statusTimeout);\n");
        html.append("              window.__statusTimeout = setTimeout(() => {\n");
        html.append("                statusEl.style.display = \"none\";\n");
        html.append("              }, 3000);\n");
        html.append("            } else {\n");
        html.append("              clearTimeout(window.__statusTimeout);\n");
        html.append("            }\n");
        html.append("          },\n");
        html.append("        };\n");
        html.append("      })();\n");
        html.append("    </script>\n");
        
        // Close BODY and HTML
        html.append("  </body>\n");
        html.append("</html>\n");
        
        return html.toString();
    }
}
