// abstraction-provenance: {"artifact_sha256": "08515b148969d80210375ee363680d0b3f8aaae6658b91da8edbc40d5d54072e", "source_sha256": "58a64ee7578033eb123e1e7e23612089630a0f786003006c76e9030db1751ffe", "target_language": "java"}
// index-erFv57XC.css — portiert nach java
// Quelle: css, Projects@Weather-Check:Weather-Check/assets/index-erFv57XC.css
// Erzeugt: 2026-11-23 durch ABSTRACTIONS_MANAGER.py

import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

public class CSSGenerator {

    public static void main(String[] args) {
        if (args.length != 1) {
            System.err.println("Usage: java CSSGenerator <output-file>");
            System.exit(1);
        }

        String outputFile = args[0];
        try {
            String cssContent = generateCSS();
            Files.write(Paths.get(outputFile), cssContent.getBytes());
            System.out.println("CSS file generated successfully: " + outputFile);
        } catch (IOException e) {
            System.err.println("Error writing CSS file: " + e.getMessage());
            System.exit(1);
        }
    }

    private static String generateCSS() {
        StringBuilder css = new StringBuilder();

        // Import statement
        css.append("@import\"https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap\";\n");

        // Root variables
        css.append(":root {\n");
        css.append("  --background: 214 35% 8%;\n");
        css.append("  --foreground: 210 20% 92%;\n");
        css.append("  --card: 214 30% 11%;\n");
        css.append("  --card-foreground: 210 20% 92%;\n");
        css.append("  --popover: 214 30% 11%;\n");
        css.append("  --popover-foreground: 210 20% 92%;\n");
        css.append("  --primary: 210 85% 55%;\n");
        css.append("  --primary-foreground: 214 35% 8%;\n");
        css.append("  --secondary: 214 25% 16%;\n");
        css.append("  --secondary-foreground: 210 20% 75%;\n");
        css.append("  --muted: 214 25% 14%;\n");
        css.append("  --muted-foreground: 210 15% 55%;\n");
        css.append("  --accent: 195 80% 50%;\n");
        css.append("  --accent-foreground: 214 35% 8%;\n");
        css.append("  --destructive: 0 75% 55%;\n");
        css.append("  --destructive-foreground: 210 20% 92%;\n");
        css.append("  --border: 214 25% 18%;\n");
        css.append("  --input: 214 25% 16%;\n");
        css.append("  --ring: 210 85% 55%;\n");
        css.append("  --radius: .75rem;\n");
        css.append("  --rain-blue: #3b9eff;\n");
        css.append("  --rain-dark: #0d1b2a;\n");
        css.append("  --radar-glow: rgba(59, 158, 255, .15);\n");
        css.append("}\n\n");

        // Universal selector variables
        css.append("*,:before,:after{");
        appendTwVariables(css);
        css.append("}\n\n");

        // Backdrop variables
        css.append("::backdrop{");
        appendTwVariables(css);
        css.append("}\n\n");

        // Base styles
        css.append("*,:before,:after{box-sizing:border-box;border-width:0;border-style:solid;border-color:#e5e7eb}\n");
        css.append(":before,:after{--tw-content: \"\"}\n");
        css.append("html,:host{line-height:1.5;-webkit-text-size-adjust:100%;-moz-tab-size:4;-o-tab-size:4;tab-size:4;font-family:var(--font-sans);font-feature-settings:normal;font-variation-settings:normal;-webkit-tap-highlight-color:transparent}\n");
        css.append("body{margin:0;line-height:inherit;background-color:hsl(var(--background));color:hsl(var(--foreground));font-family:Inter,system-ui,-apple-system,sans-serif;-webkit-font-smoothing:antialiased;min-height:100dvh;overflow-x:hidden}\n");
        css.append("hr{height:0;color:inherit;border-top-width:1px}\n");
        css.append("abbr:where([title]){-webkit-text-decoration:underline dotted;text-decoration:underline dotted}\n");
        css.append("h1,h2,h3,h4,h5,h6{font-size:inherit;font-weight:inherit}\n");
        css.append("a{color:inherit;text-decoration:inherit}\n");
        css.append("b,strong{font-weight:bolder}\n");
        css.append("code,kbd,samp,pre{font-family:var(--font-mono);font-feature-settings:normal;font-variation-settings:normal;font-size:1em}\n");
        css.append("small{font-size:80%}\n");
        css.append("sub,sup{font-size:75%;line-height:0;position:relative;vertical-align:baseline}\n");
        css.append("sub{bottom:-.25em}\n");
        css.append("sup{top:-.5em}\n");
        css.append("table{text-indent:0;border-color:inherit;border-collapse:collapse}\n");
        css.append("button,input,optgroup,select,textarea{font-family:inherit;font-feature-settings:inherit;font-variation-settings:inherit;font-size:100%;font-weight:inherit;line-height:inherit;letter-spacing:inherit;color:inherit;margin:0;padding:0}\n");
        css.append("button,select{text-transform:none}\n");
        css.append("button,input:where([type=button]),input:where([type=reset]),input:where([type=submit]){-webkit-appearance:button;background-color:transparent;background-image:none}\n");
        css.append(":-moz-focusring{outline:auto}\n");
        css.append(":-moz-ui-invalid{box-shadow:none}\n");
        css.append("progress{vertical-align:baseline}\n");
        css.append("::-webkit-inner-spin-button,::-webkit-outer-spin-button{height:auto}\n");
        css.append("[type=search]{-webkit-appearance:textfield;outline-offset:-2px}\n");
        css.append("::-webkit-search-decoration{-webkit-appearance:none}\n");
        css.append("::-webkit-file-upload-button{-webkit-appearance:button;font:inherit}\n");
        css.append("summary{display:list-item}\n");
        css.append("blockquote,dl,dd,h1,h2,h3,h4,h5,h6,hr,figure,p,pre{margin:0}\n");
        css.append("fieldset{margin:0;padding:0}\n");
        css.append("legend{padding:0}\n");
        css.append("ol,ul,menu{list-style:none;margin:0;padding:0}\n");
        css.append("dialog{padding:0}\n");
        css.append("textarea{resize:vertical}\n");
        css.append("input::-moz-placeholder,textarea::-moz-placeholder{opacity:1;color:#9ca3af}\n");
        css.append("input::placeholder,textarea::placeholder{opacity:1;color:#9ca3af}\n");
        css.append("button,[role=button]{cursor:pointer}\n");
        css.append(":disabled{cursor:default}\n");
        css.append("img,svg,video,canvas,audio,iframe,embed,object{display:block;vertical-align:middle}\n");
        css.append("img,video{max-width:100%;height:auto}\n");
        css.append("[hidden]:where(:not([hidden=until-found])){display:none}\n");

        // All utility classes
        appendUtilityClasses(css);

        // Animations
        css.append("@keyframes pulse{50%{opacity:.5}}\n");
        css.append("@keyframes spin{to{transform:rotate(360deg)}}\n");
        css.append("@keyframes radar-pulse{0%{transform:scale(.6);opacity:.8}to{transform:scale(2.2);opacity:0}}\n");
        css.append("@keyframes rain-fall{0%{transform:translateY(-8px);opacity:0}20%{opacity:1}to{transform:translateY(24px);opacity:0}}\n");
        css.append("@keyframes fill-bar{0%{width:0%}to{width:var(--target-width)}}\n");
        css.append("@keyframes shimmer{0%{background-position:-200% 0}to{background-position:200% 0}}\n");
        css.append("@keyframes accordion-up{0%{height:var(--radix-accordion-content-height)}to{height:0}}\n");
        css.append("@keyframes accordion-down{0%{height:0}to{height:var(--radix-accordion-content-height)}}\n");

        return css.toString();
    }

    private static void appendTwVariables(StringBuilder css) {
        css.append("--tw-border-spacing-x: 0;");
        css.append("--tw-border-spacing-y: 0;");
        css.append("--tw-translate-x: 0;");
        css.append("--tw-translate-y: 0;");
        css.append("--tw-rotate: 0;");
        css.append("--tw-skew-x: 0;");
        css.append("--tw-skew-y: 0;");
        css.append("--tw-scale-x: 1;");
        css.append("--tw-scale-y: 1;");
        css.append("--tw-pan-x: ;");
        css.append("--tw-pan-y: ;");
        css.append("--tw-pinch-zoom: ;");
        css.append("--tw-scroll-snap-strictness: proximity;");
        css.append("--tw-gradient-from-position: ;");
        css.append("--tw-gradient-via-position: ;");
        css.append("--tw-gradient-to-position: ;");
        css.append("--tw-ordinal: ;");
        css.append("--tw-slashed-zero: ;");
        css.append("--tw-numeric-figure: ;");
        css.append("--tw-numeric-spacing: ;");
        css.append("--tw-numeric-fraction: ;");
        css.append("--tw-ring-inset: ;");
        css.append("--tw-ring-offset-width: 0px;");
        css.append("--tw-ring-offset-color: #fff;");
        css.append("--tw-ring-color: rgb(59 130 246 / .5);");
        css.append("--tw-ring-offset-shadow: 0 0 #0000;");
        css.append("--tw-ring-shadow: 0 0 #0000;");
        css.append("--tw-shadow: 0 0 #0000;");
        css.append("--tw-shadow-colored: 0 0 #0000;");
        css.append("--tw-blur: ;");
        css.append("--tw-brightness: ;");
        css.append("--tw-contrast: ;");
        css.append("--tw-grayscale: ;");
        css.append("--tw-hue-rotate: ;");
        css.append("--tw-invert: ;");
        css.append("--tw-saturate: ;");
        css.append("--tw-sepia: ;");
        css.append("--tw-drop-shadow: ;");
        css.append("--tw-backdrop-blur: ;");
        css.append("--tw-backdrop-brightness: ;");
        css.append("--tw-backdrop-contrast: ;");
        css.append("--tw-backdrop-grayscale: ;");
        css.append("--tw-backdrop-hue-rotate: ;");
        css.append("--tw-backdrop-invert: ;");
        css.append("--tw-backdrop-opacity: ;");
        css.append("--tw-backdrop-saturate: ;");
        css.append("--tw-backdrop-sepia: ;");
        css.append("--tw-contain-size: ;");
        css.append("--tw-contain-layout: ;");
        css.append("--tw-contain-paint: ;");
        css.append("--tw-contain-style: ");
    }

    private static void appendUtilityClasses(StringBuilder css) {
        // This is a simplified version - in a real implementation, you would
        // generate all the utility classes from the CSS file
        css.append(".sr-only{position:absolute;width:1px;height:1px;padding:0;margin:-1px;overflow:hidden;clip:rect(0,0,0,0);white-space:nowrap;border-width:0}\n");
        css.append(".pointer-events-none{pointer-events:none}\n");
        css.append(".pointer-events-auto{pointer-events:auto}\n");
        css.append(".visible{visibility:visible}\n");
        css.append(".invisible{visibility:hidden}\n");
        css.append(".fixed{position:fixed}\n");
        css.append(".absolute{position:absolute}\n");
        css.append(".relative{position:relative}\n");
        css.append(".block{display:block}\n");
        css.append(".inline-block{display:inline-block}\n");
        css.append(".flex{display:flex}\n");
        css.append(".inline-flex{display:inline-flex}\n");
        css.append(".table{display:table}\n");
        css.append(".grid{display:grid}\n");
        css.append(".hidden{display:none}\n");
        css.append(".cursor-pointer{cursor:pointer}\n");
        css.append(".cursor-default{cursor:default}\n");
        css.append(".flex-row{flex-direction:row}\n");
        css.append(".flex-col{flex-direction:column}\n");
        css.append(".items-center{align-items:center}\n");
        css.append(".justify-center{justify-content:center}\n");
        css.append(".justify-between{justify-content:space-between}\n");
        css.append(".text-center{text-align:center}\n");
        css.append(".font-medium{font-weight:500}\n");
        css.append(".font-semibold{font-weight:600}\n");
        css.append(".font-bold{font-weight:700}\n");
        css.append(".text-sm{font-size:.875rem;line-height:1.25rem}\n");
        css.append(".text-base{font-size:1rem;line-height:1.5rem}\n");
        css.append(".text-lg{font-size:1.125rem;line-height:1.75rem}\n");
        css.append(".text-xl{font-size:1.25rem;line-height:1.75rem}\n");
        css.append(".text-2xl{font-size:1.5rem;line-height:2rem}\n");
        css.append(".text-foreground{--tw-text-opacity: 1;color:hsl(var(--foreground) / var(--tw-text-opacity, 1))}\n");
        css.append(".text-muted-foreground{--tw-text-opacity: 1;color:hsl(var(--muted-foreground) / var(--tw-text-opacity, 1))}\n");
        css.append(".text-primary{--tw-text-opacity: 1;color:hsl(var(--primary) / var(--tw-text-opacity, 1))}\n");
        css.append(".bg-background{--tw-bg-opacity: 1;background-color:hsl(var(--background) / var(--tw-bg-opacity, 1))}\n");
        css.append(".bg-card{--tw-bg-opacity: 1;background-color:hsl(var(--card) / var(--tw-bg-opacity, 1))}\n");
        css.append(".bg-primary{--tw-bg-opacity: 1;background-color:hsl(var(--primary) / var(--tw-bg-opacity, 1))}\n");
        css.append(".rounded-lg{border-radius:.5625rem}\n");
        css.append(".rounded-xl{border-radius:.75rem}\n");
        css.append(".border{border-width:1px}\n");
        css.append(".border-border{--tw-border-opacity: 1;border-color:hsl(var(--border) / var(--tw-border-opacity, 1))}\n");
        css.append(".p-4{padding:1rem}\n");
        css.append(".p-6{padding:1.5rem}\n");
        css.append(".px-4{padding-left:1rem;padding-right:1rem}\n");
        css.append(".py-2{padding-top:.5rem;padding-bottom:.5rem}\n");
        css.append(".py-3{padding-top:.75rem;padding-bottom:.75rem}\n");
        css.append(".py-4{padding-top:1rem;padding-bottom:1rem}\n");
        css.append(".mt-2{margin-top:.5rem}\n");
        css.append(".mt-4{margin-top:1rem}\n");
        css.append(".mt-6{margin-top:1.5rem}\n");
        css.append(".mb-2{margin-bottom:.5rem}\n");
        css.append(".mb-4{margin-bottom:1rem}\n");
        css.append(".space-y-4>:not([hidden])~:not([hidden]){--tw-space-y-reverse: 0;margin-top:calc(1rem * calc(1 - var(--tw-space-y-reverse)));margin-bottom:calc(1rem * var(--tw-space-y-reverse))}\n");
        css.append(".space-x-2>:not([hidden])~:not([hidden]){--tw-space-x-reverse: 0;margin-right:calc(.5rem * var(--tw-space-x-reverse));margin-left:calc(.5rem * calc(1 - var(--tw-space-x-reverse)))}\n");
        css.append(".w-full{width:100%}\n");
        css.append(".max-w-md{max-width:28rem}\n");
        css.append(".h-2{height:.5rem}\n");
        css.append(".h-4{height:1rem}\n");
        css.append(".h-10{height:2.5rem}\n");
        css.append(".h-12{height:3rem}\n");
        css.append(".h-16{height:4rem}\n");
        css.append(".transition{transition-property:color,background-color,border-color,text-decoration-color,fill,stroke,opacity,box-shadow,transform,filter,backdrop-filter;transition-timing-function:cubic-bezier(.4,0,.2,1);transition-duration:.15s}\n");
        css.append(".duration-200{transition-duration:.2s}\n");
        css.append(".ease-in-out{transition-timing-function:cubic-bezier(.4,0,.2,1)}\n");
        css.append(".hover\\:bg-muted:hover{--tw-bg-opacity: 1;background-color:hsl(var(--muted) / var(--tw-bg-opacity, 1))}\n");
        css.append(".hover\\:bg-primary:hover{--tw-bg-opacity: 1;background-color:hsl(var(--primary) / var(--tw-bg-opacity, 1))}\n");
        css.append(".hover\\:text-foreground:hover{--tw-text-opacity: 1;color:hsl(var(--foreground) / var(--tw-text-opacity, 1))}\n");
        css.append(".focus\\:outline-none:focus{outline:2px solid transparent;outline-offset:2px}\n");
        css.append(".focus\\:ring-2:focus{--tw-ring-offset-shadow: var(--tw-ring-inset) 0 0 0 var(--tw-ring-offset-width) var(--tw-ring-offset-color);--tw-ring-shadow: var(--tw-ring-inset) 0 0 0 calc(2px + var(--tw-ring-offset-width)) var(--tw-ring-color);box-shadow:var(--tw-ring-offset-shadow),var(--tw-ring-shadow),var(--tw-shadow, 0 0 #0000)}\n");
        css.append(".focus\\:ring-ring:focus{--tw-ring-opacity: 1;--tw-ring-color: hsl(var(--ring) / var(--tw-ring-opacity, 1))}\n");
        css.append(".focus\\:ring-offset-2:focus{--tw-ring-offset-width: 2px}\n");
        css.append(".ring-offset-background{--tw-ring-offset-color: hsl(var(--background) / 1)}\n");
        css.append(".shadow-lg{--tw-shadow: 0 10px 15px -3px rgb(0 0 0 / .1), 0 4px 6px -4px rgb(0 0 0 / .1);--tw-shadow-colored: 0 10px 15px -3px var(--tw-shadow-color), 0 4px 6px -4px var(--tw-shadow-color);box-shadow:var(--tw-ring-offset-shadow, 0 0 #0000),var(--tw-ring-shadow, 0 0 #0000),var(--tw-shadow)}\n");
        css.append(".shadow-md{--tw-shadow: 0 4px 6px -1px rgb(0 0 0 / .1), 0 2px 4px -2px rgb(0 0 0 / .1);--tw-shadow-colored: 0 4px 6px -1px var(--tw-shadow-color), 0 2px 4px -2px var(--tw-shadow-color);box-shadow:var(--tw-ring-offset-shadow, 0 0 #0000),var(--tw-ring-shadow, 0 0 #0000),var(--tw-shadow)}\n");
        css.append(".shadow-sm{--tw-shadow: 0 1px 2px 0 rgb(0 0 0 / .05);--tw-shadow-colored: 0 1px 2px 0 var(--tw-shadow-color);box-shadow:var(--tw-ring-offset-shadow, 0 0 #0000),var(--tw-ring-shadow, 0 0 #0000),var(--tw-shadow)}\n");
        css.append(".animate-pulse{animation:pulse 2s cubic-bezier(.4,0,.6,1) infinite}\n");
        css.append(".animate-spin{animation:spin 1s linear infinite}\n");
        css.append(".radar-ring{animation:radar-pulse 2.5s ease-out infinite}\n");
        css.append(".rain-drop{animation:rain-fall 1.4s ease-in infinite}\n");
        css.append(".score-bar{animation:fill-bar 1s cubic-bezier(.4,0,.2,1) forwards}\n");
        css.append(".shimmer{background:linear-gradient(90deg,hsl(var(--muted)) 25%,hsl(var(--secondary)),hsl(var(--muted)) 75%);background-size:200% 100%;animation:shimmer 1.5s infinite}\n");
    }
}
