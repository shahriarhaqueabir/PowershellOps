function Resolve-HawkDuckDuckGoHref {
    <#
    .SYNOPSIS
    Extracts the real URL from a DuckDuckGo redirect href.
    .DESCRIPTION
    DDG Lite search results use /l/?uddg=<encoded-url> redirect links.
    This function extracts the actual destination URL from those hrefs,
    and passes through direct https:// URLs unchanged.
    .PARAMETER Href
    The href attribute value from a DDG Lite search result link.
    #>
    [CmdletBinding()]
    param([string]$Href)

    if (-not $Href) { return $null }
    if ($Href -match 'uddg=([^&]+)') { return [Uri]::UnescapeDataString($matches[1]) }
    if ($Href -match '^//') { return "https:$Href" }
    if ($Href -match '^https?://') { return $Href }
    return $null
}

function Test-HawkSafeFetchUrl {
    <#
    .SYNOPSIS
    Validates a URL is safe for automated fetching.
    .DESCRIPTION
    SSRF guard for AI-driven web search. Rejects non-http(s) schemes,
    unresolvable hosts, loopback, private (RFC1918), link-local, and
    IPv6 unique-local addresses so fetched pages can never target the
    local machine or LAN services.
    .PARAMETER Url
    Candidate absolute URL.
    #>
    [CmdletBinding()]
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) { return $false }

    $uri = $null
    if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri)) { return $false }
    if ($uri.Scheme -notin @('http', 'https')) { return $false }
    if (-not $uri.Host) { return $false }

    try {
        $addrs = [System.Net.Dns]::GetHostAddresses($uri.Host)
    }
    catch { return $false }
    if (-not $addrs) { return $false }

    foreach ($a in $addrs) {
        if ([System.Net.IPAddress]::IsLoopback($a)) { return $false }
        if ($a.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) {
            $b = $a.GetAddressBytes()
            if ($b[0] -eq 10) { return $false }                                                    # 10/8 private
            if ($b[0] -eq 172 -and $b[1] -ge 16 -and $b[1] -le 31) { return $false }               # 172.16/12 private
            if ($b[0] -eq 192 -and $b[1] -eq 168) { return $false }                                # 192.168/16 private
            if ($b[0] -eq 169 -and $b[1] -eq 254) { return $false }                                # 169.254/16 link-local
            if ($b[0] -eq 127) { return $false }                                                   # loopback belt+braces
        }
        elseif ($a.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6) {
            if ($a.IsIPv6LinkLocal) { return $false }                                              # fe80::/10
            $b = $a.GetAddressBytes()
            if (($b[0] -band 0xFE) -eq 0xFC) { return $false }                                     # fc00::/7 unique-local
        }
    }
    return $true
}

function Invoke-HawkWebRequestRetry {
    <#
    .SYNOPSIS
    Invoke-WebRequest with bounded retries.
    .DESCRIPTION
    Wraps Invoke-WebRequest with up to $MaxAttempts attempts and exponential
    backoff (500ms then 1500ms) so transient 429/5xx/network blips don't
    silently degrade search results.
    .PARAMETER RequestArgs
    Hashtable splatted directly onto Invoke-WebRequest.
    .PARAMETER MaxAttempts
    Total attempts allowed. Default 2.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$RequestArgs,
        [int]$MaxAttempts = 2
    )

    $backoffMs = @(0, 500, 1500)
    $lastError = $null

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            return Invoke-WebRequest @RequestArgs -ErrorAction Stop
        }
        catch {
            $lastError = $_
            if ($attempt -lt $MaxAttempts) {
                Start-Sleep -Milliseconds $backoffMs[[math]::Min($attempt, $backoffMs.Count - 1)]
            }
        }
    }
    throw $lastError
}

function Invoke-HawkSearch {
    <#
    .SYNOPSIS
    Searches the web using Google, DuckDuckGo, GitHub, Stack Overflow, or Bing.
    .DESCRIPTION
    Queries the specified search engine and returns results. Use -AI to pipe
    results through the local LLM for synthesis. -Deep fetches full page content
    for deeper analysis. Alias: ggl (Google default).
    .PARAMETER Query
    Search terms. Accepts multiple words as remaining arguments.
    .PARAMETER Engine
    Search backend: google, ddg, gh, so, bing. Default: google.
    .PARAMETER AI
    Pipe results through the local LLM for synthesis.
    .PARAMETER Deep
    Fetch full page content for deeper analysis (slower).
    .PARAMETER News
    Pull real news articles via Google News RSS instead of general web results.
    Feeds headline metadata (title, source, date) plus article bodies to the AI.
    .PARAMETER Sources
    Number of source URLs to fetch for AI synthesis (1-30). 0 = auto.
    .PARAMETER Instruction
    Instruction prompt for the AI synthesis step.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments = $true)]
        [string[]]$Query,
        [ValidateSet('google', 'ddg', 'gh', 'so', 'bing')]
        [Alias('e')]
        [string]$Engine = 'google',
        [Alias('a')]
        [switch]$AI,
        [switch]$Deep,
        [switch]$News,
        [ValidateRange(1, 30)]
        [int]$Sources = 0,
        [string]$Instruction = 'Synthesize a concise report answering the query based on the following website contents. Extract key facts and insights.'
    )

    $skipNext = $false
    $cleanQuery = foreach ($token in $Query) {
        if ($skipNext) {
            $skipNext = $false
            continue
        }

        if ($token -in @('-AI', '-a', '-Deep', '-News')) { continue }
        if ($token -in @('-Engine', '-e', '-Sources')) {
            $skipNext = $true
            continue
        }
        $token
    }

    $joinedQuery = ($cleanQuery -join ' ').Trim()
    if (-not $joinedQuery) {
        throw 'Search query cannot be empty.'
    }

    $encoded = [Uri]::EscapeDataString($joinedQuery)
    $browserUrls = @{
        google = "https://www.google.com/search?q=$encoded"
        ddg    = "https://duckduckgo.com/?q=$encoded"
        gh     = "https://github.com/search?q=$encoded&type=repositories"
        so     = "https://stackoverflow.com/search?q=$encoded"
        bing   = "https://www.bing.com/search?q=$encoded"
    }

    if (-not $AI) {
        Write-Host "  [Search] Opened [$Engine] -> $joinedQuery" -ForegroundColor Cyan
        Start-Process $browserUrls[$Engine]
        return
    }

    Write-Host "  [Search] Fetching top links for: $joinedQuery" -ForegroundColor Cyan
    $hawkSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    try {
        $context = "Search Query: $joinedQuery`n`n"
        $urls = @()

        if ($News) {
            Write-Host '  [News] Pulling Google News RSS feed...' -ForegroundColor Cyan
            $feedUrl = "https://news.google.com/rss/search?q=$encoded&hl=en-US&gl=US&ceid=US:en"
            try {
                $feedResp = Invoke-HawkWebRequestRetry -RequestArgs @{
                    Uri             = $feedUrl
                    Headers         = @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' }
                    UseBasicParsing = $true
                    TimeoutSec      = 12
                    WebSession      = $hawkSession
                }
                $feed = [xml]$feedResp.Content
                $items = @($feed.rss.channel.item | Select-Object -First 30)
                if (-not $items) {
                    Write-Warning 'No news items found in the RSS feed. Falling back to web search.'
                }
                else {
                    $context += "NEWS HEADLINES (Google News RSS):`n"
                    $idx = 0
                    foreach ($it in $items) {
                        $idx++
                        $srcName = if ($it.source) { [string]$it.source.'#cdata-section' ?? [string]$it.source } else { 'Unknown' }
                        $when = if (($it.pubDate -as [datetime])) { ([datetime]$it.pubDate).ToString('yyyy-MM-dd HH:mm') } else { '' }
                        $context += "$idx. [$srcName] $($it.title)  ($when)`n"
                    }
                    $context += "`n"
                    $urls = @($items | ForEach-Object { [string]$_.link } | Where-Object { $_ })
                }
            }
            catch {
                Write-Warning "News RSS fetch failed ($($_.Exception.Message)). Falling back to web search."
            }
        }

        if (-not $urls) {
            $response = Invoke-HawkWebRequestRetry -RequestArgs @{
                Uri             = 'https://lite.duckduckgo.com/lite/'
                Method          = 'Post'
                Body            = @{ q = $joinedQuery }
                UseBasicParsing = $true
                WebSession      = $hawkSession
            }

            $urls = $response.Links |
            Where-Object { ($_.outerHTML -match "class='result-link'" -or $_.class -eq 'result-link') } |
            ForEach-Object { Resolve-HawkDuckDuckGoHref -Href $_.href } |
            Where-Object { $_ -and $_ -notmatch '^https?://(?:www\.)?duckduckgo\.com' } |
            Select-Object -Unique |
            Select-Object -First 30

            if (-not $urls) {
                Write-Warning 'Could not find any URLs. Opening browser instead.'
                Start-Process $browserUrls[$Engine]
                return
            }
        }

        $readCount = 0
        $fetchAttempted = 0
        $targetReadCount = if ($Sources -gt 0) { $Sources } elseif ($Deep) { 10 } else { 4 }
        $pageTimeoutSec = if ($Deep) { 12 } else { 8 }
        $maxPageChars = if ($Deep) { 4500 } else { 2400 }
        $maxPageBytes = 8388608   # 8MB absolute safety guard; oversized pages are text-truncated later, not discarded

        foreach ($url in $urls) {
            if ($readCount -ge $targetReadCount) { break }

            if (-not (Test-HawkSafeFetchUrl $url)) {
                Write-Host "  [Blocked] Unsafe or non-public target: $url" -ForegroundColor DarkYellow
                continue
            }

            if ($fetchAttempted -gt 0) {
                Start-Sleep -Milliseconds (Get-Random -Minimum 300 -Maximum 800)
            }
            $fetchAttempted++

            Write-Host "  [Read] $url" -ForegroundColor DarkGray
            try {
                $page = Invoke-HawkWebRequestRetry -RequestArgs @{
                    Uri             = $url
                    Headers         = @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' }
                    UseBasicParsing = $true
                    TimeoutSec      = $pageTimeoutSec
                    WebSession      = $hawkSession
                }

                $finalUri = $null
                if ($page.BaseResponse -and $page.BaseResponse.RequestMessage) {
                    $finalUri = [string]$page.BaseResponse.RequestMessage.RequestUri
                }
                elseif ($page.BaseResponse -and $page.BaseResponse.ResponseUri) {
                    $finalUri = [string]$page.BaseResponse.ResponseUri
                }
                if ($finalUri -and -not (Test-HawkSafeFetchUrl $finalUri)) {
                    throw "Redirected to a blocked address: $finalUri"
                }

                $declaredBytes = 0
                if (-not [int]::TryParse([string]$page.RawContentLength, [ref]$declaredBytes) -or $declaredBytes -eq 0) {
                    [void][int]::TryParse(([string]($page.Headers['Content-Length'] -join '')), [ref]$declaredBytes)
                }
                if ($declaredBytes -gt $maxPageBytes) {
                    throw "Page too large ($declaredBytes bytes, exceeds $([Math]::Round($maxPageBytes / 1MB))MB safety guard)."
                }

                $contentType = [string]($page.Headers['Content-Type'] -join ';')
                if ($contentType -and $contentType -notmatch 'text/(?:html|plain)') {
                    throw "Non-text content type: $contentType"
                }

                $cleanText = [System.Net.WebUtility]::HtmlDecode(($page.Content -replace '(?s)<style[^>]*>.*?</style>', '' -replace '(?s)<script[^>]*>.*?</script>', '' -replace '<[^>]+>', ' ').Trim())
                $cleanText = $cleanText -replace '\s+', ' '
                if ([string]::IsNullOrWhiteSpace($cleanText)) {
                    throw 'No readable text extracted from the page.'
                }

                $alphaRatio = (($cleanText.ToCharArray() | Where-Object { [char]::IsLetterOrDigit($_) }).Count) / [Math]::Max(1, $cleanText.Length)
                if ($alphaRatio -lt 0.10) {
                    throw ('Content failed sanity sniff ({0:P0} alphanumeric).' -f $alphaRatio)
                }

                # Hawk quality gate (v12.0): reject injection attempts and low-signal pages.
                if (Test-HawkPromptInjection -Text $cleanText) {
                    throw 'Prompt-injection pattern detected; page excluded from synthesis.'
                }
                $opsQuality = Get-HawkSourceQualityScore -Content $cleanText -Uri $url
                if ($opsQuality.Score -lt 50) {
                    throw ('Low source quality score ({0}/100); page excluded.' -f $opsQuality.Score)
                }

                if ($cleanText.Length -gt $maxPageChars) { $cleanText = $cleanText.Substring(0, $maxPageChars) }
                $context += "Source: $url`nContent: $cleanText`n`n"
                $readCount++
            }
            catch {
                $reason = $_.Exception.Message
                $statusCode = $null
                if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                    $statusCode = [int]$_.Exception.Response.StatusCode
                }

                $detail = if ($statusCode) { "HTTP $statusCode - $reason" } else { $reason }
                Write-Host "  [Warning] Failed to read $url ($detail)" -ForegroundColor DarkYellow
            }
        }

        if ($readCount -eq 0) {
            Write-Warning 'Could not read any result pages. Opening browser instead.'
            Start-Process $browserUrls[$Engine]
            return
        }

        if ($readCount -lt $targetReadCount) {
            Write-Host "  [Warning] Read $readCount of $targetReadCount target sources; candidate list exhausted." -ForegroundColor DarkYellow
        }

        Write-Host '  [AI] Analyzing results...' -ForegroundColor Magenta
        try {
            $null = $context | Invoke-HawkAI -Instruction $Instruction
        }
        catch {
            Write-Warning "AI analysis failed: $($_.Exception.Message)"
        }
    }
    catch {
        Write-Warning "Search request failed: $($_.Exception.Message). Opening browser."
        Start-Process $browserUrls[$Engine]
    }
}

<#
.SYNOPSIS
Comprehensive Hawk system health check.
.DESCRIPTION
Validates PowerShell profile, Hawk module, AI/LLM engine, environment variables, and PATH.
Provides a single command to verify the entire Hawk stack is operational.
.PARAMETER ProfilePath
Path to the PowerShell profile. Defaults to $PROFILE.CurrentUserCurrentHost.
.PARAMETER ProjectRoot
Hawk project root. Defaults to $global:HawkProjectRoot.
#>
