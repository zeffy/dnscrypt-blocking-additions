function Rot13 {
    param([string]$s)

    $sb = [System.Text.StringBuilder]::new()

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
    $list = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
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
            if ( $source.skip_lines ) {
                $content = $content | Select-Object -Skip $source.skip_lines
            }
            $count = 0
            $total = 0
            foreach ( $line in $content ) {
                if ( $comment_token ) {
                    $line = ($line -split $comment_token, 2)[0]
                }
                $line = $line.Trim()
                $entry = $null
                if ( $source.regex ) {
                    if ( $line -match $source.regex ) {
                        $entry = $matches[1].Trim()
                    }
                } elseif ( $line ) {
                    $entry = $line
                }
                if ( $entry ) {
                    $total++
                    if ( $source.rot13 ) {
                        $entry = Rot13($entry)
                    }
                    if ( $source.not_like ) {
                        if ( $source.not_like `
                                | % { $entry -like $_ } `
                                | ? { $_ } `
                                | Select-Object -First 1 ) {
                            continue
                        }
                    }
                    $count += [int]$list.Add($entry)
                }
            }
            "{0:N0} used out of {1:N0}" -f $count, $total
        } finally {
            if ( $file ) {
                Remove-Item $file
            }
        }
    }
    ""
    "Optimizing list..."
    $sb = [System.Text.StringBuilder]::new()
    $rlist = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ( $item in $list ) {
        $parts = $item.Split('.')
        [System.Array]::Reverse($parts)
        foreach ( $part in $parts | Select -SkipLast 1 ) {
            [void]$sb.Insert(0, $part)
            if ( $list.Contains($sb.ToString()) ) {
                [void]$rlist.Add($item)
                break
            }
            [void]$sb.Insert(0, '.')
        }
        [void]$sb.Clear()
    }
    "{0:N0} used out of {1:N0}" -f ($list.Count - $rlist.Count), $list.Count
    $list.ExceptWith($rlist)
    "Saving list to $($_.filename)..."
    $list > $_.filename
    ""
}
[System.GC]::Collect()
