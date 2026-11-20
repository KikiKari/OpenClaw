#!/usr/bin/env pwsh
# index.html — portiert nach powershell
# Quelle: html, OpenClaw@gateway1:skills/scripting-utils/references/eggdrop/index.html
# auch in: OpenClaw@gateway2:skills/scripting-utils/references/eggdrop/index.html
# Erzeugt: 2026-11-08 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
    Generates an HTML document similar to the provided index.html and writes it to a specified file.
.DESCRIPTION
    This PowerShell script creates a structured HTML document based on the provided index.html content,
    and outputs it to a file specified by the -OutputPath parameter.
.PARAMETER OutputPath
    The path where the generated HTML file will be saved.
.EXAMPLE
    .\generate-index.ps1 -OutputPath "index.html"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)

# Create HTML document structure
$HTMLDocument = @{
    Head = @{
        Title = "Eggdrop, an open source IRC bot -- Eggdrop 1.10.1 documentation"
        Meta = @(
            @{charset = "utf-8"},
            @{name = "viewport"; content = "width=device-width, initial-scale=1.0"}
        )
        Links = @(
            @{rel = "stylesheet"; type = "text/css"; href = "_static/pygments.css?v=03e43079"},
            @{rel = "stylesheet"; type = "text/css"; href = "_static/eggdrop.css?v=ab48a1b6"},
            @{rel = "search"; title = "Search"; href = "search.html"},
            @{rel = "next"; title = "README"; href = "install/readme.html"; accesskey = "N"}
        )
        Scripts = @(
            @{src = "_static/documentation_options.js?v=290de6c6"},
            @{src = "_static/doctools.js?v=9bcbadda"},
            @{src = "_static/sphinx_highlight.js?v=dc90522c"}
        )
    }
    Body = @{
        HeaderWrapper = @{
            Header = @{
                HeaderTitle = @{
                    Text = "Eggdrop 1.10.1 documentation"
                    Href = "#"
                }
                RelNav = @{
                    Next = @{
                        Title = "README"
                        Href = "install/readme.html"
                        AccessKey = "N"
                    }
                }
            }
        }
        ContentWrapper = @{
            Sidebar = @{
                TOC = @{
                    Sections = @(
                        @{
                            Caption = "Installing Eggdrop"
                            Items = @(
                                @{Href = "install/readme.html"; Text = "README"},
                                @{Href = "install/install.html"; Text = "Installing Eggdrop"},
                                @{Href = "install/upgrading.html"; Text = "Upgrading Eggdrop"}
                            )
                        },
                        @{
                            Caption = "Using Eggdrop"
                            Items = @(
                                @{Href = "using/features.html"; Text = "Eggdrop Features"},
                                @{Href = "using/core.html"; Text = "Eggdrop Core Settings"},
                                @{Href = "using/partyline.html"; Text = "The Party Line"},
                                @{Href = "using/autoscripts.html"; Text = "Eggdrop Autoscripts"},
                                @{Href = "using/users.html"; Text = "Users and Flags"},
                                @{Href = "using/bans.html"; Text = "Bans, Invites, and Exempts"},
                                @{Href = "using/botnet.html"; Text = "Botnet Sharing and Linking"},
                                @{Href = "using/ipv6.html"; Text = "IPv6 support"},
                                @{Href = "using/tls.html"; Text = "TLS support"},
                                @{Href = "using/ircv3.html"; Text = "IRCv3 support"},
                                @{Href = "using/accounts.html"; Text = "Account tracking in Eggdrop"},
                                @{Href = "using/pbkdf2info.html"; Text = "Encryption/Hashing"},
                                @{Href = "using/python.html"; Text = "Using the Python Module"},
                                @{Href = "using/twitchinfo.html"; Text = "Twitch"},
                                @{Href = "using/tricks.html"; Text = "Advanced Tips"},
                                @{Href = "using/text-sub.html"; Text = "Textfile Substitutions"},
                                @{Href = "using/tcl-commands.html"; Text = "Eggdrop Tcl Commands"},
                                @{Href = "using/twitch-tcl-commands.html"; Text = "Eggdrop Twitch Tcl Commands"},
                                @{Href = "using/patch.html"; Text = "Patching Eggdrop"}
                            )
                        },
                        @{
                            Caption = "Tutorials"
                            Items = @(
                                @{Href = "tutorials/setup.html"; Text = "Setting Up Eggdrop"},
                                @{Href = "tutorials/firststeps.html"; Text = "Common First Steps"},
                                @{Href = "tutorials/tlssetup.html"; Text = "Enabling TLS Security on Eggdrop"},
                                @{Href = "tutorials/userfilesharing.html"; Text = "Sharing Userfiles"},
                                @{Href = "tutorials/firstscript.html"; Text = "Writing an Eggdrop Tcl Script"},
                                @{Href = "tutorials/module.html"; Text = "Writing a Basic Eggdrop Module"}
                            )
                        },
                        @{
                            Caption = "Eggdrop Modules"
                            Items = @(
                                @{Href = "modules/index.html"; Text = "Eggdrop Module Information"},
                                @{Href = "modules/included.html"; Text = "Modules included with Eggdrop"},
                                @{Href = "modules/writing.html"; Text = "How to Write an Eggdrop Module"},
                                @{Href = "modules/internals.html"; Text = "Eggdrop Bind Internals"}
                            )
                        },
                        @{
                            Caption = "About Eggdrop"
                            Items = @(
                                @{Href = "about/about.html"; Text = "About Eggdrop"},
                                @{Href = "about/legal.html"; Text = "Boring legal stuff"}
                            )
                        }
                    )
                }
                SearchForm = @{
                    Action = "search.html"
                    Method = "get"
                }
            }
            Document = @{
                DocumentWrapper = @{
                    BodyWrapper = @{
                        BodyContent = @{
                            Sections = @(
                                @{
                                    Id = "eggdrop-an-open-source-irc-bot"
                                    Title = "Eggdrop, an open source IRC bot"
                                    Content = @"
Eggdrop is a free, open source software program built to assist in managing an IRC channel. It is the world's oldest actively-maintained IRC bot and was designed to be easily used and expanded on via it's ability to run Tcl scripts. Eggdrop can join IRC channels and perorm automated tasks such as protecting the channel from abuse, assisting users obtain their op/voice status, provide information and greetings, host games, etc.
"@
                                    SubSections = @(
                                        @{
                                            Id = "some-things-you-can-do-with-eggdrop"
                                            Title = "Some things you can do with Eggdrop"
                                            Content = @"
Eggdrop has a large number of features, such as:
"@
                                            ListItems = @(
                                                @{Href = "using/users.html"; Text = "Channel Management"},
                                                @{Text = "Running Tcl Scripts"},
                                                @{Href = "using/ircv3.html"; Text = "Integration of the most current IRCv3 capabilities"},
                                                @{Href = "using/botnet.html"; Text = "The ability to link multiple Eggdrops together and share userfiles"},
                                                @{Href = "using/tls.html"; Text = "TLS Support"},
                                                @{Href = "using/ipv6.html"; Text = "IPv6 Support"},
                                                @{Href = "using/twitchinfo.html"; Text = "Twitch Support"},
                                                @{Text = "... and much much more!"}
                                            )
                                        },
                                        @{
                                            Id = "how-to-get-eggdrop"
                                            Title = "How to get Eggdrop"
                                            Content = @"
The Eggdrop project source code is hosted at https://github.com/eggheads/eggdrop. You can clone it via git, or alternatively a copy of the current stable snapshot is located at https://geteggdrop.com. Additional information can be found on the official Eggdrop webpage at https://www.eggheads.org. For more information, see Installing Eggdrop
"@
                                        },
                                        @{
                                            Id = "how-to-install-eggdrop"
                                            Title = "How to install Eggdrop"
                                            SubSections = @(
                                                @{
                                                    Id = "installation-pre-requisites"
                                                    Title = "Installation Pre-requisites"
                                                    Content = "Eggdrop requires Tcl (and its development header files) to be present on the system it is compiled on. It is also strongly encouraged to install openssl (and its development header files) to enable TLS-protected network communication."
                                                },
                                                @{
                                                    Id = "installation"
                                                    Title = "Installation"
                                                    Content = "A guide to quickly installing Eggdrop can be found here."
                                                }
                                            )
                                        },
                                        @{
                                            Id = "where-to-find-more-help"
                                            Title = "Where to find more help"
                                            Content = "The Eggheads development team can be found lurking on #eggdrop on the Libera network (irc.libera.chat)."
                                        }
                                    )
                                }
                            )
                        }
                    }
                }
            }
        }
        FooterWrapper = @{
            Footer = @{
                Left = @{
                    Navigation = @{
                        Next = @{
                            Title = "README"
                            Href = "install/readme.html"
                        }
                    }
                }
                Right = @{
                    Copyright = "© Copyright 2025, Eggheads."
                    LastUpdated = "Last updated on Aug 15, 2025."
                    CreatedWith = "Created using Sphinx 8.2.3."
                }
            }
        }
    }
}

# Generate HTML content
$HTMLContent = @"
<!DOCTYPE html>
<html lang="en" data-content_root="./">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1.0"/>
<title>$($HTMLDocument.Head.Title)</title>
<link rel="stylesheet" type="text/css" href="$($HTMLDocument.Head.Links[0].href)"/>
<link rel="stylesheet" type="text/css" href="$($HTMLDocument.Head.Links[1].href)"/>
<script src="$($HTMLDocument.Head.Scripts[0].src)"></script>
<script src="$($HTMLDocument.Head.Scripts[1].src)"></script>
<script src="$($HTMLDocument.Head.Scripts[2].src)"></script>
<link rel="search" title="Search" href="$($HTMLDocument.Head.Links[2].href)"/>
<link rel="next" title="$($HTMLDocument.Head.Links[3].title)" href="$($HTMLDocument.Head.Links[3].href)" accesskey="N"/>
</head>
<body>
<div class="header-wrapper" role="banner">
<div class="header">
<div class="headertitle"><a href="$($HTMLDocument.Body.HeaderWrapper.Header.HeaderTitle.Href)">$($HTMLDocument.Body.HeaderWrapper.Header.HeaderTitle.Text)</a></div>
<div class="rel" role="navigation" aria-label="related navigation">
<a href="$($HTMLDocument.Body.HeaderWrapper.Header.RelNav.Next.Href)" title="$($HTMLDocument.Body.HeaderWrapper.Header.RelNav.Next.Title)" accesskey="N">next</a>
</div>
</div>
</div>
<div class="content-wrapper">
<div class="content">
<div class="sidebar">
<h3>Table of Contents</h3>
$(
    foreach ($section in $HTMLDocument.Body.Sidebar.TOC.Sections) {
        "<p class=`"caption`" role=`"heading`"><span class=`"caption-text`">$($section.Caption)</span></p>`n<ul>`n"
        foreach ($item in $section.Items) {
            "<li class=`"toctree-l1`"><a class=`"reference internal`" href=`"$($item.Href)`">$($item.Text)</a></li>`n"
        }
        "</ul>`n"
    }
)
<div role="search">
<h3 style="margin-top: 1.5em;">Search</h3>
<form class="search" action="$($HTMLDocument.Body.Sidebar.SearchForm.Action)" method="$($HTMLDocument.Body.Sidebar.SearchForm.Method)">
<input type="text" name="q"/>
<input type="submit" value="Go"/>
</form>
</div>
</div>
<div class="document">
<div class="documentwrapper">
<div class="bodywrapper">
<div class="body" role="main">
$(
    foreach ($section in $HTMLDocument.Body.Document.DocumentWrapper.BodyWrapper.BodyContent.Sections) {
        "<section id=`"$($section.Id)`">`n<h1>$($section.Title)<a class=`"headerlink`" href=`"#$($section.Id)`" title=`"Link to this heading`">¶</a></h1>`n<p>$($section.Content)</p>`n"
        foreach ($subSection in $section.SubSections) {
            "<section id=`"$($subSection.Id)`">`n<h2>$($subSection.Title)<a class=`"headerlink`" href=`"#$($subSection.Id)`" title=`"Link to this heading`">¶</a></h2>`n"
            if ($subSection.Content) {
                "<p>$($subSection.Content)</p>`n"
            }
            if ($subSection.ListItems) {
                "<ul class=`"simple`">`n"
                foreach ($item in $subSection.ListItems) {
                    if ($item.Href) {
                        "<li><p><a class=`"reference external`" href=`"$($item.Href)`">$($item.Text)</a></p></li>`n"
                    } else {
                        "<li><p>$($item.Text)</p></li>`n"
                    }
                }
                "</ul>`n"
            }
            if ($subSection.SubSections) {
                foreach ($subSubSection in $subSection.SubSections) {
                    "<section id=`"$($subSubSection.Id)`">`n<h3>$($subSubSection.Title)<a class=`"headerlink`" href=`"#$($subSubSection.Id)`" title=`"Link to this heading`">¶</a></h3>`n<p>$($subSubSection.Content)</p>`n</section>`n"
                }
            }
            "</section>`n"
        }
        "</section>`n"
    }
)
</div>
</div>
</div>
</div>
<div class="clearer"></div>
</div>
</div>
<div class="footer-wrapper">
<div class="footer">
<div class="left">
<div role="navigation" aria-label="related navigaton">
<a href="$($HTMLDocument.Body.FooterWrapper.Footer.Left.Navigation.Next.Href)" title="$($HTMLDocument.Body.FooterWrapper.Footer.Left.Navigation.Next.Title)">next</a>
</div>
<div role="note" aria-label="source link">
</div>
</div>
<div class="right">
<div class="footer" role="contentinfo">
$($HTMLDocument.Body.FooterWrapper.Footer.Right.Copyright)
$($HTMLDocument.Body.FooterWrapper.Footer.Right.LastUpdated)
$($HTMLDocument.Body.FooterWrapper.Footer.Right.CreatedWith)
</div>
</div>
<div class="clearer"></div>
</div>
</div>
</body>
</html>
"@

# Write HTML content to file
$HTMLContent | Out-File -FilePath $OutputPath -Encoding utf8

Write-Host "HTML document generated successfully at $OutputPath"
