// abstraction-provenance: {"artifact_sha256": "11f2a1a0ad5233dd335ddb590a565d5c92b2e747f93d0d42937bd5e17e7684ae", "source_sha256": "e48c1623d8fdce193daf72caa7d76d4da5acf28c8842186c21c07f8cfddb5613", "target_language": "cpp"}
// index.html — portiert nach cpp
// Quelle: html, OpenClaw@gateway1:skills/scripting-utils/references/eggdrop/index.html
// auch in: OpenClaw@gateway2:skills/scripting-utils/references/eggdrop/index.html
// auch in: workspace@local:git/skills/scripting-utils/references/eggdrop/index.html
// auch in: workspace@local:skills/scripting-utils/references/eggdrop/index.html
// auch in: 4 weiteren Fundstellen
// Erzeugt: 2026-11-24 durch ABSTRACTIONS_MANAGER.py

#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <map>

class HTMLDocument {
private:
    std::ofstream file;
    
public:
    HTMLDocument(const std::string& filename) {
        file.open(filename);
    }
    
    ~HTMLDocument() {
        if (file.is_open()) {
            file.close();
        }
    }
    
    void writeDoctype() {
        file << "<!DOCTYPE html>\n\n";
    }
    
    void startHtml(const std::string& lang = "en") {
        file << "<html lang=\"" << lang << "\" data-content_root=\"./\">\n";
    }
    
    void endHtml() {
        file << "</html>\n";
    }
    
    void startHead() {
        file << "  <head>\n";
    }
    
    void endHead() {
        file << "  </head>";
    }
    
    void addMetaCharset() {
        file << "    <meta charset=\"utf-8\" />\n";
    }
    
    void addMetaViewport() {
        file << "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" /><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />\n";
    }
    
    void addTitle(const std::string& title) {
        file << "    <title>" << title << "</title>\n";
    }
    
    void addStylesheet(const std::string& href) {
        file << "    <link rel=\"stylesheet\" type=\"text/css\" href=\"" << href << "\" />\n";
    }
    
    void addScript(const std::string& src) {
        file << "    <script src=\"" << src << "\"></script>\n";
    }
    
    void addLinkRel(const std::string& rel, const std::string& title, const std::string& href) {
        file << "    <link rel=\"" << rel << "\" title=\"" << title << "\" href=\"" << href << "\" /> \n";
    }
    
    void startBody() {
        file << "<body>\n";
    }
    
    void endBody() {
        file << "  </body>\n";
    }
    
    void startDiv(const std::string& className, const std::string& role = "") {
        if (role.empty()) {
            file << "    <div class=\"" << className << "\">\n";
        } else {
            file << "    <div class=\"" << className << "\" role=\"" << role << "\">\n";
        }
    }
    
    void endDiv() {
        file << "       </div>\n";
    }
    
    void addHeaderLink(const std::string& href, const std::string& text) {
        file << "        <div class=\"headertitle\"><a\n";
        file << "          href=\"" << href << "\">" << text << "</a></div>\n";
    }
    
    void startNav() {
        file << "        <div class=\"rel\" role=\"navigation\" aria-label=\"related navigation\">\n";
    }
    
    void endNav() {
        file << "        </div>\n";
    }
    
    void addNavLink(const std::string& href, const std::string& title, const std::string& text, const std::string& accesskey = "") {
        if (accesskey.empty()) {
            file << "          <a href=\"" << href << "\" title=\"" << title << "\">" << text << "</a>\n";
        } else {
            file << "          <a href=\"" << href << "\" title=\"" << title << "\"\n";
            file << "             accesskey=\"" << accesskey << "\">" << text << "</a>\n";
        }
    }
    
    void startContentWrapper() {
        file << "    <div class=\"content-wrapper\">\n";
        file << "      <div class=\"content\">\n";
    }
    
    void endContentWrapper() {
        file << "        <div class=\"clearer\"></div>\n";
        file << "      </div>\n";
        file << "    </div>\n";
    }
    
    void startSidebar() {
        file << "        <div class=\"sidebar\">\n";
    }
    
    void endSidebar() {
        file << "        </div>\n";
    }
    
    void addHeading(int level, const std::string& text) {
        file << "          <h" << level << ">" << text << "</h" << level << ">\n";
    }
    
    void addParagraph(const std::string& text, const std::string& className = "", const std::string& role = "") {
        if (!className.empty() && !role.empty()) {
            file << "          <p class=\"" << className << "\" role=\"" << role << "\">" << text << "</p>\n";
        } else if (!className.empty()) {
            file << "          <p class=\"" << className << "\">" << text << "</p>\n";
        } else {
            file << "          <p>" << text << "</p>\n";
        }
    }
    
    void startList() {
        file << "<ul>\n";
    }
    
    void endList() {
        file << "</ul>\n";
    }
    
    void addListItem(const std::string& text, const std::string& className = "") {
        if (!className.empty()) {
            file << "<li class=\"" << className << "\"><a class=\"reference internal\" href=\"#\">" << text << "</a></li>\n";
        } else {
            file << "<li><a class=\"reference internal\" href=\"#\">" << text << "</a></li>\n";
        }
    }
    
    void startSearchBox() {
        file << "          <div role=\"search\">\n";
        file << "            <h3 style=\"margin-top: 1.5em;\">Search</h3>\n";
        file << "            <form class=\"search\" action=\"search.html\" method=\"get\">\n";
        file << "                <input type=\"text\" name=\"q\" />\n";
        file << "                <input type=\"submit\" value=\"Go\" />\n";
        file << "            </form>\n";
        file << "          </div>\n";
    }
    
    void startDocument() {
        file << "        <div class=\"document\">\n";
        file << "            \n";
        file << "      <div class=\"documentwrapper\">\n";
        file << "        <div class=\"bodywrapper\">\n";
        file << "          <div class=\"body\" role=\"main\">\n";
        file << "            \n";
    }
    
    void endDocument() {
        file << "            <div class=\"clearer\"></div>\n";
        file << "          </div>\n";
        file << "        </div>\n";
        file << "      </div>\n";
        file << "        </div>\n";
    }
    
    void startSection(const std::string& id, int level) {
        file << "  <section id=\"" << id << "\">\n";
        file << "<h" << level << ">" << id << "</h" << level << ">\n";
    }
    
    void endSection() {
        file << "</section>\n";
    }
    
    void addSectionText(const std::string& text) {
        file << "<p>" << text << "</p>\n";
    }
    
    void startUnorderedList(const std::string& classes = "") {
        if (!classes.empty()) {
            file << "<ul class=\"" << classes << "\">\n";
        } else {
            file << "<ul class=\"simple\">\n";
        }
    }
    
    void endUnorderedList() {
        file << "</ul>\n";
    }
    
    void addListItemWithLink(const std::string& href, const std::string& text, bool external = false) {
        if (external) {
            file << "<li><p><a class=\"reference external\" href=\"" << href << "\">" << text << "</a></p></li>\n";
        } else {
            file << "<li><p><a class=\"reference internal\" href=\"" << href << "\">" << text << "</a></p></li>\n";
        }
    }
    
    void startFooterWrapper() {
        file << "    <div class=\"footer-wrapper\">\n";
        file << "      <div class=\"footer\">\n";
    }
    
    void endFooterWrapper() {
        file << "        <div class=\"clearer\"></div>\n";
        file << "      </div>\n";
        file << "    </div>\n";
    }
    
    void startFooterLeft() {
        file << "        <div class=\"left\">\n";
        file << "          <div role=\"navigation\" aria-label=\"related navigaton\">\n";
    }
    
    void endFooterLeft() {
        file << "          </div>\n";
        file << "          <div role=\"note\" aria-label=\"source link\">\n";
        file << "          </div>\n";
        file << "        </div>\n";
    }
    
    void startFooterRight() {
        file << "        <div class=\"right\">\n";
        file << "          \n";
        file << "    <div class=\"footer\" role=\"contentinfo\">\n";
    }
    
    void endFooterRight() {
        file << "    </div>\n";
        file << "        </div>\n";
    }
    
    void addCopyrightNotice(int year, const std::string& holder) {
        file << "    &#169; Copyright " << year << ", " << holder << ".\n";
    }
    
    void addLastUpdated(const std::string& date) {
        file << "      Last updated on " << date << ".\n";
    }
    
    void addCreatedWith(const std::string& tool, const std::string& url) {
        file << "      Created using <a href=\"" << url << "\">" << tool << "</a> 8.2.3.\n";
    }
    
    void addCompoundToctree(const std::string& caption, const std::vector<std::pair<std::string, std::string>>& items) {
        file << "<div class=\"toctree-wrapper compound\">\n";
        file << "<p class=\"caption\" role=\"heading\"><span class=\"caption-text\">" << caption << "</span></p>\n";
        file << "<ul>\n";
        
        for (const auto& item : items) {
            file << "<li class=\"toctree-l1\"><a class=\"reference internal\" href=\"" << item.first << "\">" << item.second << "</a>";
            
            // Special handling for nested lists in some sections
            if (item.second == "README") {
                file << "<ul>\n";
                file << "<li class=\"toctree-l2\"><a class=\"reference internal\" href=\"install/readme.html#notice\">Notice</a></li>\n";
                file << "<li class=\"toctree-l2\"><a class=\"reference internal\" href=\"install/readme.html#what-is-eggdrop\">What is Eggdrop?</a></li>\n";
                file << "<li class=\"toctree-l2\"><a class=\"reference internal\" href=\"install/readme.html#how-to-get-eggdrop\">How to Get Eggdrop</a></li>\n";
                file << "<li class=\"toctree-l2\"><a class=\"reference internal\" href=\"install/readme.html#system-pre-requisites\">System Pre-Requisites</a></li>\n";
                file << "<li class=\"toctree-l2\"><a class=\"reference internal\" href=\"install/readme.html#minimum-requirements\">Minimum Requirements</a></li>\n";
                file << "<li class=\"toctree-l2\"><a class=\"reference internal\" href=\"install/readme.html#quick-startup\">Quick Startup</a></li>\n";
                file << "<li class=\"toctree-l2\"><a class=\"reference internal\" href=\"install/readme.html#upgrading\">Upgrading</a></li>\n";
                file << "<li class=\"toctree-l2\"><a class=\"reference internal\" href=\"install/readme.html#command-line\">Command Line</a></li>\n";
                file << "<li class=\"toctree-l2\"><a class=\"reference internal\" href=\"install/readme.html#auto-starting-eggdrop\">Auto-starting Eggdrop</a></li>\n";
                file << "<li class=\"toctree-l2\"><a class=\"reference internal\" href=\"install/readme.html#documentation\">Documentation</a></li>\n";
                file << "<li class=\"toctree-l2\"><a class=\"reference internal\" href=\"install/readme.html#obtaining-help\">Obtaining Help</a></li>\n";
                file << "</ul>\n";
            } else if (item.second == "Installing Eggdrop") {
                file << "<ul>\n";
                file << "<li class=\"toctree-l2\"><a class=\"reference internal\" href=\"install/install.html#quick-startup\">Quick Startup</a></li>\n";
                file << "<li class=\"toctree-l2\"><a class=\"reference internal\" href=\"install/install.html#cygwin-requirements-windows\">Cygwin Requirements (Windows)</a></li>\n";
                file << "<li class=\"toctree-l2\"><a class=\"reference internal\" href=\"install/install.html#modules\">Modules</a></li>\n";
                file << "</ul>\n";
            } else if (item.second == "Upgrading Eggdrop") {
                file << "<ul>\n";
                file << "<li class=\"toctree-l2\"><a class=\"reference internal\" href=\"install/upgrading.html#how-to-upgrade\">How to Upgrade</a></li>\n";
                file << "<li class=\"toctree-l2\"><a class=\"reference internal\" href=\"install/upgrading.html#must-read-changes-for-eggdrop-v1-10\">Must-read changes for Eggdrop v1.10</a></li>\n";
                file << "</ul>\n";
            }
            
            file << "</li>\n";
        }
        
        file << "</ul>\n";
        file << "</div>\n";
    }
};

void generateIndexPage(HTMLDocument& doc) {
    doc.writeDoctype();
    doc.startHtml();
    
    // Head section
    doc.startHead();
    doc.addMetaCharset();
    doc.addMetaViewport();
    doc.addTitle("Eggdrop, an open source IRC bot &#8212; Eggdrop 1.10.1 documentation");
    doc.addStylesheet("_static/pygments.css?v=03e43079");
    doc.addStylesheet("_static/eggdrop.css?v=ab48a1b6");
    doc.addScript("_static/documentation_options.js?v=290de6c6");
    doc.addScript("_static/doctools.js?v=9bcbadda");
    doc.addScript("_static/sphinx_highlight.js?v=dc90522c");
    doc.addLinkRel("search", "Search", "search.html");
    doc.addLinkRel("next", "README", "install/readme.html");
    doc.endHead();
    
    // Body section
    doc.startBody();
    
    // Header
    doc.startDiv("header-wrapper", "banner");
    doc.startDiv("header");
    doc.addHeaderLink("#", "Eggdrop 1.10.1 documentation");
    doc.startNav();
    doc.addNavLink("install/readme.html", "README", "next", "N");
    doc.endNav();
    doc.endDiv();
    doc.endDiv();
    
    // Content
    doc.startContentWrapper();
    doc.startDiv("content");
    doc.startSidebar();
    
    doc.addHeading(3, "Table of Contents");
    doc.addParagraph("Installing Eggdrop", "caption", "heading");
    doc.startList();
    doc.addListItem("README", "toctree-l1");
    doc.addListItem("Installing Eggdrop", "toctree-l1");
    doc.addListItem("Upgrading Eggdrop", "toctree-l1");
    doc.endList();
    
    doc.addParagraph("Using Eggdrop", "caption", "heading");
    doc.startList();
    doc.addListItem("Eggdrop Features", "toctree-l1");
    doc.addListItem("Eggdrop Core Settings", "toctree-l1");
    doc.addListItem("The Party Line", "toctree-l1");
    doc.addListItem("Eggdrop Autoscripts", "toctree-l1");
    doc.addListItem("Users and Flags", "toctree-l1");
    doc.addListItem("Bans, Invites, and Exempts", "toctree-l1");
    doc.addListItem("Botnet Sharing and Linking", "toctree-l1");
    doc.addListItem("IPv6 support", "toctree-l1");
    doc.addListItem("TLS support", "toctree-l1");
    doc.addListItem("IRCv3 support", "toctree-l1");
    doc.addListItem("Account tracking in Eggdrop", "toctree-l1");
    doc.addListItem("Encryption/Hashing", "toctree-l1");
    doc.addListItem("Using the Python Module", "toctree-l1");
    doc.addListItem("Twitch", "toctree-l1");
    doc.addListItem("Advanced Tips", "toctree-l1");
    doc.addListItem("Textfile Substitutions", "toctree-l1");
    doc.addListItem("Eggdrop Tcl Commands", "toctree-l1");
    doc.addListItem("Eggdrop Twitch Tcl Commands", "toctree-l1");
    doc.addListItem("Patching Eggdrop", "toctree-l1");
    doc.endList();
    
    doc.addParagraph("Tutorials", "caption", "heading");
    doc.startList();
    doc.addListItem("Setting Up Eggdrop", "toctree-l1");
    doc.addListItem("Common First Steps", "toctree-l1");
    doc.addListItem("Enabling TLS Security on Eggdrop", "toctree-l1");
    doc.addListItem("Sharing Userfiles", "toctree-l1");
    doc.addListItem("Writing an Eggdrop Tcl Script", "toctree-l1");
    doc.addListItem("Writing a Basic Eggdrop Module", "toctree-l1");
    doc.endList();
    
    doc.addParagraph("Eggdrop Modules", "caption", "heading");
    doc.startList();
    doc.addListItem("Eggdrop Module Information", "toctree-l1");
    doc.addListItem("Modules included with Eggdrop", "toctree-l1");
    doc.addListItem("How to Write an Eggdrop Module", "toctree-l1");
    doc.addListItem("Eggdrop Bind Internals", "toctree-l1");
    doc.endList();
    
    doc.addParagraph("About Eggdrop", "caption", "heading");
    doc.startList();
    doc.addListItem("About Eggdrop", "toctree-l1");
    doc.addListItem("Boring legal stuff", "toctree-l1");
    doc.endList();
    
    doc.startSearchBox();
    
    doc.endSidebar();
    
    // Document content
    doc.startDocument();
    
    doc.startSection("eggdrop-an-open-source-irc-bot", 1);
    doc.addSectionText("Eggdrop is a free, open source software program built to assist in managing an IRC channel. It is the world's oldest actively-maintained IRC bot and was designed to be easily used and expanded on via it's ability to run Tcl scripts. Eggdrop can join IRC channels and perorm automated tasks such as protecting the channel from abuse, assisting users obtain their op/voice status, provide information and greetings, host games, etc.");
    
    doc.startSection("some-things-you-can-do-with-eggdrop", 2);
    doc.addSectionText("Eggdrop has a large number of features, such as:");
    doc.startUnorderedList();
    doc.addListItemWithLink("using/users.html", "Channel Management", true);
    doc.addListItemWithLink("#", "Running Tcl Scripts");
    doc.addListItemWithLink("using/ircv3.html", "Integration of the most current IRCv3 capabilities", true);
    doc.addListItemWithLink("using/botnet.html", "The ability to link multiple Eggdrops together and share userfiles", true);
    doc.addListItemWithLink("using/tls.html", "TLS Support", true);
    doc.addListItemWithLink("using/ipv6.html", "IPv6 Support", true);
    doc.addListItemWithLink("using/twitchinfo.html", "Twitch Support", true);
    doc.addListItemWithLink("#", "... and much much more!");
    doc.endUnorderedList();
    doc.endSection();
    
    doc.startSection("how-to-get-eggdrop", 2);
    doc.addSectionText("The Eggdrop project source code is hosted at ");
    doc.addSectionText("<a class=\"reference external\" href=\"https://github.com/eggheads/eggdrop\">https://github.com/eggheads/eggdrop</a>. You can clone it via git, or alternatively a copy of the current stable snapshot is located at <a class=\"reference external\" href=\"https://geteggdrop.com\">https://geteggdrop.com</a>. Additional information can be found on the official Eggdrop webpage at <a class=\"reference external\" href=\"https://www.eggheads.org\">https://www.eggheads.org</a>. For more information, see <a class=\"reference external\" href=\"install/install.html\">Installing Eggdrop</a>");
    doc.endSection();
    
    doc.startSection("how-to-install-eggdrop", 2);
    doc.startSection("installation-pre-requisites", 3);
    doc.addSectionText("Eggdrop requires Tcl (and its development header files) to be present on the system it is compiled on. It is also strongly encouraged to install openssl (and its development header files) to enable TLS-protected network communication.");
    doc.endSection();
    doc.startSection("installation", 3);
    doc.addSectionText("A guide to quickly installing Eggdrop can be found here.");
    doc.endSection();
    doc.endSection();
    
    doc.startSection("where-to-find-more-help", 2);
    doc.addSectionText("The Eggheads development team can be found lurking on #eggdrop on the Libera network (irc.libera.chat).");
    
    // Compound toctrees
    std::vector<std::pair<std::string, std::string>> installingItems = {
        {"install/readme.html", "README"},
        {"install/install.html", "Installing Eggdrop"},
        {"install/upgrading.html", "Upgrading Eggdrop"}
    };
    doc.addCompoundToctree("Installing Eggdrop", installingItems);
    
    std::vector<std::pair<std::string, std::string>> usingItems = {
        {"using/features.html", "Eggdrop Features"},
        {"using/core.html", "Eggdrop Core Settings"},
        {"using/partyline.html", "The Party Line"},
        {"using/autoscripts.html", "Eggdrop Autoscripts"},
        {"using/users.html", "Users and Flags"},
        {"using/bans.html", "Bans, Invites, and Exempts"},
        {"using/botnet.html", "Botnet Sharing and Linking"},
        {"using/ipv6.html", "IPv6 support"},
        {"using/tls.html", "TLS support"},
        {"using/ircv3.html", "IRCv3 support"},
        {"using/accounts.html", "Account tracking in Eggdrop"},
        {"using/pbkdf2info.html", "Encryption/Hashing"},
        {"using/python.html", "Using the Python Module"},
        {"using/twitchinfo.html", "Twitch"},
        {"using/tricks.html", "Advanced Tips"},
        {"using/text-sub.html", "Textfile Substitutions"},
        {"using/tcl-commands.html", "Eggdrop Tcl Commands"},
        {"using/twitch-tcl-commands.html", "Eggdrop Twitch Tcl Commands"},
        {"using/patch.html", "Patching Eggdrop"}
    };
    doc.addCompoundToctree("Using Eggdrop", usingItems);
    
    std::vector<std::pair<std::string, std::string>> tutorialsItems = {
        {"tutorials/setup.html", "Setting Up Eggdrop"},
        {"tutorials/firststeps.html", "Common First Steps"},
        {"tutorials/tlssetup.html", "Enabling TLS Security on Eggdrop"},
        {"tutorials/userfilesharing.html", "Sharing Userfiles"},
        {"tutorials/firstscript.html", "Writing an Eggdrop Tcl Script"},
        {"tutorials/module.html", "Writing a Basic Eggdrop Module"}
    };
    doc.addCompoundToctree("Tutorials", tutorialsItems);
    
    std::vector<std::pair<std::string, std::string>> modulesItems = {
        {"modules/index.html", "Eggdrop Module Information"},
        {"modules/included.html", "Modules included with Eggdrop"},
        {"modules/writing.html", "How to Write an Eggdrop Module"},
        {"modules/internals.html", "Eggdrop Bind Internals"}
    };
    doc.addCompoundToctree("Eggdrop Modules", modulesItems);
    
    std::vector<std::pair<std::string, std::string>> aboutItems = {
        {"about/about.html", "About Eggdrop"},
        {"about/legal.html", "Boring legal stuff"}
    };
    doc.addCompoundToctree("About Eggdrop", aboutItems);
    
    doc.endSection();
    doc.endDocument();
    
    // Footer
    doc.startFooterWrapper();
    doc.startDiv("footer");
    doc.startFooterLeft();
    doc.addNavLink("install/readme.html", "README", "next");
    doc.endFooterLeft();
    
    doc.startFooterRight();
    doc.addCopyrightNotice(2025, "Eggheads");
    doc.addLastUpdated("Aug 15, 2025");
    doc.addCreatedWith("Sphinx", "https://www.sphinx-doc.org/");
    doc.endFooterRight();
    doc.endDiv();
    doc.endFooterWrapper();
    
    doc.endBody();
    doc.endHtml();
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cerr << "Usage: " << argv[0] << " <output_file>\n";
        return 1;
    }
    
    HTMLDocument doc(argv[1]);
    generateIndexPage(doc);
    
    return 0;
}
