param(
    [Parameter(Mandatory=$true)][string]$HtmlFile,
    [Parameter(Mandatory=$true)][string]$OutFile
)
# Parses LinkedIn new-UI job cards from a saved <main> HTML dump.
# Card anchor: componentkey="job-card-component-ref-<ID>"
# Extracts: ID, Title, Company, PostedTime text.
$c = Get-Content $HtmlFile -Raw
$ids = [regex]::Matches($c, 'job-card-component-ref-(\d+)') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
$rows = foreach ($id in $ids) {
    $idx = $c.LastIndexOf("job-card-component-ref-$id")
    if ($idx -lt 0) { continue }
    $start = $idx + "job-card-component-ref-$id".Length
    $next = $c.IndexOf('job-card-component-ref-', $start)
    if ($next -lt 0) { $next = [Math]::Min($start + 8000, $c.Length) }
    $len = [Math]::Min($next - $start, 8000)
    if ($len -le 0) { continue }
    $chunk = $c.Substring($start, $len)
    $gt = $chunk.IndexOf('>')
    if ($gt -ge 0) { $chunk = $chunk.Substring($gt + 1) }
    $txt = ($chunk -replace '<[^>]+>', "`n") -replace '&amp;', '&' -replace '&#39;', "'" -replace '&nbsp;', ' '
    $segs = ($txt -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    $title = ''
    $company = ''
    for ($i = 0; $i -lt $segs.Count; $i++) {
        $s = $segs[$i]
        if ($s -eq '(Verified job)' -or $s -match '^(Viewed|Be an early|Actively reviewing|Posted|just now|\d+ (minute|hour|day|week|month))') { continue }
        if ($title -eq '') { $title = $s; continue }
        $tb = $title -replace ' \(Verified job\)$', ''
        if ($s -eq $title -or $s -eq $tb -or $s -eq "$tb (Verified job)") { continue }
        $company = $s
        break
    }
    $title = $title -replace ' \(Verified job\)$', ''
    $timeMatch = [regex]::Matches(($segs -join ' | '), '(just now|\d+\s+(?:minute|hour|day|week|month)s?\s+ago)')
    $time = if ($timeMatch.Count -gt 0) { $timeMatch[$timeMatch.Count - 1].Value } else { '' }
    [pscustomobject]@{ Id = $id; Title = $title; Company = $company; Time = $time }
}
$rows | Export-Csv -Path $OutFile -NoTypeInformation -Encoding UTF8
$rows | Format-Table -AutoSize -Wrap | Out-String -Width 220