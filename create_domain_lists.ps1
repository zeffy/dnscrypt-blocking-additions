function IsPatternCandidate {
    param([string]$str)

    for ( $j = 0; $j -lt $str.Length; $j++ ) {
        if ( ($str[$j] -eq [char]'?') `
                -or ($str[$j] -eq [char]'[') ) {
            return $true
        } elseif ( $str[$j] -eq [char]'*' ) {
            return $true
        }
    }
    return $false
}

function Using-Object
{
    param (
        [Parameter(Mandatory = $true)]
        [System.IDisposable]$InputObject,

        [Parameter(Mandatory = $true)]
        [ScriptBlock]$ScriptBlock
    )

    try {
        & $ScriptBlock
    } finally {
        if ($InputObject -ne $null) {
            $InputObject.Dispose()
        }
    }
}

$sb = [System.Text.StringBuilder]::new()
$list = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$except = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
Using-Object ( $wc = [System.Net.WebClient]::new() ) {
    (Get-Content -Raw '.\domain_lists.json' | ConvertFrom-Json) | % {
        $defaultCommentToken = $_.defaults.comment_token
        foreach ( $source in $_.sources ) {
            if ( $source.comment_token ) {
                $comment_token = $source.comment_token
            } else {
                $comment_token = $_.defaults.comment_token
            }
            foreach ( $header in $_.defaults.http_headers.PSObject.Properties ) {
                $wc.Headers[$header.Name] = $header.Value
            }
            foreach ( $header in $source.http_headers.PSObject.Properties ) {
                $wc.Headers[$header.Name] = $header.Value
            }
            "Downloading $($source.url)..."
            Using-Object ( $stream = $wc.OpenRead($source.url) ) {
            Using-Object ( $reader = [System.IO.StreamReader]::new($stream) ) {
                $count = 0
                $total = 0
                for ( $i = 0; $i -lt $source.skip_lines; $i++ ) {
                    [void]$reader.ReadLine()
                }
                while ( ($line = $reader.ReadLine()) -ne $null ) {
                    if ( $comment_token ) {
                        $line = ($line -split $comment_token, 2)[0]
                    }
                    $line = $line.Trim()
                    if ( $source.regex ) {
                        if ( $line -imatch $source.regex ) {
                            $entry = $matches[1].Trim()
                        }
                    } else {
                        $entry = $line.Trim()
                    }
                    if ( $entry ) {
                        if ( $source.rot13 ) {
                            foreach ( $c in $entry.ToCharArray() ) {
                                $i = 'abcdefghijklmnopqrstuvwxyz'.IndexOf($c, [System.StringComparison]::OrdinalIgnoreCase)
                                if ( $i -ge 0 ) {
                                    [void]$sb.Append('nopqrstuvwxyzabcdefghijklm'[$i])
                                } else {
                                    [void]$sb.Append($c)
                                }
                            }
                            $entry = $sb.ToString()
                            [void]$sb.Clear()
                        }
                        if ( ([System.Uri]::CheckHostName($entry -replace '^(?:\*\.|\=)') -eq $_.kind) `
                            -or (IsPatternCandidate $entry) ) {
                            $count += [int]$list.Add($entry)
                            $total++
                        } else {
                            "Invalid host name: $entry"
                        }
                    }
                }
                '{0:N0} used out of {1:N0}' -f $count, $total
            }}
        }
        ''
        $i = 0
        $step = [int]($list.Count * 0.01)
        Write-Host -NoNewLine 'Optimizing list... 0%'
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        foreach ( $entry in $list ) {
            if ( IsPatternCandidate($entry) ) {
                continue
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
        "`rOptimizing list... Done! Took {0:N2} seconds." -f $sw.Elapsed.TotalSeconds
        '{0:N0} used out of {1:N0}' -f ($list.Count - $except.Count), $list.Count
        $list.ExceptWith($except)
        $except.Clear()
        Write-Host -NoNewLine "Saving list to $($_.filename)... "
        $sw.Restart()
        [System.IO.File]::WriteAllLines($_.filename, $list)
        'Done! Took {0:N2} seconds.' -f $sw.Elapsed.TotalSeconds
        ''
        $list.Clear()
    }
}
[System.GC]::Collect()
