function Rot13 {
    param([string]$s)

    $sb = New-Object -TypeName System.Text.StringBuilder

    foreach ( $c in $s.ToCharArray() ) {
        $i = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'.IndexOf($c)
        if ( $i -ge 0 ) {
            [void]$sb.Append('NOPQRSTUVWXYZABCDEFGHIJKLMnopqrstuvwxyzabcdefghijklm'[$i])
        } else {
            [void]$sb.Append($c)
        }
    }
    return $sb.ToString()
}

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
            "Downloading $($source.url)..."
            Invoke-WebRequest -Uri $source.url -UseBasicParsing -Headers $headers -OutFile $file | Out-Null
            $content = Get-Content $file
            $unique = 0
            $duplicates = 0
            foreach ( $line in $content ) {
                $line = ($line -split $comment_token, 2)[0]
                $entry = $null
                if ( $source.regex ) {
                    if ( $line -match $source.regex ) {
                        $entry = $matches[1].Trim()
                    }
                } elseif ( $line ) {
                    $entry = $line.Trim()
                }
                if ( $entry ) {
                    if ( $source.rot13 ) {
                        $entry = Rot13($entry)
                    }
                    if ( $list.Add($entry) ) {
                        $unique++
                    } else {
                        $duplicates++
                    }
                }
             }
            "Contains $unique unique entries, $duplicates duplicates"
        } finally {
            if ( $file ) {
                Remove-Item $file
            }
        }
    }
    "Saving list to $($_.filename)..."
    $list > $_.filename
    ""
}
