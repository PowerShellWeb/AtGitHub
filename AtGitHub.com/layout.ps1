param(
    [Alias('Palette')]
    [string]
    $PaletteName = $(
        if ($config -and $config['PaletteName']) { $config['PaletteName'] }
        else { 'Konsolas' }    
    ),
    [Alias('FontName')]
    [string]
    $Font        = $(
        if ($config -and $config['FontName']) { $config['FontName'] }
        else { 'Roboto' }
    ),
    [string]
    $CodeFont   = $(
        if ($config -and $config['CodeFontName']) { $config['CodeFontName'] }
        else { 'Inconsolata' }
    ),
    
    [string[]]
    $FavIcon
)

$argsAndinput = @($args) + @($input)

if (-not $Site) { $Site = [Ordered]@{} }
if (-not $page) { $page = [Ordered]@{} }
if (-not $page.MetaData) { $page.MetaData = [Ordered]@{} }

$page.MetaData['og:title'] = 
    if ($title) {
        $title
    } elseif ($Page.title) {
        $Page.title
    } elseif ($site.title) {
        $site.title
    }

$page.MetaData['og:description'] =
    if ($description) { $description } 
    elseif ($page.description) { $page.description } 
    elseif ($site.description) { $site.description }

$page.MetaData['og:image'] =
    if ($image) { $image } 
    elseif ($page.image) { $page.image } 
    elseif ($site.image) { $site.image }

if ($page.MetaData['og:image']) {
    $page.MetaData['og:image'] = $page.MetaData['og:image'] -replace '^/', '' -replace '^[^h]', '/'
}



$style = @"
body {
    width: 100vw;
    height: 100vh;
    font-family: '$Font', sans-serif;
}    
pre, code {
    font-family: '$CodeFont', monospace;
}
a, a:visited {
    color: var(--foreground);
    text-decoration: none;
}

.mainGrid {
    display: grid;
    height: 100vh;
    width: 100vw;
    grid:
        "$( @('header') * 9)" minmax(100px, auto)
        "$( @('main') * 9)" minmax(100px, auto)
        "$( @('main') * 9)" minmax(100px, auto)
        "$( @('main') * 9)" minmax(100px, auto)
        "$( @('footer') * 9)" minmax(100px, auto)
        / $( @('1fr') * 9);
    align-content: center;
}
"@

@"
<html>
    <head>
        $(
            if ($site.analyticsID) {
@"
<!-- Google tag (gtag.js) -->
<script async src="https://www.googletagmanager.com/gtag/js?id=$($site.AnalyticsID)"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', '$($site.AnalyticsID)');
</script>
"@
            }
        )
        <title>$(if ($page['Title']) { $page['Title'] } else { $Title})</title>        
        <meta name='viewport' content='width=device-width, initial-scale=1' />
        <link rel='stylesheet' href='https://cdn.jsdelivr.net/gh/2bitdesigns/4bitcss@latest/css/$PaletteName.css' id='palette' />
        <link rel='stylesheet' href='https://fonts.googleapis.com/css?family=$Font' id='font' />
        <link rel='stylesheet' href='https://fonts.googleapis.com/css?family=$CodeFont' id='codeFont' />
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@latest/build/styles/default.min.css" id='highlight' />
        $(
            if ($FavIcon) { 
                switch -regex ($FavIcon) {
                    '\.svg$' {
                        if ($_ -match '\d+x\d+') {
                            "<link rel='icon' href='$_' type='image/svg+xml' sizes='$($matches.0)' />"
                        } else {
                            "<link rel='icon' href='$_' type='image/svg+xml' sizes='any' />"
                        }                        
                    }
                    '\.png$' {
                        if ($_ -match '\d+x\d+') {
                            "<link rel='icon' href='$_' type='image/png' sizes='$($matches.0)' />"
                        } else {
                            "<link rel='icon' href='$_' type='image/png' sizes='any' />"
                        }                        
                    }
                }
            }
        )
        <script src='https://unpkg.com/htmx.org@latest'></script>
        $(
            if (
                $Page.MetaData -is [Collections.IDictionary] -and 
                $Page.MetaData.Count
            ) {
                foreach ($og in $Page.MetaData.GetEnumerator()) {
                    "<meta name='$([Web.HttpUtility]::HtmlAttributeEncode($og.Key))' content='$([Web.HttpUtility]::HtmlAttributeEncode($og.Value))' />"
                }
            }
        )
        $ImportMap        
        <style>
$style
        </style>
        $(
            @(
                '<script src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@latest/build/highlight.min.js"></script>'
                foreach ($language in 'powershell') {
                    "<script src='https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@latest/build/languages/$language.min.js'></script>"
                }
            ) -join [Environment]::NewLine
        )
    </head>
    <body>
        <div id='content'>
            $($argsAndinput -join [Environment]::NewLine)
        </div>
        <script>hljs.highlightAll();</script>
    </body>
</html>
"@
