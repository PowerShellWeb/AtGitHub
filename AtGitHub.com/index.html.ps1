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
.grid9x9 {
  display: grid;
  height: 100vh;
  grid:
    "$( @('header') * 9)" minmax(100px, auto)
    "$( @('main') * 9)" minmax(100px, auto)
    "$( @('footer') * 9)" minmax(100px, auto)
    / $( @('1fr') * 9);
  align-content: center;
  grid-auto-rows: auto
}


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
    grid-area: navigation;
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
    $FirstPostTime = $site.AtData.Tables['app.bsky.feed.post'].Select('','createdAt ASC')[0].createdAt
    $Description = "AtGitHub | $($site.AtData.Tables['app.bsky.feed.post'].Rows.Count) posts | $($site.AtData.Tables['app.bsky.feed.like'].Rows.Count) likes | $($site.AtData.Tables['app.bsky.feed.repost'].Rows.Count) reposts since $($FirstPostTime.ToShortDateString())"
    "<h2>$($site.AtData.Tables['app.bsky.feed.post'].Rows.Count) posts</h2>"
    "<h3>$($site.AtData.Tables['app.bsky.feed.like'].Rows.Count) likes</h3>"
    "<h4>$($site.AtData.Tables['app.bsky.feed.repost'].Rows.Count) reposts</h4>"
    "<h5>Since $($FirstPostTime.ToShortDateString())</h5>"
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

   
"<div class='grid9x9'>"

$style,
    $corner,
        $header,
            $content -join [Environment]::NewLine

"</div>"
