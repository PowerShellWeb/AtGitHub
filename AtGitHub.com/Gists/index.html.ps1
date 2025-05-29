if ($PSScriptRoot) { Push-Location $PSScriptRoot }
if ($psScriptRoot -and -not $site.AtGitHub) {
    . ($PSScriptRoot | Split-Path | Join-Path -ChildPath 'AtGitHub.DataSet.ps1')
}
"<style>"
"table {
    width: 80%;
    margin-left: auto;
    margin-right: auto;
}"   
"</style>"
"<table>"
"<thead>
    <tr>
        <th>Text</th>
        <th>Likes</th>
        <th>Reposts</th>
        <th>Date</th>
    </tr>
</thead>"
foreach ($row in $site.AtGitHub.Tables['app.bsky.feed.post'].Select('LikeCount >= 0','LikeCount desc')) {
    if ($row.Uri.DnsSafeHost -ne 'gist.github.com') {
        continue
    }
    "<tr>"
    "<td>"
    "<a href='$($row.uri)'>$(
        foreach ($line in $row.message.commit.record.text -split "\r?\n") {            
            [Web.HttpUtility]::HtmlEncode($line)
        } -join '<br />'        
    )</a>"
    "</td>"
    "<td>$($row.likeCount)</td>"
    "<td>$($row.repostCount)</td>"
    "<td>$($row.createdAt.ToShortDateString())</td>"
    "</tr>"
}
"</table>"
if ($PSScriptRoot) { Pop-Location }
