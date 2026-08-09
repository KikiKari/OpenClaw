#!/usr/bin/env tclsh
# index.html — portiert nach tcl
# Quelle: html, OpenClaw@gateway1:skills/scripting-utils/references/tcl/index.html
# auch in: OpenClaw@gateway2:skills/scripting-utils/references/tcl/index.html
# Erzeugt: 2026-08-09 durch ABSTRACTIONS_MANAGER.py

# Tcl/Tk 8.6 Manual
# Ported from HTML to Tcl

proc generateHTML {} {
    set html {}

    # DOCTYPE and html tag
    append html {<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">}
    append html "\n<html>\n<head>"
    
    # Head section
    append html "\t<title>Tcl/Tk 8.6 Manual</title>\n"
    append html "\t<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
    append html "\t<link rel=\"stylesheet\" href=\"/devsite.css\" type=\"text/css\" media=\"all\">\n"
    append html "</head>\n"
    
    # Body start
    append html "<body bgcolor=\"white\" text=\"black\">\n\n"
    
    # Header table
    append html "\t<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\" width=\"780\">\n"
    append html "	    <tr>\n"
    append html "	    <td valign=\"top\" align=\"left\"><a href=\"/\"><img src=\"/images/plume.png\" width=\"60\" height=\"55\"\n"
    append html "	border=\"0\" alt=\"Tcl Home\" /><img src=\"/images/Developer.gif\" width=\"355\" height=\"55\"\n"
    append html "	border=\"0\" alt=\"Tcl Home\" title=\"Tcl Developer Xchange\" /></a></td>\n"
    append html "	    <td valign=\"top\" align=\"right\"><a href=\"/siteinfo.html\"><font size=1>Hosted by</font></a><br><a href=\"http://www.ActiveState.com/products/tcl\"><img src=\"/images/aslogo.gif\"\n"
    append html "	border=\"0\" alt=\"ActiveState\"\n"
    append html "	title=\"This site is hosted by ActiveState\" /></a></td>\n"
    append html "	    </tr>\n"
    append html "	</table>\n"
    
    # Navigation
    append html "    <div id=\"globalnav\"><ul>\n"
    append html "<li><a href=\"/\">HOME</a></li>\n"
    append html "<li><a href=\"/about/\">ABOUT TCL/TK</a></li>\n"
    append html "<li><a href=\"/software/tcltk/\">SOFTWARE</a></li>\n"
    append html "<li><a href=\"/community/coreteam/\">CORE DEVELOPMENT</a></li>\n"
    append html "<li><a href=\"/community/\">COMMUNITY</a></li>\n"
    append html "<li><a href=\"/doc/\" class=\"here\">DOCUMENTATION</a></li>\n"
    append html "</ul></div>\n"
    append html "<br clear=\"all\" />\n"
    
    # Blue divider
    append html "<DIV style=\"border-top: 2px solid #3163CE; width: 780px\"></DIV>\n"
    
    # Search table
    append html "<table border=\"0\" cellpadding=\"2\" cellspacing=\"0\" width=\"780\">\n"
    append html "	    <tr><td align=\"left\" valign=\"middle\">\n"
    append html "<!-- SiteSearch Google -->\n"
    append html "	<div style=\"display:table-cell; vertical-align:middle; margin:0px\">\n"
    append html "<FORM method=\"GET\" action=\"https://www.google.com/search\">\n"
    append html "<A HREF=\"https://www.google.com/\"><IMG src=\"/images/Search.gif\" border=\"0\"\n"
    append html "ALT=\"Google SiteSearch\" /></A>\n"
    append html "<INPUT TYPE=\"text\" name=\"q\" size=\"20\" maxlength=\"255\" value=\"\">\n"
    append html "<INPUT type=\"image\" value=\"submit\" name=\"btnG\" src=\"/images/Go.gif\">\n"
    append html "<input type=\"hidden\" name=\"ie\" value=\"UTF-8\">\n"
    append html "<input type=\"hidden\" name=\"oe\" value=\"UTF-8\">\n"
    append html "<input type=\"hidden\" name=\"domains\" value=\"tcl.tk\">\n"
    append html "<input type=\"hidden\" name=\"sitesearch\" value=\"tcl.tk\">\n"
    append html "</FORM></div>\n"
    append html "<!-- SiteSearch Google -->\n"
    append html "</td><td \n"
    append html "	    align=\"right\"><p class=\"banner\">Tcl/Tk 8.6 Manual</p></td></tr></table>\n"
    
    # Yellow divider
    append html "	<DIV style=\"border-top: 1px solid #FFCE00; margin-bottom: 2px; width: 780px\"></DIV>"
    
    # Main content table
    append html "<table border=\"0\" cellpadding=\"0\" cellspacing=\"0\" width=\"780\">\n"
    append html "<tr><td>\n"
    
    # Content list
    append html "<DL class=\"keylist\">\n"
    append html "<DT><A HREF=\"UserCmd/contents.htm\">Tcl/Tk Applications</A></DT>\n"
    append html "<DD>The interpreters which implement Tcl and Tk.</DD>\n"
    append html "<DT><A HREF=\"TclCmd/contents.htm\">Tcl Commands</A></DT>\n"
    append html "<DD>The commands which the <B>tclsh</B> interpreter implements.</DD>\n"
    append html "<DT><A HREF=\"TkCmd/contents.htm\">Tk Commands</A></DT>\n"
    append html "<DD>The additional commands which the <B>wish</B> interpreter implements.</DD>\n"
    append html "<DT><A HREF=\"ItclCmd/contents.htm\">[incr Tcl] Package Commands</A></DT>\n"
    append html "<DD>The additional commands provided by the [incr Tcl] package.</DD>\n"
    append html "<DT><A HREF=\"SqliteCmd/contents.htm\">SQLite Package Commands</A></DT>\n"
    append html "<DD>The additional commands provided by the SQLite package.</DD>\n"
    append html "<DT><A HREF=\"TdbcCmd/contents.htm\">TDBC Package Commands</A></DT>\n"
    append html "<DD>The additional commands provided by the TDBC package.</DD>\n"
    append html "<DT><A HREF=\"TdbcmysqlCmd/contents.htm\">tdbc::mysql Package Commands</A></DT>\n"
    append html "<DD>The additional commands provided by the tdbc::mysql package.</DD>\n"
    append html "<DT><A HREF=\"TdbcodbcCmd/contents.htm\">tdbc::odbc Package Commands</A></DT>\n"
    append html "<DD>The additional commands provided by the tdbc::odbc package.</DD>\n"
    append html "<DT><A HREF=\"TdbcpostgresCmd/contents.htm\">tdbc::postgres Package Commands</A></DT>\n"
    append html "<DD>The additional commands provided by the tdbc::postgres package.</DD>\n"
    append html "<DT><A HREF=\"TdbcsqliteCmd/contents.htm\">tdbc::sqlite3 Package Commands</A></DT>\n"
    append html "<DD>The additional commands provided by the tdbc::sqlite3 package.</DD>\n"
    append html "<DT><A HREF=\"ThreadCmd/contents.htm\">Thread Package Commands</A></DT>\n"
    append html "<DD>The additional commands provided by the Thread package.</DD>\n"
    append html "<DT><A HREF=\"TclLib/contents.htm\">Tcl Library</A></DT>\n"
    append html "<DD>The C functions which a Tcl extended C program may use.</DD>\n"
    append html "<DT><A HREF=\"TkLib/contents.htm\">Tk Library</A></DT>\n"
    append html "<DD>The additional C functions which a Tk extended C program may use.</DD>\n"
    append html "<DT><A HREF=\"ItclLib/contents.htm\">[incr Tcl] Package Library</A></DT>\n"
    append html "<DD>The additional C functions provided by the [incr Tcl] package.</DD>\n"
    append html "<DT><A HREF=\"TdbcLib/contents.htm\">TDBC Package Library</A></DT>\n"
    append html "<DD>The additional C functions provided by the TDBC package.</DD>\n"
    append html "<DT><A HREF=\"Keywords/contents.htm\">Keywords</A>\n"
    append html "<DD>The keywords from the Tcl/Tk man pages.\n"
    append html "<!--\n"
    append html "<DT><A HREF=\"tutorial/tcltutorial.html\">Tcl Tutorial</A></DT>\n"
    append html "<DD>Tutorial for Tcl features.</DD>\n"
    append html "-->\n"
    append html "</DL>\n\n"
    
    # Footer
    append html "<br clear=\"all\" />\n"
    append html "<p align=\"center\" class=\"footer\">\n"
    append html "		    <small><b>\n"
    append html "		    This is the main Tcl Developer Xchange site,\n"
    append html "		    www.tcl-lang.org .\n"
    append html "		    </b></small>\n"
    append html "		&nbsp;&nbsp;\n"
    append html "<a href=\"/siteinfo.html\">About this Site</a> |\n"
    append html "<a href=\"/cdn-cgi/l/email-protection#7a0d1f18171b090e1f083a0e191657161b141d5415081d\"><span class=\"__cf_email__\" data-cfemail=\"95e2f0f7f8f4e6e1f0e7d5e1f6f9b8f9f4fbf2bbfae7f2\">[email&#160;protected]</span></a>\n"
    append html "<br>\n"
    append html "<a href=\"/\">Home</a> | \n"
    append html "<a href=\"/about/\">About Tcl/Tk</a> |\n"
    append html "<a href=\"/software/tcltk/\">Software</a> | \n"
    append html "<a href=\"/community/coreteam/\">Core Development</a> |\n"
    append html "<a href=\"/community/\">Community</a> |\n"
    append html "<a href=\"/doc/\">Documentation</a>\n"
    append html "</p>\n"
    append html "</td></tr></table>"
    
    # Scripts
    append html "<script data-cfasync=\"false\" src=\"/cdn-cgi/scripts/5c5dd728/cloudflare-static/email-decode.min.js\" defer></script>"
    
    # Close tags
    append html "</body></html>\n"
    
    return $html
}

# Main execution
if {$argc != 1} {
    puts "Usage: $argv0 <output_file>"
    exit 1
}

set output_file [lindex $argv 0]
set html_content [generateHTML]

if {[catch {open $output_file w} file_handle]} {
    puts "Error: Could not open file $output_file for writing"
    exit 1
}

puts $file_handle $html_content
close $file_handle

puts "HTML file generated successfully: $output_file"
