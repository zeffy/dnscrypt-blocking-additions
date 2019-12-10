$ProgressPreference = 'SilentlyContinue'
$sb = [System.Text.StringBuilder]::new()
$list = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$except = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

(Get-Content -Raw '.\domain_lists.json' | ConvertFrom-Json) | % {
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
            $count = 0
            $total = 0
            foreach ( $line in [System.Linq.Enumerable]::Skip([System.IO.File]::ReadAllLines($file), $source.skip_lines) ) {
                if ( $comment_token ) {
                    $line = ($line -split $comment_token, 2)[0]
                }
                $line = $line.Trim()
                if ( $source.regex ) {
                    if ( $line -match $source.regex ) {
                        $entry = $matches[1].Trim()
                    }
                } else {
                    $entry = $line.Trim()
                }
                if ( $entry ) {
                    if ( $source.rot13 ) {
                        foreach ( $c in $entry.ToCharArray() ) {
                            $i = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'.IndexOf($c)
                            if ( $i -ge 0 ) {
                                [void]$sb.Append('NOPQRSTUVWXYZABCDEFGHIJKLMnopqrstuvwxyzabcdefghijklm'[$i])
                            } else {
                                [void]$sb.Append($c)
                            }
                        }
                        $entry = $sb.ToString()
                        [void]$sb.Clear()
                    }
                    $count += [int]$list.Add($entry)
                    $total++
                }
            }
            '{0:N0} used out of {1:N0}' -f $count, $total
        } finally {
            if ( $file ) {
                Remove-Item $file
            }
        }
    }
    ''
    $i = 0
    $step = [int]($list.Count * 0.01)
    Write-Host -NoNewLine 'Optimizing list... 0%'
    foreach ( $entry in $list ) {
        for ( $j = 0; $j -lt $str.Length; $j++ ) {
            if ( ($str[$j] -eq [char]'?') -or ($str[$j] -eq [char]'[') ) {
                continue
            } elseif ( ($str[$j] -eq [char]'*') `
                    -and (($j -gt 0) -or ($str[$j + 1] -ne [char]'.')) ) {
                continue
            }
        }
        $parts = $entry -replace '^\=' -split '\.'
        foreach ( $part in [System.Linq.Enumerable]::Reverse([System.Linq.Enumerable]::Skip($parts, 1)) ) {
            [void]$sb.Insert(0, $part)
            if ( $list.Contains($sb.ToString()) ) {
                [void]$except.Add($entry)
                break
            }
            [void]$sb.Insert(0, '.')
        }
        [void]$sb.Clear()
        $i++
        if ( ($i % $step) -eq 0 ) {
            Write-Host -NoNewLine ("`rOptimizing list... {0:P0}" -f ($i / $list.Count))
        }
    }
    "`rOptimizing list... 100%"
    '{0:N0} used out of {1:N0}' -f ($list.Count - $except.Count), $list.Count
    $list.ExceptWith($except)
    $except.Clear()
    Write-Host -NoNewLine "Saving list to $($_.filename)... "
    [System.IO.File]::WriteAllLines($_.filename, $list)
    'Done!'
    ''
    $list.Clear()
}
[System.GC]::Collect()
