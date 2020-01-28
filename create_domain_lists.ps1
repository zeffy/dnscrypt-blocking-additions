function Format-FileSize {
    param([long]$cb)

    if ( $cb ) {
        if ( $cb -ge 1PB ) { return '{0:#,0.##} PB' -f ($cb / 1PB) }
        if ( $cb -ge 1TB ) { return '{0:#,0.##} TB' -f ($cb / 1TB) }
        if ( $cb -ge 1GB ) { return '{0:#,0.##} GB' -f ($cb / 1GB) }
        if ( $cb -ge 1MB ) { return '{0:#,0.##} MB' -f ($cb / 1MB) }
        if ( $cb -ge 1KB ) { return '{0:#,0.##} KB' -f ($cb / 1KB) }
        return '{0:N0} bytes' -f $cb
    }
    return ''
}

function IsPatternCandidate {
    param([string]$str)

    for ( $j = 0; $j -lt $str.Length; $j++ ) {
        if ( ($str[$j] -eq [char]'?') `
                -or ($str[$j] -eq [char]'[') `
                -or ($str[$j] -eq [char]'*') ) {
            return $true
        }
    }
    return $false
}

function Using-Object {
    param (
        [Parameter(Mandatory = $true)]
        [System.IDisposable]$InputObject,

        [Parameter(Mandatory = $true)]
        [ScriptBlock]$ScriptBlock
    )

    try {
        & $ScriptBlock
    } finally {
        if ( $InputObject -ne $null ) {
            $InputObject.Dispose()
        }
    }
}
Set-Alias -Name using -Value Using-Object

$sb = [System.Text.StringBuilder]::new()
$list = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$except = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
using ( $wc = [System.Net.WebClient]::new() ) {
    (Get-Content -Raw '.\domain_lists.json' | ConvertFrom-Json) | % {
        $defaultCommentToken = $_.defaults.comment_token
        foreach ( $source in $_.sources ) {
            if ( $source.comment_token ) {
                $comment_token = $source.comment_token
            } else {
                $comment_token = $_.defaults.comment_token
            }
            if ( $source.file ) {
                $stream = [System.IO.FileStream]::new($source.file, [System.IO.FileMode]::Open)
                Write-Host -NoNewLine "Processing $($source.file)... "
                Format-FileSize $stream.Length
            } else {
                foreach ( $header in $_.defaults.http_headers.PSObject.Properties ) {
                    $wc.Headers[$header.Name] = $header.Value
                }
                foreach ( $header in $source.http_headers.PSObject.Properties ) {
                    $wc.Headers[$header.Name] = $header.Value
                }
                Write-Host -NoNewLine "Downloading $($source.url)... "
                $stream = $wc.OpenRead($source.url)
                Format-FileSize $wc.ResponseHeaders['Content-Length']
            }
            using ( $reader = [System.IO.StreamReader]::new($stream) ) {
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
            }
            $stream.Dispose()
            $stream = $null
        }
        ''
        $i = 0
        $step = [int]($list.Count * $(if ( $env:GITHUB_ACTIONS ) { 0.2 } else { 0.01 }))
        Write-Host -NoNewLine 'Optimizing list... 0%'
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        foreach ( $entry in $list ) {
            if ( IsPatternCandidate $entry ) {
                continue
            }
            foreach ( $part in [System.Linq.Enumerable]::Reverse( `
                    [System.Linq.Enumerable]::Skip(($entry -replace '^\=').Split([char]'.'), 1)) ) {
                if ( $sb.Length -gt 0 ) {
                    [void]$sb.Insert(0, [char]'.')
                }
                [void]$sb.Insert(0, $part)
                if ( $list.Contains($sb.ToString()) ) {
                    [void]$except.Add($entry)
                    break
                }
            }
            [void]$sb.Clear()
            $i++
            if ( ($i % $step) -eq 0 ) {
                Write-Host -NoNewLine ("`rOptimizing list... {0:P0}" -f ($i / $list.Count))
            }
        }
        "`rOptimizing list... Done! Took {0:#,0.##} seconds." -f $sw.Elapsed.TotalSeconds
        '{0:N0} used out of {1:N0}' -f ($list.Count - $except.Count), $list.Count
        $list.ExceptWith($except)
        $except.Clear()
        Write-Host -NoNewLine "Saving list to $($_.filename)... "
        $sw.Restart()
        [System.IO.File]::WriteAllLines($_.filename, $list)
        'Done! Took {0:#,0.##} seconds.' -f $sw.Elapsed.TotalSeconds
        ''
        $list.Clear()
        [System.GC]::Collect()
    }
}
