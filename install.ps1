<#
.SYNOPSIS
    Downloads and installs zyguard (zyguard.exe, zyguard-tui.exe,
    zyguard-server.exe) from the MakPr016/zyguard-releases GitHub releases,
    without Scoop or the setup .exe.

.DESCRIPTION
    Published at the root of the public zyguard-releases repo, so the install
    command never changes between releases:

        irm https://raw.githubusercontent.com/MakPr016/zyguard-releases/main/install.ps1 | iex

    or, from cmd.exe or any shell with curl (built into Windows 10 and later):

        curl -fsSL https://raw.githubusercontent.com/MakPr016/zyguard-releases/main/install.ps1 -o "%TEMP%\zyguard-install.ps1" && powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\zyguard-install.ps1"

    Every release so far is a pre-release, which GitHub's releases/latest
    link skips, so the newest release is looked up through the API. The zip
    is checked against the SHA-256 digest GitHub records for the asset before
    anything is unpacked. Installs to %LOCALAPPDATA%\Programs\zyguard and adds
    that folder to the user PATH; running it again upgrades in place.

    Optional environment variables:
        ZYGUARD_VERSION       a release to install instead of the newest (0.1.0-beta.2.7)
        ZYGUARD_INSTALL_DIR   where to install instead of the default folder
        ZYGUARD_NO_MODIFY_PATH=1  leave the user PATH alone

    Runs as a script block with no `exit`, so piping it into `iex` cannot close
    the caller's shell and leaves no variables behind.
#>
& {
    $ErrorActionPreference = "Stop"
    $ProgressPreference = "SilentlyContinue"   # Windows PowerShell 5.1's progress bar slows downloads ~10x
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    $repo = "MakPr016/zyguard-releases"
    $asset = "zyguard-windows-x64.zip"
    $exes = @("zyguard.exe", "zyguard-tui.exe", "zyguard-server.exe")
    $dir = if ($env:ZYGUARD_INSTALL_DIR) { $env:ZYGUARD_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA "Programs\zyguard" }

    if (-not [Environment]::Is64BitOperatingSystem) { throw "zyguard needs 64-bit Windows." }

    $headers = @{ "User-Agent" = "zyguard-install"; "Accept" = "application/vnd.github+json" }
    $release = if ($env:ZYGUARD_VERSION) {
        $tag = "v" + $env:ZYGUARD_VERSION.TrimStart("v")
        Invoke-RestMethod -Headers $headers "https://api.github.com/repos/$repo/releases/tags/$tag"
    } else {
        # Newest first, pre-releases included.
        @(Invoke-RestMethod -Headers $headers "https://api.github.com/repos/$repo/releases?per_page=1")[0]
    }
    if (-not $release) { throw "No releases found on github.com/$repo." }
    $zipAsset = $release.assets | Where-Object { $_.name -eq $asset } | Select-Object -First 1
    if (-not $zipAsset) { throw "Release $($release.tag_name) has no $asset." }
    if ($zipAsset.digest -notmatch '^sha256:([0-9a-f]{64})$') { throw "GitHub lists no SHA-256 digest for $asset in $($release.tag_name); not installing an unverified download." }
    $expected = $Matches[1]

    $running = Get-Process -Name "zyguard", "zyguard-tui", "zyguard-server" -ErrorAction SilentlyContinue
    if ($running) { throw "Close the running zyguard programs first ($(($running.Name | Sort-Object -Unique) -join ', ')), then run the installer again." }

    Write-Host "Installing zyguard $($release.tag_name) to $dir"
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("zyguard-install-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        $zip = Join-Path $tmp $asset
        Invoke-WebRequest -UseBasicParsing -Headers @{ "User-Agent" = "zyguard-install" } -Uri $zipAsset.browser_download_url -OutFile $zip
        $actual = (Get-FileHash -Path $zip -Algorithm SHA256).Hash.ToLower()
        if ($actual -ne $expected) { throw "SHA-256 mismatch for $asset (expected $expected, got $actual); nothing was installed." }

        $unpacked = Join-Path $tmp "unpacked"
        Expand-Archive -Path $zip -DestinationPath $unpacked
        foreach ($exe in $exes) {
            if (-not (Test-Path (Join-Path $unpacked $exe))) { throw "$asset is missing $exe; nothing was installed." }
        }
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        foreach ($exe in $exes) { Copy-Item -Force (Join-Path $unpacked $exe) $dir }
    } finally {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $entries = @($userPath -split ";" | Where-Object { $_ })
    if ($env:ZYGUARD_NO_MODIFY_PATH -eq "1") {
        Write-Host "Left PATH unchanged; the programs are in $dir."
    } elseif ($entries -notcontains $dir) {
        [Environment]::SetEnvironmentVariable("Path", (($entries + $dir) -join ";"), "User")
        Write-Host "Added $dir to your user PATH (new terminals pick it up)."
    }
    if ($env:ZYGUARD_NO_MODIFY_PATH -ne "1" -and ($env:Path -split ";") -notcontains $dir) { $env:Path = "$env:Path;$dir" }

    # A Scoop or installer copy earlier on PATH would shadow this one.
    $found = Get-Command zyguard.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($env:ZYGUARD_NO_MODIFY_PATH -ne "1" -and $found -and (Split-Path $found.Source) -ne $dir) {
        Write-Warning "``zyguard`` currently resolves to $($found.Source), not this install. Remove that copy (scoop uninstall zyguard, or the setup's uninstaller) or put $dir first on PATH."
    }

    Write-Host ""
    Write-Host "Installed zyguard $($release.tag_name). Start the chat UI with:  zyguard-tui"
}
