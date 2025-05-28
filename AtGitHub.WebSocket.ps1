#requires -Module WebSocket
param(
[uri]
$jetstreamUrl = "wss://jetstream$(1,2 | Get-Random).us-$('west','east' | Get-Random).bsky.network/subscribe",

[string[]]
$Collections = @('app.bsky.feed.post','app.bsky.feed.like','app.bsky.feed.repost'),

[string[]]
$Dids = @(),

[TimeSpan]
$Since = [TimeSpan]::FromHours(3),

[TimeSpan]
$TimeOut = [TimeSpan]::FromMinutes(25),

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

. ./AtGitHub.DataSet.ps1 -ZipPath $ZipPath
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
                        if (-not $likesTable.Rows.Find($atUri)) {
                            # Add the like to the likes table
                            $likesTable.Rows.Add($foundPost.uri, $message.commit.record.subject.uri, $atUri, $message.commit.record.createdAt)
                            if (-not "$($foundPost.LikeCount)") {
                                $foundPost.LikeCount = 0
                            }
                            $foundPost.LikeCount++
                            Write-Host "$($foundPost.uri) $atUri has been liked $($foundPost.LikeCount) times"
                        }
                    } catch {
                        Write-Verbose "Caught an Error adding a like (this could mean it was unrelated to a tracked post): $($_.Exception.Message) $($_.Exception | Out-String)"
                    }
                }
                'app.bsky.feed.repost' {
                    $foundPost =  $postsTable.Rows.Find($message.commit.record.subject.uri)
                    if (-not $foundPost) { continue }
                    try {
                        if (-not $repostTable.Rows.Find($atUri)) {
                            $repostTable.Rows.Add($foundPost.Uri, $message.commit.record.subject.uri, $atUri, $message.commit.record.createdAt)
                            if (-not "$($foundPost.RepostCount)") {
                                $foundPost.RepostCount = 0
                            }
                            $foundPost.RepostCount++
                            Write-Host "$($foundPost.Uri) $atUri has been reposted $($foundPost.RepostCount) times"
                        }                        
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
    # wantedCollections = $collections
    # cursor = ([DateTimeOffset]::Now - $since).ToUnixTimeMilliseconds()
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
$watchStart = [DateTime]::Now
$totalProcessed = [long]0
$timeframes = @()
do {
    $batchStart = [DateTime]::Now
    $batch =$Jetstream | Receive-Job -ErrorAction Ignore     
    $matchingItems = @($batch | 
        Where-Object $AtFilter)        

    if ($batch) {
        $timeframes += [DateTime]::Now - $batchStart
        Write-Host "Processed batch of $($batch.Length) in $($timeframes[-1]) - Last Post @ $($batch[-1].commit.record.createdAt)" -ForegroundColor Green
        if ($matchingItems) {            
            Write-Host "Filtered batch to $($matchingItems.Length) items" -ForegroundColor Green
            $matchingItems | saveFirehose
            $totalProcessed += $matchingItems.Length
        }
    }
    
    Start-Sleep -Milliseconds (Get-Random -Min .1kb -Max 1kb)
} while ($Jetstream.JobStateInfo.State -in 'NotStarted','Running') 


$batch =$Jetstream | Receive-Job -ErrorAction Ignore     
$matchingItems = @($batch | 
    Where-Object $AtFilter)        

if ($batch) {
    $timeframes += [DateTime]::Now - $batchStart
    Write-Host "Processed batch of $($batch.Length) in $($timeframes[-1]) - Last Post @ $($batch[-1].commit.record.createdAt)" -ForegroundColor Green
    if ($matchingItems) {            
        Write-Host "Filtered batch to $($matchingItems.Length) items" -ForegroundColor Green
        $matchingItems | saveFirehose
        $totalProcessed += $matchingItems.Length
    }
}

$totalTime = $watchStart - [DateTime]::Now
Write-Host "$totalProcessed items processed in $($totalTime) - Average time per item: $($totalProcessed / $totalTime.TotalSeconds) items/sec" -ForegroundColor Cyan
    
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

if ($PSScriptRoot) { Pop-Location }