#!/usr/bin/env ruby
# abstraction-provenance: {"artifact_sha256": "d027fcd9b9993a0719e880bd4053bcd7bb023ff6bfc1cb7ebd350555325719a0", "source_sha256": "c2445d9bf4b0ccf8c05eb944692addc1436cc68504dfc0ab9e6677d90ced3ec9", "target_language": "ruby"}
# index.html — portiert nach ruby
# Quelle: html, workspace@local:skills/github-clones/openclaw/ui/index.html
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

require 'json'

class HTMLGenerator
  def initialize
    @doc = Document.new
  end

  def generate
    @doc.to_html
  end

  def save_to_file(filename)
    File.write(filename, generate)
  end

  class Document
    def initialize
      @children = []
      @children << Doctype.new
      @children << HTMLTag.new
    end

    def to_html
      @children.map(&:to_html).join("\n")
    end

    class Doctype
      def to_html
        "<!doctype html>"
      end
    end

    class HTMLTag
      def initialize
        @attributes = { lang: "en" }
        @children = []
        @children << HeadTag.new
        @children << BodyTag.new
      end

      def to_html
        attrs = @attributes.map { |k, v| "#{k}=\"#{v}\"" }.join(" ")
        children_html = @children.map(&:to_html).join("\n  ")
        "<html #{attrs}>\n  #{children_html}\n</html>"
      end

      class HeadTag
        def initialize
          @children = []
          @children << MetaTag.new(charset: "UTF-8")
          @children << MetaTag.new(name: "viewport", content: "width=device-width, initial-scale=1.0")
          @children << TitleTag.new("OpenClaw Control")
          @children << MetaTag.new(name: "color-scheme", content: "dark light")
          @children << LinkTag.new(rel: "icon", type: "image/svg+xml", href: "/favicon.svg")
          @children << LinkTag.new(rel: "icon", type: "image/png", sizes: "32x32", href: "/favicon-32.png")
          @children << LinkTag.new(rel: "apple-touch-icon", sizes: "180x180", href: "/apple-touch-icon.png")
          @children << ScriptTag.new(ThemeScript.new)
        end

        def to_html
          children_html = @children.map(&:to_html).join("\n    ")
          "<head>\n    #{children_html}\n  </head>"
        end

        class ThemeScript
          def to_js
            <<-JS
(function () {
  var THEMES = { claw: 1, knot: 1, dash: 1 };
  var MODES = { system: 1, light: 1, dark: 1 };
  var LEGACY = {
    dark: "claw:dark",
    light: "claw:light",
    openknot: "knot:dark",
    fieldmanual: "dash:dark",
    clawdash: "dash:light",
    system: "claw:system",
  };
  try {
    var keys = Object.keys(localStorage);
    var raw;
    for (var i = 0; i < keys.length; i++) {
      if (keys[i].indexOf("openclaw.control.settings.v1") === 0) {
        raw = localStorage.getItem(keys[i]);
        if (raw) break;
      }
    }
    if (!raw) return;
    var s = JSON.parse(raw);
    var t = s && s.theme;
    var m = s && s.themeMode;
    if (typeof t !== "string") t = "";
    if (typeof m !== "string") m = "";
    var legacy = LEGACY[t];
    var theme = THEMES[t] ? t : legacy ? legacy.split(":")[0] : "claw";
    var mode = MODES[m] ? m : legacy ? legacy.split(":")[1] : "system";
    if (mode === "system") {
      mode = window.matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";
    }
    var resolved =
      theme === "knot"
        ? mode === "light"
          ? "openknot-light"
          : "openknot"
        : theme === "dash"
          ? mode === "light"
            ? "dash-light"
            : "dash"
          : mode === "light"
            ? "light"
            : "dark";
    document.documentElement.setAttribute("data-theme", resolved);
    document.documentElement.setAttribute(
      "data-theme-mode",
      resolved.indexOf("light") !== -1 ? "light" : "dark",
    );
  } catch (e) {}
})();
            JS
          end
        end
      end

      class BodyTag
        def initialize
          @children = []
          @children << CustomElement.new("openclaw-app")
          @children << ScriptTag.new(ModuleScript.new)
        end

        def to_html
          children_html = @children.map(&:to_html).join("\n    ")
          "<body>\n    #{children_html}\n  </body>"
        end

        class ModuleScript
          def src
            "/src/main.ts"
          end

          def type
            "module"
          end

          def to_html
            "<script type=\"#{type}\" src=\"#{src}\"></script>"
          end
        end
      end
    end

    # Base tag classes
    class MetaTag
      def initialize(attributes = {})
        @attributes = attributes
      end

      def to_html
        attrs = @attributes.map { |k, v| "#{k}=\"#{v}\"" }.join(" ")
        "<meta #{attrs} />"
      end
    end

    class TitleTag
      def initialize(content)
        @content = content
      end

      def to_html
        "<title>#{@content}</title>"
      end
    end

    class LinkTag
      def initialize(attributes = {})
        @attributes = attributes
      end

      def to_html
        attrs = @attributes.map { |k, v| "#{k}=\"#{v}\"" }.join(" ")
        "<link #{attrs} />"
      end
    end

    class ScriptTag
      def initialize(content = nil)
        @content = content
      end

      def to_html
        if @content.respond_to?(:to_js)
          content_js = @content.to_js.strip
          "<script>\n      #{content_js.gsub("\n", "\n      ")}\n    </script>"
        elsif @content.is_a?(String)
          "<script>#{@content}</script>"
        else
          "<script></script>"
        end
      end
    end

    class CustomElement
      def initialize(tag_name, attributes = {})
        @tag_name = tag_name
        @attributes = attributes
      end

      def to_html
        if @attributes.empty?
          "<#{@tag_name}></#{@tag_name}>"
        else
          attrs = @attributes.map { |k, v| "#{k}=\"#{v}\"" }.join(" ")
          "<#{@tag_name} #{attrs}></#{@tag_name}>"
        end
      end
    end
  end
end

# Main execution
if __FILE__ == $0
  generator = HTMLGenerator.new
  output_file = ARGV[0] || "index.html"
  generator.save_to_file(output_file)
  puts "HTML file generated: #{output_file}"
end
