if ($PSScriptRoot) { Push-Location $PSScriptRoot }
if ($psScriptRoot -and -not $site.AtGitHub) {
    . ($PSScriptRoot | Split-Path | Join-Path -ChildPath 'AtGitHub.DataSet.ps1')
}
$Title = "Issues"
$Description = "GitHub Issues mentioned in BlueSky"
$pattern = "/issues?/\d+"
"<style>"
"table {
    width: 80%;
    margin-left: auto;
    margin-right: auto;    
}
table th, table td {
    padding: 0.5em;
    text-align: center;
    border: 1px solid;
}    
"   
"</style>"
"<table>"
"<thead>
    <tr>
        <th>Text</th>
        <th>Locale</th>
        <th>Likes</th>
        <th>Reposts</th>
        <th>Date</th>
    </tr>
</thead>"
foreach ($row in $site.AtGitHub.Tables['app.bsky.feed.post'].Select('','LikeCount desc')) {
    if ($row.Uri -notmatch $pattern) {
        continue
    }
    "<tr>"
    "<td>"
    "<a href='$($row.message | at.web)'>$(
        @(foreach ($line in $row.message.commit.record.text -split "(?>\r\n|\n)") {
            [Web.HttpUtility]::HtmlEncode($line)
        }) -join '<br />'
    )</a>"
    "</td>"
    "<td>$($row.message.commit.record.langs -join '')</td>"    
    "<td>$($row.likeCount)</td>"
    "<td>$($row.repostCount)</td>"
    "<td>$($row.createdAt.ToShortDateString())</td>"
    "</tr>"
}
"</table>"
if ($PSScriptRoot) { Pop-Location }
