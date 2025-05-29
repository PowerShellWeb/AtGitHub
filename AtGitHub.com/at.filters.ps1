function at.listRecords {
    [CmdletBinding(SupportsPaging)]
    [Alias('at.records')]
    param(
        # The decentralized identifier (DID) of the user.
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]
        $did = "did:plc:hlchta7bwmobyum375ltycg5",
        
        # The collection of records to retrieve.
        # This can be any object
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('$type')]
        [string]
        $Collection = "app.bsky.feed.post",
        
        # The cursor.
        # This should be empty.
        # A cursor can be provided to start from a specific point in the list.
        # Each response will include a cursor to the next page of results.
        # Once the cursor is empty, there are no more results.        
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]
        $Cursor,
    
        # The number of records to return.
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Limit')]
        [int]
        $BatchSize = 100
    )

    process {
        $total = [long]0
        $skipped = [long]0
        :AtSync do {
            $xrpcUrl = "https://bsky.social/xrpc/com.atproto.repo.listRecords?repo=$did&collection=$collection&cursor=$Cursor&limit=$BatchSize"
            $results = Invoke-RestMethod $xrpcUrl
            if ($results -and $results.cursor) {
                $Cursor = $results.cursor
            }
            foreach ($record in $results.records) {
                if ($PSCmdlet.PagingParameters.Skip -and 
                    $skipped -lt $PSCmdlet.PagingParameters.Skip
                ) {
                    $skipped++
                    continue
                }                                        
                
                $record.pstypenames.insert(0, $collection)
                $record
                $total++
                
                if ($PSCmdlet.PagingParameters.First -and 
                    $total -ge $PSCmdlet.PagingParameters.First) {
                    break AtSync
                }
            }    
        } while ($results -and $results.cursor)
    }    
}

filter at.web {
    param(
        [string]$pdc="bsky.app"
    )
    $data = $_
    $recordType = $data.commit.record.'$type'
    switch ($recordType) {
        'app.bsky.feed.post' {
            "https://$($pdc)/profile/$($data.did)/$(@($recordType -split '\.')[-1])/$($data.commit.rkey)"
        }
        default {
            "https://bsky.social/xrpc/com.atproto.repo.getRecord?repo=$did&collection=$collection&rkey=$($data.commit.rkey)"
        }
    }
}

