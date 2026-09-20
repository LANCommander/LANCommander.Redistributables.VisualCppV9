<#
.SYNOPSIS
    Resolves and downloads the upstream Visual C++ v9 Redistributable (2008) installers.
.DESCRIPTION
    Contract:
      -CheckOnly            write the upstream version to stdout and exit.
      -OutputPath <dir>     download the installers there, then emit a JSON object
                            with Version and optionally Changelog.

    Microsoft publishes no version number for the v14 package anywhere. There is
    no release feed, and the download page deliberately omits the version because
    the package is updated frequently -- their own instructions are to download the
    installer and read "File version" off its properties in Explorer. So none of
    Resolve-UpstreamVersion's resolvers apply and the version is read out of the
    downloaded installer instead. The older per-year packages are pinned and never
    move, so the same code simply reports the same version every time, which is
    correct.

    2008 is where "read it off the installer" stops meaning the PE resource, and
    this is the only repository in the family that does it differently. The PE file
    version of vcredist_x86.exe and vcredist_x64.exe is 9.0.30729.5677: the stamp on
    the self-extracting shell, which Microsoft left behind at the ATL Security
    Update and never restamped for the MFC one. The Windows Installer package inside
    is 9.0.30729.6161, and that is the number the MSI declares, that the machine
    records in its uninstall entry once installed, that Microsoft's own winget
    manifests carry, and that the Download Center entry for KB2538243 serves. Taking
    the shell's version would stamp this package with a build nobody recognises and
    that DetectInstall would never see on a client.

    So the version comes from vc_red.msi, extracted with the vendor's own documented
    /x: switch -- no 7-Zip, no third-party tooling, and nothing is installed.

    The installers are copied in byte-for-byte under their original filenames --
    vcredist_x86.exe and vcredist_x64.exe, which is what Microsoft served them as;
    the vc_redist.<arch>.exe spelling only arrives with the 2015+ packages. That
    matches VisualCppV10, VisualCppV11 and VisualCppV12 and diverges from
    VisualCppV14, which normalises the name.

    For 2012 and 2013 there is a positive reason to keep the upstream names: their
    published REDIST lists grant those files by name. No such list exists for 2008,
    so that argument is unavailable here -- see LICENSES/NOTICE.md. The names are
    kept anyway, because renaming a file we are relying on a redistribution grant to
    carry is a change we have no reason to make. Scripts/Install.ps1 and
    Scripts/Package.ps1 expect this spelling to match.

    Changelog is deliberately null. Microsoft publishes no per-build changelog at a
    stable URL, and inventing one would put fiction in every release body.
#>
[CmdletBinding(DefaultParameterSetName = 'Download')]
param(
    [Parameter(ParameterSetName = 'Check')][switch] $CheckOnly,
    [Parameter(ParameterSetName = 'Download', Mandatory)][string] $OutputPath
)

$ErrorActionPreference = 'Stop'

$definition = Get-RedistributableDefinition -Path $PSScriptRoot
$source = $definition['Source']

$downloads = $source['Downloads']

if (-not $downloads -or $downloads.Count -eq 0) {
    throw 'Source.Downloads in redistributable.yml lists no installers to fetch'
}

$versionFrom = [string] $source['VersionFrom']

if (-not $downloads.Contains($versionFrom)) {
    throw "Source.VersionFrom is '$versionFrom' but Source.Downloads has no such entry"
}

<#
.SYNOPSIS
    Reads the four-part ProductVersion out of the MSI inside a 2008 self-extractor.
.DESCRIPTION
    This is why both workflows pin runs_on to windows-latest, for two reasons rather
    than the one the sibling repositories have. Extraction runs the vendor's own
    Windows executable, and reading the MSI property table goes through the
    WindowsInstaller COM automation object. Neither exists on Linux.

    /x:<dir> /q is Microsoft's documented way to unpack these packages without
    installing them. Two things about it are worth knowing before changing this:

      - It returns exit code 0 when it has extracted nothing at all. A path
        containing a space silently produces no files unless the switch value is
        quoted, which is why it is quoted below. The presence of vc_red.msi is the
        real success test, not the exit code.
      - It writes the full setup layout -- installer shell, localised EULAs, the
        cab. Only vc_red.msi is read; none of it is packaged. The payload this
        script emits is the untouched self-extractors.
#>
function Get-PackageVersion {
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $ScratchPath
    )

    $null = New-Item -ItemType Directory -Path $ScratchPath -Force

    $process = Start-Process -FilePath $Path -ArgumentList ('/x:"{0}"' -f $ScratchPath), '/q' -Wait -PassThru
    $msi = Join-Path $ScratchPath 'vc_red.msi'

    if (-not (Test-Path -LiteralPath $msi)) {
        $size = (Get-Item -LiteralPath $Path).Length

        throw "'$Path' ($size bytes) did not yield a vc_red.msi when extracted (exit code $($process.ExitCode)). " +
              "Run this on Windows -- extraction runs the vendor's own executable. " +
              "If you already are, the download was not an installer."
    }

    $installer = New-Object -ComObject WindowsInstaller.Installer

    try {
        # [string] is load-bearing. Join-Path emits a PSObject-wrapped string, and
        # handing that wrapper to COM marshalling fails with DISP_E_TYPEMISMATCH
        # rather than with anything that names the real problem. The cast unwraps it.
        $database = $installer.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $installer, @([string] $msi, 0))
        $view = $database.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $database, @("SELECT Value FROM Property WHERE Property = 'ProductVersion'"))

        $null = $view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null)
        $record = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)

        # Compared against $null rather than tested with -not. A COM object has no
        # boolean conversion, so -not dispatches into it and comes back with
        # DISP_E_TYPEMISMATCH instead of the answer.
        if ($null -eq $record) {
            throw "'$msi' has no ProductVersion property"
        }

        # Microsoft ships this one with a leading space in the property value.
        $version = ([string] $record.GetType().InvokeMember('StringData', 'GetProperty', $null, $record, 1)).Trim()
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($installer) | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace($version)) {
        throw "'$msi' reported an empty ProductVersion"
    }

    return $version
}

$temp = Join-Path ([System.IO.Path]::GetTempPath()) "vcredist-$([guid]::NewGuid())"
$null = New-Item -ItemType Directory -Path $temp -Force

try {
    # -CheckOnly runs daily from the scheduled upstream check, so it fetches only
    # the one installer the version is taken from rather than all of them.
    $wanted = if ($CheckOnly) { @($versionFrom) } else { @($downloads.Keys) }

    $versions = [ordered] @{}

    foreach ($architecture in $wanted) {
        $url = [string] $downloads[$architecture]
        $file = Join-Path $temp "vcredist_$architecture.exe"

        Write-Verbose "Downloading $url"
        Invoke-WebRequest -Uri $url -OutFile $file -MaximumRetryCount 3 -RetryIntervalSec 5

        $versions[$architecture] = Get-PackageVersion -Path $file -ScratchPath (Join-Path $temp "extract-$architecture")
    }

    $version = $versions[$versionFrom]

    # Microsoft ships every architecture of a given build together, so a mismatch
    # means one of the links is serving a stale file. Worth seeing in the build
    # log, but not worth failing over -- the package is still coherent, it just
    # carries two builds.
    foreach ($architecture in $versions.Keys) {
        if ($versions[$architecture] -ne $version) {
            Write-Warning "vcredist_$architecture.exe is $($versions[$architecture]) but the package is stamped $version from $versionFrom"
        }
    }

    if ($CheckOnly) {
        Write-Output $version
        return
    }

    if (-not (Test-Path -LiteralPath $OutputPath)) {
        $null = New-Item -ItemType Directory -Path $OutputPath -Force
    }

    # The self-extractors, not the extracted layout. What ships is exactly what
    # Microsoft served.
    foreach ($architecture in $downloads.Keys) {
        Copy-Item -LiteralPath (Join-Path $temp "vcredist_$architecture.exe") -Destination $OutputPath -Force
    }

    # The terms have to reach the machine the software is installed on, not just
    # this repository.
    $license = Join-Path $PSScriptRoot 'LICENSES/UPSTREAM-LICENSE.txt'

    if (Test-Path -LiteralPath $license) {
        Copy-Item -LiteralPath $license -Destination (Join-Path $OutputPath 'LICENSE.txt') -Force
    }
    else {
        throw 'LICENSES/UPSTREAM-LICENSE.txt is missing; the license text must ship with the installers'
    }

    @{
        Version   = $version
        Changelog = $null
    } | ConvertTo-Json -Compress | Write-Output
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
