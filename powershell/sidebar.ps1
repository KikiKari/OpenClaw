#!/usr/bin/env pwsh
# abstraction-provenance: {"artifact_sha256": "9387908ed1a5cea4b2cf0a83b9a54759ecf0f04667adc06aa35cde16a04fca32", "source_sha256": "495ea0a0b976b10360709637ad086ec1b1fd4496c479c1d93db8b3acf95f1318", "target_language": "powershell"}
# sidebar.css — portiert nach powershell
# Quelle: css, workspace@local:skills/github-clones/openclaw/ui/src/styles/chat/sidebar.css
# Erzeugt: 2026-11-19 durch ABSTRACTIONS_MANAGER.py

<#
.SYNOPSIS
    Generates the sidebar.css file with all defined styles.
.PARAMETER OutputPath
    The path where the CSS file will be saved.
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$OutputPath
)

# Create a hashtable representing the CSS structure
$cssRules = @{}

# Add Split View Layout rules
$cssRules['.chat-split-container'] = @{
    'display' = 'flex'
    'gap' = '0'
    'flex' = '1'
    'min-height' = '0'
    'height' = '100%'
}

$cssRules['.chat-main'] = @{
    'min-width' = '312px'
    'display' = 'flex'
    'flex-direction' = 'column'
    'overflow' = 'hidden'
    'transition' = 'flex 250ms ease-out'
}

$cssRules['.chat-sidebar'] = @{
    'flex' = '1'
    'min-width' = '300px'
    'border-left' = '1px solid var(--border)'
    'display' = 'flex'
    'flex-direction' = 'column'
    'overflow' = 'hidden'
    'animation' = 'slide-in 200ms ease-out'
}

# Keyframes need special handling
$keyframes = @{
    'slide-in' = @{
        'from' = @{
            'opacity' = '0'
            'transform' = 'translateX(20px)'
        }
        'to' = @{
            'opacity' = '1'
            'transform' = 'translateX(0)'
        }
    }
}

# Add Sidebar Panel rules
$cssRules['.sidebar-panel'] = @{
    'display' = 'flex'
    'flex-direction' = 'column'
    'height' = '100%'
    'background' = 'var(--panel)'
}

$cssRules['.sidebar-header'] = @{
    'display' = 'flex'
    'justify-content' = 'space-between'
    'align-items' = 'center'
    'padding' = '12px 16px'
    'border-bottom' = '1px solid var(--border)'
    'flex-shrink' = '0'
    'position' = 'sticky'
    'top' = '0'
    'z-index' = '10'
    'background' = 'var(--panel)'
}

$cssRules['.sidebar-header .btn'] = @{
    'padding' = '4px 8px'
    'font-size' = '14px'
    'min-width' = 'auto'
    'line-height' = '1'
}

$cssRules['.sidebar-title'] = @{
    'font-weight' = '600'
    'font-size' = '14px'
}

$cssRules['.sidebar-content'] = @{
    'flex' = '1'
    'overflow' = 'auto'
    'padding' = '16px'
}

$cssRules['.sidebar-markdown'] = @{
    'font-size' = '14px'
    'line-height' = '1.6'
    'color' = 'var(--text)'
}

# Headings
$cssRules['.sidebar-markdown :where(h1)'] = @{
    'font-size' = '1.65em'
    'font-weight' = '700'
    'letter-spacing' = '-0.025em'
    'margin' = '1.6em 0 0.6em'
    'padding-bottom' = '0.35em'
    'border-bottom' = '1px solid var(--border)'
    'line-height' = '1.25'
}

$cssRules['.sidebar-markdown :where(h2)'] = @{
    'font-size' = '1.35em'
    'font-weight' = '650'
    'letter-spacing' = '-0.02em'
    'margin' = '1.4em 0 0.5em'
    'padding-bottom' = '0.25em'
    'border-bottom' = '1px solid var(--border)'
    'line-height' = '1.3'
}

$cssRules['.sidebar-markdown :where(h3)'] = @{
    'font-size' = '1.15em'
    'font-weight' = '600'
    'letter-spacing' = '-0.01em'
    'margin' = '1.2em 0 0.4em'
    'line-height' = '1.35'
}

$cssRules['.sidebar-markdown :where(h4, h5, h6)'] = @{
    'font-size' = '1em'
    'font-weight' = '600'
    'margin' = '1em 0 0.35em'
    'line-height' = '1.4'
    'color' = 'var(--text-strong)'
}

$cssRules['.sidebar-markdown > :where(h1, h2, h3, h4, h5, h6):first-child'] = @{
    'margin-top' = '0'
}

# Paragraphs & spacing
$cssRules['.sidebar-markdown :where(p, ul, ol, pre, blockquote, table, details)'] = @{
    'margin' = '0'
}

$cssRules['.sidebar-markdown :where(p + p, p + ul, p + ol, p + pre, p + blockquote, p + table, p + details)'] = @{
    'margin-top' = '0.75em'
}

$cssRules['.sidebar-markdown :where(h1 + p, h2 + p, h3 + p, h4 + p)'] = @{
    'margin-top' = '0'
}

# Lists
$cssRules['.sidebar-markdown :where(ul, ol)'] = @{
    'padding-left' = '1.6em'
}

$cssRules['.sidebar-markdown :where(li + li)'] = @{
    'margin-top' = '0.3em'
}

$cssRules['.sidebar-markdown :where(li > p)'] = @{
    'margin-top' = '0.25em'
}

$cssRules['.sidebar-markdown :where(li > ul, li > ol)'] = @{
    'margin-top' = '0.25em'
}

# Links
$cssRules['.sidebar-markdown :where(a)'] = @{
    'color' = 'var(--accent)'
    'text-decoration' = 'underline'
    'text-underline-offset' = '2px'
    'text-decoration-color' = 'color-mix(in srgb, var(--accent) 40%, transparent)'
    'transition' = 'text-decoration-color var(--duration-fast) ease'
}

$cssRules['.sidebar-markdown :where(a:hover)'] = @{
    'text-decoration-color' = 'var(--accent)'
}

# Inline code
$cssRules['.sidebar-markdown code'] = @{
    'font-family' = 'var(--mono)'
    'font-size' = '0.88em'
}

$cssRules['.sidebar-markdown :where(:not(pre) > code)'] = @{
    'padding' = '0.15em 0.4em'
    'border-radius' = 'var(--radius-sm)'
    'background' = 'rgba(0, 0, 0, 0.12)'
    'border' = '1px solid var(--border)'
}

$cssRules[':root[data-theme-mode="light"] .sidebar-markdown :where(:not(pre) > code)'] = @{
    'background' = 'rgba(0, 0, 0, 0.06)'
}

# Code blocks
$cssRules['.sidebar-markdown pre'] = @{
    'background' = 'rgba(0, 0, 0, 0.12)'
    'border' = '1px solid var(--border)'
    'border-radius' = 'var(--radius-md)'
    'padding' = '14px 16px'
    'overflow-x' = 'auto'
    'margin-top' = '0.75em'
}

$cssRules[':root[data-theme-mode="light"] .sidebar-markdown pre'] = @{
    'background' = 'rgba(0, 0, 0, 0.04)'
}

$cssRules['.sidebar-markdown :where(pre code)'] = @{
    'background' = 'none'
    'border' = 'none'
    'padding' = '0'
    'font-size' = '12.5px'
    'line-height' = '1.55'
}

# Blockquotes
$cssRules['.sidebar-markdown :where(blockquote)'] = @{
    'border-left' = '3px solid var(--border-strong)'
    'padding' = '8px 14px'
    'margin-left' = '0'
    'margin-top' = '0.75em'
    'color' = 'var(--muted)'
    'background' = 'rgba(255, 255, 255, 0.02)'
    'border-radius' = '0 var(--radius-sm) var(--radius-sm) 0'
}

$cssRules[':root[data-theme-mode="light"] .sidebar-markdown :where(blockquote)'] = @{
    'background' = 'rgba(0, 0, 0, 0.025)'
}

$cssRules['.sidebar-markdown :where(blockquote blockquote)'] = @{
    'margin-top' = '8px'
}

# Tables
$cssRules['.sidebar-markdown :where(table)'] = @{
    'margin-top' = '0.75em'
    'border-collapse' = 'collapse'
    'width' = '100%'
    'font-size' = '13px'
    'display' = 'block'
    'overflow-x' = 'auto'
}

$cssRules['.sidebar-markdown :where(th, td)'] = @{
    'border' = '1px solid var(--border)'
    'padding' = '8px 12px'
    'text-align' = 'left'
    'vertical-align' = 'top'
}

$cssRules['.sidebar-markdown :where(th)'] = @{
    'font-weight' = '600'
    'font-size' = '12px'
    'color' = 'var(--muted)'
    'background' = 'var(--secondary)'
    'text-transform' = 'uppercase'
    'letter-spacing' = '0.03em'
}

$cssRules['.sidebar-markdown :where(tbody tr:hover)'] = @{
    'background' = 'var(--bg-hover)'
}

# Horizontal rules
$cssRules['.sidebar-markdown :where(hr)'] = @{
    'border' = 'none'
    'border-top' = '1px solid var(--border)'
    'margin' = '1.5em 0'
}

# Bold / italic
$cssRules['.sidebar-markdown :where(strong)'] = @{
    'font-weight' = '600'
    'color' = 'var(--text-strong)'
}

# Images
$cssRules['.sidebar-markdown .markdown-inline-image'] = @{
    'display' = 'block'
    'max-width' = '100%'
    'max-height' = '420px'
    'width' = 'auto'
    'height' = 'auto'
    'border' = '1px solid var(--border)'
    'border-radius' = 'var(--radius-md)'
    'background' = 'color-mix(in srgb, var(--secondary) 70%, transparent)'
    'object-fit' = 'contain'
    'margin-top' = '0.75em'
}

# Details / summary
$cssRules['.sidebar-markdown :where(details)'] = @{
    'margin-top' = '0.75em'
    'border' = '1px solid var(--border)'
    'border-radius' = 'var(--radius-md)'
    'background' = 'var(--bg-elevated)'
    'overflow' = 'hidden'
}

$cssRules['.sidebar-markdown :where(summary)'] = @{
    'cursor' = 'pointer'
    'padding' = '8px 12px'
    'font-weight' = '500'
    'font-size' = '13px'
    'user-select' = 'none'
    'transition' = 'background var(--duration-fast) ease'
}

$cssRules['.sidebar-markdown :where(summary:hover)'] = @{
    'background' = 'var(--bg-hover)'
}

$cssRules['.sidebar-markdown :where(details[open] > :not(summary))'] = @{
    'padding' = '0 12px 10px'
}

# Media queries need special handling
$mediaQueries = @(
    @{
        query = '(max-width: 768px)'
        rules = @{
            '.chat-split-container--open' = @{
                'position' = 'fixed'
                'top' = '0'
                'left' = '0'
                'right' = '0'
                'bottom' = '0'
                'z-index' = '1000'
            }
            '.chat-split-container--open .chat-main' = @{
                'display' = 'none'
            }
            '.chat-split-container--open .chat-sidebar' = @{
                'width' = '100%'
                'min-width' = '0'
                'border-left' = 'none'
            }
        }
    }
)

# Function to convert hashtable to CSS string
function Convert-ToCSS {
    param(
        [hashtable]$Rules,
        [string]$Indent = ""
    )
    
    $output = ""
    foreach ($selector in ($Rules.Keys | Sort-Object)) {
        $properties = $Rules[$selector]
        $output += "${Indent}${selector} {`n"
        
        foreach ($prop in ($properties.Keys | Sort-Object)) {
            $value = $properties[$prop]
            $output += "${Indent}  ${prop}: ${value};`n"
        }
        
        $output += "${Indent}}`n`n"
    }
    return $output
}

# Generate the CSS content
$cssContent = "/* Split View Layout */`n"
$cssContent += Convert-ToCSS -Rules @{ 
    '.chat-split-container' = $cssRules['.chat-split-container']
    '.chat-main' = $cssRules['.chat-main']
    '.chat-sidebar' = $cssRules['.chat-sidebar']
}

# Add keyframes
$cssContent += "@keyframes slide-in {`n"
$cssContent += "  from {`n"
$cssContent += "    opacity: $($keyframes['slide-in']['from']['opacity']);`n"
$cssContent += "    transform: $($keyframes['slide-in']['from']['transform']);`n"
$cssContent += "  }`n"
$cssContent += "  to {`n"
$cssContent += "    opacity: $($keyframes['slide-in']['to']['opacity']);`n"
$cssContent += "    transform: $($keyframes['slide-in']['to']['transform']);`n"
$cssContent += "  }`n"
$cssContent += "}`n`n"

# Continue with other sections
$cssContent += "/* Sidebar Panel */`n"
$cssContent += Convert-ToCSS -Rules @{ 
    '.sidebar-panel' = $cssRules['.sidebar-panel']
    '.sidebar-header' = $cssRules['.sidebar-header']
    '.sidebar-header .btn' = $cssRules['.sidebar-header .btn']
    '.sidebar-title' = $cssRules['.sidebar-title']
    '.sidebar-content' = $cssRules['.sidebar-content']
    '.sidebar-markdown' = $cssRules['.sidebar-markdown']
}

# Headings section
$cssContent += "/* ── Headings ── */`n"
$cssContent += Convert-ToCSS -Rules @{ 
    '.sidebar-markdown :where(h1)' = $cssRules['.sidebar-markdown :where(h1)']
    '.sidebar-markdown :where(h2)' = $cssRules['.sidebar-markdown :where(h2)']
    '.sidebar-markdown :where(h3)' = $cssRules['.sidebar-markdown :where(h3)']
    '.sidebar-markdown :where(h4, h5, h6)' = $cssRules['.sidebar-markdown :where(h4, h5, h6)']
    '.sidebar-markdown > :where(h1, h2, h3, h4, h5, h6):first-child' = $cssRules['.sidebar-markdown > :where(h1, h2, h3, h4, h5, h6):first-child']
}

# Paragraphs & spacing
$cssContent += "/* ── Paragraphs & spacing ── */`n"
$cssContent += Convert-ToCSS -Rules @{ 
    '.sidebar-markdown :where(p, ul, ol, pre, blockquote, table, details)' = $cssRules['.sidebar-markdown :where(p, ul, ol, pre, blockquote, table, details)']
    '.sidebar-markdown :where(p + p, p + ul, p + ol, p + pre, p + blockquote, p + table, p + details)' = $cssRules['.sidebar-markdown :where(p + p, p + ul, p + ol, p + pre, p + blockquote, p + table, p + details)']
    '.sidebar-markdown :where(h1 + p, h2 + p, h3 + p, h4 + p)' = $cssRules['.sidebar-markdown :where(h1 + p, h2 + p, h3 + p, h4 + p)']
}

# Lists
$cssContent += "/* ── Lists ── */`n"
$cssContent += Convert-ToCSS -Rules @{ 
    '.sidebar-markdown :where(ul, ol)' = $cssRules['.sidebar-markdown :where(ul, ol)']
    '.sidebar-markdown :where(li + li)' = $cssRules['.sidebar-markdown :where(li + li)']
    '.sidebar-markdown :where(li > p)' = $cssRules['.sidebar-markdown :where(li > p)']
    '.sidebar-markdown :where(li > ul, li > ol)' = $cssRules['.sidebar-markdown :where(li > ul, li > ol)']
}

# Links
$cssContent += "/* ── Links ── */`n"
$cssContent += Convert-ToCSS -Rules @{ 
    '.sidebar-markdown :where(a)' = $cssRules['.sidebar-markdown :where(a)']
    '.sidebar-markdown :where(a:hover)' = $cssRules['.sidebar-markdown :where(a:hover)']
}

# Inline code
$cssContent += "/* ── Inline code ── */`n"
$cssContent += Convert-ToCSS -Rules @{ 
    '.sidebar-markdown code' = $cssRules['.sidebar-markdown code']
    '.sidebar-markdown :where(:not(pre) > code)' = $cssRules['.sidebar-markdown :where(:not(pre) > code)']
    ':root[data-theme-mode="light"] .sidebar-markdown :where(:not(pre) > code)' = $cssRules[':root[data-theme-mode="light"] .sidebar-markdown :where(:not(pre) > code)']
}

# Code blocks
$cssContent += "/* ── Code blocks ── */`n"
$cssContent += Convert-ToCSS -Rules @{ 
    '.sidebar-markdown pre' = $cssRules['.sidebar-markdown pre']
    ':root[data-theme-mode="light"] .sidebar-markdown pre' = $cssRules[':root[data-theme-mode="light"] .sidebar-markdown pre']
    '.sidebar-markdown :where(pre code)' = $cssRules['.sidebar-markdown :where(pre code)']
}

# Blockquotes
$cssContent += "/* ── Blockquotes ── */`n"
$cssContent += Convert-ToCSS -Rules @{ 
    '.sidebar-markdown :where(blockquote)' = $cssRules['.sidebar-markdown :where(blockquote)']
    ':root[data-theme-mode="light"] .sidebar-markdown :where(blockquote)' = $cssRules[':root[data-theme-mode="light"] .sidebar-markdown :where(blockquote)']
    '.sidebar-markdown :where(blockquote blockquote)' = $cssRules['.sidebar-markdown :where(blockquote blockquote)']
}

# Tables
$cssContent += "/* ── Tables ── */`n"
$cssContent += Convert-ToCSS -Rules @{ 
    '.sidebar-markdown :where(table)' = $cssRules['.sidebar-markdown :where(table)']
    '.sidebar-markdown :where(th, td)' = $cssRules['.sidebar-markdown :where(th, td)']
    '.sidebar-markdown :where(th)' = $cssRules['.sidebar-markdown :where(th)']
    '.sidebar-markdown :where(tbody tr:hover)' = $cssRules['.sidebar-markdown :where(tbody tr:hover)']
}

# Horizontal rules
$cssContent += "/* ── Horizontal rules ── */`n"
$cssContent += Convert-ToCSS -Rules @{ 
    '.sidebar-markdown :where(hr)' = $cssRules['.sidebar-markdown :where(hr)']
}

# Bold / italic
$cssContent += "/* ── Bold / italic ── */`n"
$cssContent += Convert-ToCSS -Rules @{ 
    '.sidebar-markdown :where(strong)' = $cssRules['.sidebar-markdown :where(strong)']
}

# Images
$cssContent += "/* ── Images ── */`n"
$cssContent += Convert-ToCSS -Rules @{ 
    '.sidebar-markdown .markdown-inline-image' = $cssRules['.sidebar-markdown .markdown-inline-image']
}

# Details / summary
$cssContent += "/* ── Details / summary ── */`n"
$cssContent += Convert-ToCSS -Rules @{ 
    '.sidebar-markdown :where(details)' = $cssRules['.sidebar-markdown :where(details)']
    '.sidebar-markdown :where(summary)' = $cssRules['.sidebar-markdown :where(summary)']
    '.sidebar-markdown :where(summary:hover)' = $cssRules['.sidebar-markdown :where(summary:hover)']
    '.sidebar-markdown :where(details[open] > :not(summary))' = $cssRules['.sidebar-markdown :where(details[open] > :not(summary))']
}

# Media queries
$cssContent += "/* Mobile: Full-screen modal */`n"
foreach ($mq in $mediaQueries) {
    $cssContent += "@media $($mq.query) {`n"
    foreach ($selector in $mq.rules.Keys) {
        $properties = $mq.rules[$selector]
        $cssContent += "  ${selector} {`n"
        foreach ($prop in $properties.Keys) {
            $value = $properties[$prop]
            $cssContent += "    ${prop}: ${value};`n"
        }
        $cssContent += "  }`n`n"
    }
    $cssContent += "}`n`n"
}

# Write to file
Set-Content -Path $OutputPath -Value $cssContent.TrimEnd()

Write-Host "CSS file generated successfully at $OutputPath"
