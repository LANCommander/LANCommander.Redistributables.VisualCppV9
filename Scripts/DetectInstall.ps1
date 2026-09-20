# Reports whether the selected Visual C++ v9 Redistributable (2008) runtimes are
# already present, and at least as new as the build this package carries.
#
# Working directory: {InstallDir}\.lancommander\{RedistributableId}\
#
# Fast by construction: one wildcard registry read per hive and no network. The
# engine gives this script ten seconds.

$ErrorActionPreference = 'Stop'

# Four components, where every sibling in this family compares three.
#
# The others reduce to major.minor.build because their registry values and their
# manifest versions disagree about the fourth component -- v11 writes
# "v11.0.61030.00" against a manifest "11.0.61030.0" -- and because a three-part
# [version] has Revision -1, which sorts below 0.
#
# 2008 cannot afford that reduction. Its entire servicing history lives in the
# revision field: RTM is 9.0.21022, SP1 is 9.0.30729.17, the ATL Security Update is
# 9.0.30729.4148 and the MFC Security Update this package carries is
# 9.0.30729.6161. Collapse to three components and an unpatched SP1 machine reports
# as satisfied, and never receives MS11-025. So all four are compared, with a
# missing component read as 0 rather than -1, which keeps the original reason for
# normalising intact.
function Get-RuntimeVersion {
    param([string] $Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }

    $match = [regex]::Match($Value, '(\d+)\.(\d+)\.(\d+)(?:\.(\d+))?')

    if (-not $match.Success) { return $null }

    $revision = if ($match.Groups[4].Success) { [int] $match.Groups[4].Value } else { 0 }

    return [version]::new(
        [int] $match.Groups[1].Value,
        [int] $match.Groups[2].Value,
        [int] $match.Groups[3].Value,
        $revision)
}

# 2008 is detected through the Windows uninstall registry, because there is nothing
# else to read. It predates the convention its siblings rely on: v14, 2013 and 2012
# record themselves under Microsoft\VisualStudio\<n>.0\VC\Runtimes and 2010 under
# ...\VC\VCRedist, while HKLM\SOFTWARE\Microsoft\VisualStudio\9.0\VC does not exist
# at all -- verified on a machine carrying 9.0.30729.6161 for both architectures,
# under both the native and the WOW6432Node view.
#
# Microsoft's own guidance for 9.0 is to call MsiQueryProductState with a fixed list
# of product codes. That is unusable here: the codes differ per servicing build and,
# as the comments on that same article record, per installer locale, so a hard-coded
# list silently fails to detect a German or Japanese machine.
#
# Three things about these entries drive the code below.
#
#   - The architecture is in the display name, so it survives the hive the entry
#     happens to land in. On a 64-bit host the x64 entries sit under the native
#     path and the x86 ones under WOW6432Node, and which of those the host
#     PowerShell can see depends on its own bitness. Both are read.
#   - The precise build is ALSO only in the display name. DisplayVersion is derived
#     from the MSI ProductVersion, which Windows Installer truncates to three
#     fields: the SP1 entry reads "9.0.30729" where its name reads
#     "9.0.30729.17". The name is authoritative and DisplayVersion is the fallback.
#   - Several entries per architecture are normal. Unlike 2010 and later, the 2008
#     packages do not major-upgrade each other -- RTM, SP1, the ATL update and the
#     MFC update each keep their own uninstall entry and can all be present at
#     once. The newest per architecture is the one that answers the question.
function Get-InstalledRuntime {
    $found = @{}

    foreach ($root in @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )) {
        # One wildcard read per hive rather than one per subkey. There are several
        # hundred of these on a normal machine and this script has ten seconds.
        $entries = Get-ItemProperty -Path (Join-Path $root '*') -ErrorAction SilentlyContinue

        foreach ($entry in $entries) {
            $match = [regex]::Match(
                [string] $entry.DisplayName,
                '^Microsoft Visual C\+\+ 2008 Redistributable\s*-\s*(x86|x64|ia64)\s+([\d.]+)')

            if (-not $match.Success) { continue }

            $architecture = $match.Groups[1].Value.ToLowerInvariant()

            $version = Get-RuntimeVersion -Value $match.Groups[2].Value

            if (-not $version) { $version = Get-RuntimeVersion -Value ([string] $entry.DisplayVersion) }
            if (-not $version) { continue }

            if (-not $found.ContainsKey($architecture) -or $found[$architecture] -lt $version) {
                $found[$architecture] = $version
            }
        }
    }

    return $found
}

# Anything unexpected means "not installed" rather than an error. A detection
# script that throws inside its timeout tells the operator nothing useful, and
# attempting an install that turns out to be redundant is harmless -- the installer
# repairs in place, or reports 1638 and the Install script treats that as success.
#
# That is also the mitigation for the one weakness of matching on a display name:
# should a localised installer ever write a translated one, no entry matches, this
# reports "not installed", and the Install script puts the machine right anyway.
$Return = $false

try {
    # The cmdlet writes a non-terminating error when the game manifest has no entry
    # for this redistributable. Both is the right answer in that case -- it is never
    # wrong, only occasionally more than necessary -- so the lookup is not allowed to
    # fail the script.
    $options = Get-RedistributableOptions -Path $InstallDirectory -Id $GameManifest.Id `
        -Name 'Visual C++ v9 Redistributable (2008)' -ErrorAction SilentlyContinue

    $architecture = if ($options -and $options.Architecture) { ([string] $options.Architecture).ToLowerInvariant() } else { 'both' }

    if ($architecture -eq 'auto') {
        $executable = $GameManifest.Actions |
            Where-Object { $_.IsPrimaryAction } |
            Select-Object -First 1 -ExpandProperty Path

        if ($executable) { $executable = $executable.Replace('{InstallDir}', $InstallDirectory) }

        # Unreadable executable falls back to both rather than guessing. A wrong
        # guess here silently skips the runtime the game actually needs.
        $architecture = 'both'

        if ($executable -and (Test-Path -LiteralPath $executable)) {
            $stream = [System.IO.File]::OpenRead($executable)

            try {
                $reader = [System.IO.BinaryReader]::new($stream)
                $stream.Position = 0x3C
                $stream.Position = $reader.ReadInt32() + 4
                $machine = $reader.ReadUInt16()

                # 0x8664 x64, 0xAA64 ARM64 -- both map to x64, but not for v14's
                # reason. The v14 x64 package carries ARM64 binaries; the 2008 one
                # does not, and Microsoft never built an ARM or ARM64 runtime for
                # 2008 at all -- Windows on ARM postdates it by years. x64 is simply
                # the closest thing that exists, and ARM64 Windows runs it under
                # emulation. 0x014C is x86, and is also what a managed AnyCPU
                # executable reports even though it runs 64-bit; those games should
                # be set to Both explicitly.
                $architecture = if ($machine -eq 0x8664 -or $machine -eq 0xAA64) { 'x64' } else { 'x86' }
            }
            finally {
                $stream.Dispose()
            }
        }
    }

    $required = switch ($architecture) {
        'x86' { @('x86') }
        'x64' { @('x64') }
        default { @('x86', 'x64') }
    }

    # Null when the manifest carries no version, which degrades this to a presence
    # check rather than failing detection outright.
    $wanted = Get-RuntimeVersion -Value $RedistributableManifest.Version

    $installed = Get-InstalledRuntime

    $satisfied = $true

    foreach ($arch in $required) {
        if (-not $installed.ContainsKey($arch)) {
            Write-Host "Visual C++ v9 Redistributable (2008) ($arch) is not installed"
            $satisfied = $false
            break
        }

        if ($wanted -and $installed[$arch] -lt $wanted) {
            Write-Host "Visual C++ v9 Redistributable (2008) ($arch) is $($installed[$arch]), older than the packaged $($RedistributableManifest.Version)"
            $satisfied = $false
            break
        }
    }

    $Return = $satisfied
}
catch {
    Write-Host "Visual C++ v9 Redistributable (2008) detection failed, assuming not installed: $($_.Exception.Message)"
    $Return = $false
}
