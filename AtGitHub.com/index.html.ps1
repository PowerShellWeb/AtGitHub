$Title = 'AtGitHub'

$Description = 'At Protocol GitHub'

$TopLevelLinks = 'Users', 'Repos', 'Gists', 'Discussions', 'Issues', 'Posts', 'Pulls', 'Tags'

$navigation = @($TopLevelLinks |
    ForEach-Object -Begin {
        "<nav class='navigation'>"
    } -Process {
        "<a href='$($_ -replace '\s')'><button>$($_)</button></a>"
    } -End {
        "</nav>"
    }) -join [Environment]::NewLine

$style = @"
<style type='text/css'>
.header {
    text-align: center;
    margin: 2em;
    height: 20%;
    grid-area: header;
}

.navigation {
    text-align: center;
    margin: 1em;
    height: 5%;
}

.content {
    margin: 3em;
    height: 33%;
    grid-area: main;
    text-align: center;
}

.corner {
    position: fixed;
    display: grid;
    margin-right: 0.5%;
    margin-top: 0%; 
    right: 0.5%;   
    text-align: right;
    grid-template-columns: 1fr 1fr;
}

.corner div {
    padding: 0.5em;
}
</style>
"@

$header = @"
<div class='header'>
<a href='/'>
<svg>
$(
    Get-Content .\Assets\AtGitHub-Animated.svg -Raw
)
</svg>
<h1>
$Title
</h1>
</a>
$navigation
</div>
"@




$content = @"
<div class='content'>
$(
if ($site.AtData) {
    $tableCounts = 
        "$($site.AtData.Tables['app.bsky.feed.post'].Rows.Count) posts",
        "$($site.AtData.Tables['app.bsky.feed.like'].Rows.Count) likes",
        "$($site.AtData.Tables['app.bsky.feed.repost'].Rows.Count) reposts"

    $Description = "AtGitHub | $($tableCounts -join ' | ')"

    "<h3>$($tableCounts -join ' | ')</h3>"
    if (-not $site.LastBuildTime) {
        $site.LastBuildTime = [DateTime]::UtcNow
    }
    "<h4 data-last-updated='$($site.LastBuildTime.ToString('o'))' id='lastUpdated'></h4>"
    "<script>"
    "document.getElementById('lastUpdated').innerHTML = 'Last Updated @ ' + new Date('$($site.LastBuildTime.ToString('o'))').toLocaleString();"
    "</script>"
    # "<h4>Last Updated @ $(if ($site.LastBuildTime -is [DateTime]) { $site.LastBuildTime.ToString('r') })</h4>"
} else {
    "No data available."
}
)
</div>
"@

$corner = @"
<div class='corner'>
<div>
<a href='https://github.com/PowerShellWeb/AtGitHub'>
$(Get-Content -Path ./Assets/GitHub.svg -Raw)
</a>
</div>
</div>
"@
  
"<div class='mainGrid'>"
$style, $corner, $header, $content -join [Environment]::NewLine
"</div>"
