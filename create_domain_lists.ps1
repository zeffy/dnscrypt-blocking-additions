(Get-Content -Raw '.\domain_lists.json' | ConvertFrom-Json) | % {
    $list = New-Object -TypeName System.Collections.Generic.HashSet[string]
    $defaultCommentToken = $_.defaults.comment_token
    $defaultHeaders = @{}
    foreach ( $header in $_.defaults.http_headers.PSObject.Properties ) {
        $defaultHeaders[$header.Name] = $header.Value
    }
    foreach ( $source in $_.sources ) {
        $comment_token = $_.defaults.comment_token
        if ( $source.comment_token ) {
            $comment_token = $source.comment_token
        }
        $headers = $defaultHeaders.Clone()
        foreach ( $header in $source.http_headers.PSObject.Properties ) {
            $headers[$header.Name] = $header.Value
        }
        $file = New-TemporaryFile
        try {
            $source.url
            $wr = Invoke-WebRequest -Uri $source.url -UseBasicParsing -Headers $headers -OutFile $file
            $content = Get-Content $file
            $unique = 0
            $duplicates = 0
            foreach ( $line in $content ) {
                $line = ($line -split $comment_token, 2)[0]
                if ( $source.regex ) {
                    if ( $line -match $source.regex ) {
                        if ( $list.Add($matches[1].Trim()) ) {
                            $unique++
                        } else {
                            $duplicates++
                        }
                    }
                } elseif ( $line ) {
                    if ( $list.Add($matches[1].Trim()) ) {
                        $unique++
                    } else {
                        $duplicates++
                    }
                }
             }
            "Unique entries: $unique, Duplicates: $duplicates"
        } finally {
            if ( $file ) {
                Remove-Item $file
            }
        }
    }
    $list > $_.filename
}
