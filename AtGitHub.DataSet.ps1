param([string]$ZipPath = './AtGitHub.zip')

if ($PSScriptRoot) { Push-Location $PSScriptRoot }

$atGitHubData       = [Data.DataSet]::new('AtGitHub')
$atGitRepoTable     = $atGitHubData.Tables.Add('github.repository')
$atGitRepoLink      = $atGitHubData.Tables.Add('github.repository.link')
$postsTable         = $atGitHubData.Tables.Add('app.bsky.feed.post')
$likesTable         = $atGitHubData.Tables.Add('app.bsky.feed.like')
$repostTable        = $atGitHubData.Tables.Add('app.bsky.feed.repost')

$atGitRepoTable.Columns.AddRange(@(
    [Data.DataColumn]::new('owner', [string], '', 'Attribute')
    [Data.DataColumn]::new('repository', [string], '', 'Attribute')
))
$atGitRepoTable.PrimaryKey = $atGitRepoTable.Columns['owner','repository']

$atGitRepoLink.Columns.AddRange(@(
    [Data.DataColumn]::new('owner', [string], '', 'Hidden')
    [Data.DataColumn]::new('repository', [string], '', 'Hidden')
    [Data.DataColumn]::new('uri', [uri], '', 'Attribute')    
))

$atGitRepoLink.PrimaryKey = $atGitRepoLink.Columns['uri']
$atGitRepoMentions = $atGitHubData.Relations.Add('Mentions', $atGitRepoTable.Columns['owner','repository'], $atGitRepoLink.Columns['owner','repository'])
$atGitRepoMentions.Nested = $true
$atGitRepoMentions.ParentKeyConstraint[0].ConstraintName = 'atOwnerAndRepo'

$postsTable.Columns.AddRange(@(
    [Data.DataColumn]::new('uri', [uri], '', 'Hidden'),
    [Data.DataColumn]::new('atUri', [string], '', 'Attribute'),
    [Data.DataColumn]::new('createdAt', [DateTime], '', 'Attribute')
    [Data.DataColumn]::new('json', [string],'','Attribute')
    [Data.DataColumn]::new('likeCount', [uint32],'','Attribute')
    [Data.DataColumn]::new('repostCount', [uint32],'','Attribute')
    [Data.DataColumn]::new('message', [object],'','Hidden')    
))

$postsTable.PrimaryKey = $postsTable.Columns['atUri']

$postAboutSource = $atGitHubData.Relations.Add('Posts', $atGitRepoLink.Columns['uri'], $postsTable.Columns['uri'])
$postAboutSource.Nested = $true
$postAboutSource.ParentKeyConstraint[0].ConstraintName = 'atUri'

$likesTable.Columns.AddRange(@(
    [Data.DataColumn]::new('uri', [uri], '', 'Hidden')
    [Data.DataColumn]::new('subjectAtUri', [string], '', 'Hidden'),    
    [Data.DataColumn]::new('atUri', [string], '', 'Attribute')
    [Data.DataColumn]::new('createdAt', [DateTime], '', 'Attribute')
))
$likesTable.PrimaryKey = $likesTable.Columns['atUri']

$likesAPost = $atGitHubData.Relations.Add('Likes', $postsTable.Columns['uri','atUri'], $likesTable.Columns['uri','subjectAtUri'])
$likesAPost.Nested = $true
$likesAPost.ParentKeyConstraint[0].ConstraintName = 'atUri'

$repostTable.Columns.AddRange(@(
    [Data.DataColumn]::new('uri', [uri], '', 'Hidden')
    [Data.DataColumn]::new('subjectAtUri', [string], '', 'Hidden'),
    [Data.DataColumn]::new('atUri', [string], '', 'Attribute')
    [Data.DataColumn]::new('createdAt', [DateTime], '', 'Attribute')
))
$repostTable.PrimaryKey = $repostTable.Columns['atUri']

$repostsAPost = $atGitHubData.Relations.Add('Reposts', $postsTable.Columns['uri','atUri'], $repostTable.Columns['uri','subjectAtUri'])
$repostsAPost.Nested = $true
$repostsAPost.ParentKeyConstraint[0].ConstraintName = 'atUri'

# If the file exists, load the existing data
if (Test-Path -Path $ZipPath) {
    $atPackage =
        [IO.Packaging.Package]::Open(
            "$(Resolve-Path -Path $ZipPath)",
            'Open',
            'Read'
        )

    if ($atPackage.PartExists("/AtGitHub.xml")) {
        $existingDataPart = $atPackage.GetPart("/AtGitHub.xml")
        $readStream = $existingDataPart.GetStream()
        $null =$atGitHubData.ReadXml($readStream)
        $readStream.Close()

        foreach ($post in $atGitHubData.Tables['app.bsky.feed.post']) {
            if (-not "$($post.message)") {
                $post.message = ConvertFrom-Json -InputObject $post.json
            }
            if ($post.LikeCount -eq [DBNull]::Value) {
                $post.LikeCount = $likesTable.Select("subjectAtUri = '$($post.AtUri)'").Count
            }
            if ($post.RepostCount -eq [DBNull]::Value) {
                $post.RepostCount = $likesTable.Select("subjectAtUri = '$($post.AtUri)'").Count
            }
        }
    }
    $atPackage.Close()
}

if ($PSScriptRoot) { Pop-Location }