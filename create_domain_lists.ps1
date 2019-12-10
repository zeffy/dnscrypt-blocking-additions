function Rot13 {
    param([string]$str)

    $sb = [System.Text.StringBuilder]::new()
    foreach ( $c in $str.ToCharArray() ) {
        $i = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'.IndexOf($c)
        if ( $i -ge 0 ) {
            [void]$sb.Append('NOPQRSTUVWXYZABCDEFGHIJKLMnopqrstuvwxyzabcdefghijklm'[$i])
        } else {
            [void]$sb.Append($c)
        }
    }
    return $sb.ToString()
}

function IsPattern {
    param([string]$str)

    for ( $i = 0; $i -lt $str.Length; $i++ ) {
        if ( ($str[$i] -eq [char]'?') -or ($str[$i] -eq [char]'[') ) {
            return $true
        } elseif ( ($str[$i] -eq [char]'*') -and (($i -ne 0) -and ($str[$i + 1] -ne [char]'.')) ) {
            return $true
        }
    }
    return $false
}

$ProgressPreference = 'SilentlyContinue'

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
    $sb = [System.Text.StringBuilder]::new()
    $except = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $i = 0
    $step = [int]($list.Count * 0.01)
    Write-Host -NoNewLine "Optimizing list... 0%"
    foreach ( $entry in $list ) {
        for ( $j = 0; $j -lt $str.Length; $j++ ) {
            if ( ($str[$j] -eq [char]'?') -or ($str[$j] -eq [char]'[') ) {
                continue
            } elseif ( ($str[$j] -eq [char]'*') `
                    -and (($j -ne 0) -or ($str[$j + 1] -ne [char]'.')) ) {
                continue
            }
        }
        $parts = $entry -replace '^\=' -split '\.'
        [System.Array]::Reverse($parts)
        foreach ( $part in $parts | Select -SkipLast 1 ) {
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
            Start-Sleep -Milliseconds 100
            Write-Host -NoNewLine ("`rOptimizing list... {0:P0}" -f ($i / $list.Count))
        }
    }
    "`rOptimizing list... 100%"
    "{0:N0} used out of {1:N0}" -f ($list.Count - $except.Count), $list.Count
    $list.ExceptWith($except)
    Write-Host -NoNewLine "Saving list to $($_.filename)... "
    $list > $_.filename
    "Done!"
    ""
}
[System.GC]::Collect()
