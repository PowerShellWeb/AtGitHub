#requires -Module WebSocket
param(
[uri]
$jetstreamUrl = "wss://jetstream$(1,2 | Get-Random).us-$('west','east' | Get-Random).bsky.network/subscribe",

[string[]]
$Collections = @('app.bsky.feed.post','app.bsky.feed.like','app.bsky.feed.repost'),

[string[]]
$Dids = @(),

[TimeSpan]
$Since = [TimeSpan]::FromDays(.5),

[TimeSpan]
$TimeOut = [TimeSpan]::FromMinutes(15),

[ScriptBlock]
$AtFilter = {
    $message = $_
    $messageLink = $message.commit.record.embed.external.uri -as [uri]
    $message.commit.record.'$type' -in 'app.bsky.feed.like','app.bsky.feed.repost' -or
    $messageLink.DnsSafeHost -in 'github.com','gist.github.com'
},

[string]
$Root = "./",

[string]
$ZipPath = "./AtGitHub.zip"
)

if ($PSScriptRoot) { Push-Location $PSScriptRoot}


$atGitHubData = [Data.DataSet]::new('AtGitHub')
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

$firehose = Get-ChildItem -Recurse -File -Filter *.json |
    ForEach-Object { 
        $json = Get-Content -Path $_.FullName -Raw -ErrorAction Ignore
        $message = ConvertFrom-Json -InputObject $json
        if (-not $jsonObject.commit.record.'$type') {
            return
        }
        $messageLink = $message.commit.record.embed.external.uri -as [uri]
        $message
    }

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

function saveFirehose {
        $firehoses = @($input)
        $c = 0
        $t = $firehoses.Length
        $progressId = Get-Random
    
    foreach ($message in $firehoses) {
        $c++
        if (-not ($c % 10)) {
            $p = $c / $t * 100
            Write-Progress -Id $progressId -Activity "$($message.did)" -Status "Processing $($message.commit.record.'$type')" -PercentComplete $p 
        }    
        
        $atUri = "at://$($message.did)/$($message.commit.record.'$type')/$($message.commit.rkey)"
        $newRow = 
            switch ($message.commit.record.'$type') {
                'app.bsky.feed.post' {
                    
                    $messageLink = $message.commit.record.embed.external.uri -as [uri]
                    if (-not $messageLink) {                    
                        continue
                    }
                    
                    $owner, $repo = $messageLink.Segments[1..2] -replace '^/' -replace '/$'
    
                    if (-not $owner -or -not $repo) {
                        Write-Host "Skipping post with no owner or repo: $($messageLink)" -ForegroundColor Yellow
                        continue
                    }
    
                    if (-not $atGitRepoTable.Rows.Find(@($owner, $repo))) {
                        $null = $atGitRepoTable.Rows.Add($owner, $repo)
                    }
    
                    if (-not $atGitRepoLink.Rows.Find($messageLink)) {
                        $null = $atGitRepoLink.Rows.Add($owner, $repo, $messageLink)
                    }

                    if ($postsTable.Rows.Find($atUri)) {                        
                        Write-Host "$($owner)/$repo $atUri already exists"
                    } else {
                        $postsTable.Rows.Add($messageLink, $atUri, $message.commit.record.createdAt, ($message | ConvertTo-Json -Depth 10))
                        Write-Host "$($owner)/$repo $($messageLink) $atUri "
                    }
                    
                    

                }
                'app.bsky.feed.like' {
                    $foundPost =  $postsTable.Rows.Find($message.commit.record.subject.uri)
                    if (-not $foundPost) {
                        continue
                    }
                    try {
                        $likesTable.Rows.Add($foundPost.uri, $message.commit.record.subject.uri, $atUri, $message.commit.record.createdAt)                        
                        $foundPost.LikeCount++
                        Write-Host "$($foundPost.uri) $atUri has been liked $($foundPost.LikeCount) times"
                    } catch {
                        Write-Verbose "Caught an Error adding a like (this could mean it was unrelated to a tracked post): $($_.Exception.Message) $($_.Exception | Out-String)"
                    }
                }
                'app.bsky.feed.repost' {
                    $foundPost =  $postsTable.Rows.Find($message.commit.record.subject.uri)
                    if (-not $foundPost) { continue }
                    try {
                        $repostTable.Rows.Add($foundPost.Uri, $message.commit.record.subject.uri, $atUri, $message.commit.record.createdAt)
                        $foundPost.RepostCount++
                        Write-Host "$($foundPost.Uri) $atUri has been reposted $($foundPost.RepostCount) times"
                    }
                    catch {
                        Write-Verbose "Caught an Error adding a like (this could mean it was unrelated to a tracked post): $($_.Exception.Message) $($_.Exception | Out-String)"
                    }
                }
            }
    
        if ($newRow.Uri) {
            # Write-Host "$($newRow.Uri) $atUri"
        }
        elseif ($newRow.AtUri -and $newRow.SubjectAtUri) {
            Write-Host "$($newRow.Table.TableName) $($newRow.SubjectAtUri) $atUri"
        }        
    }
    
    Write-Progress -Id $progressId -Activity "$($message.did) " -Status "Processing $($message.commit.record.'$type')" -Completed
    
}
    
$jetstreamUrl = @(
    "$jetstreamUrl"
    '?'
    @(
        foreach ($collection in $Collections) {            
            "wantedCollections=$([Uri]::EscapeDataString($collection))"            
        }
        foreach ($did in $Dids) {
            "wantedDids=$([Uri]::EscapeDataString($did))"
        }
        "cursor=$([DateTimeOffset]::Now.Add(-$Since).ToUnixTimeMilliseconds())" 
    ) -join '&'
) -join ''

$Jetstream = WebSocket -SocketUrl $jetstreamUrl -Query @{
    wantedCollections = $collections
    cursor = ([DateTimeOffset]::Now - $since).ToUnixTimeMilliseconds()
} -TimeOut $TimeOut

filter toAtUri {
    $in = $_
    $did = $in.did
    $rkey = $in.commit.rkey
    $recordType = $in.commit.record.'$type'
    "at://$did/$recordType/$rkey"
}

Write-Host "Listening To Jetstream: $jetstreamUrl" -ForegroundColor Cyan
Write-Host "Starting loop @ $([DateTime]::Now)" -ForegroundColor Cyan
$batchStart = [DateTime]::Now
$filesFound = @()
do {
    $batch =$Jetstream | Receive-Job -ErrorAction Ignore     
    $matchingItems = @($batch | 
        Where-Object $AtFilter)
        
    

    if ($batch) {
        Write-Host "Processed batch of $($batch.Length) in $([DateTime]::Now - $batchStart) - Last Post @ $($batch[-1].commit.record.createdAt)" -ForegroundColor Green
        if ($matchingItems) {            
            Write-Host "Found $($matchingItems.Length) matches" -ForegroundColor Green
            $matchingItems | saveFirehose            
        }
    }
    
    Start-Sleep -Milliseconds (Get-Random -Min .1kb -Max 1kb)
} while ($Jetstream.JobStateInfo.State -in 'NotStarted','Running') 

$Jetstream | 
    Receive-Job | 
    Where-Object $AtFilter |
    saveFirehose
    
$atPackage =
    [IO.Packaging.Package]::Open(
        "$(Resolve-Path -Path $ZipPath)",
        'OpenOrCreate',
        'ReadWrite'
    )

$atSchemaPart = 
    if (-not $atPackage.PartExists("/$($atGitHubData.DataSetName).xsd")) {
        $atPackage.CreatePart("/$($atGitHubData.DataSetName).xsd", "application/xml", 'Maximum')    
    } else {
        $atPackage.GetPart("/$($atGitHubData.DataSetName).xsd")
    }

$partStream = $atSchemaPart.GetStream()
$atGitHubData.WriteXmlSchema($partStream)
$partStream.Close()
$partStream.Dispose()

$atPart =        
    if (-not $atPackage.PartExists("/$($atGitHubData.DataSetName).xml")) {
        $atPackage.CreatePart("/$($atGitHubData.DataSetName).xml", "application/xml", 'Maximum')
    } else {
        $atPackage.GetPart("/$($atGitHubData.DataSetName).xml")
    }
$partStream = $atPart.GetStream()
$atGitHubData.WriteXml($partStream)
$partStream.Close()
$partStream.Dispose()
$atPackage.Close()

Get-Item $ZipPath | 
    Add-Member NoteProperty CommitMessage "Syncing From At Protocol [skip ci]" -Force -PassThru

if ($PSScriptRoot) { Pop-Location}