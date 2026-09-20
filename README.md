# LANCommander.Redistributables.VisualCppV9

Automatically built LANCommander redistributable import package (`.LCX`) for the
[Visual C++ v9 Redistributable (2008)](https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist).

The Microsoft Visual C++ 2008 runtime (v9.0), required by games built with the
Visual Studio 2008 toolchain — broadly the 2008 to 2012 release window, which is
the densest stretch of the LAN-era back catalogue there is. Without it a game fails
at launch with `MSVCR90.dll is missing`, `MSVCP90.dll was not found`, or the same
for `mfc90u.dll`, `atl90.dll` or `vcomp90.dll`. It is also the runtime behind *This
application has failed to start because the application configuration is
incorrect* and the `R6034` runtime error, both of which are side-by-side assembly
failures rather than plain missing files. If a game ships a
`_CommonRedist\vcredist\2008\` folder, this is the runtime it wants.

This runtime installs **side by side** with every other Visual C++ version. It does
not replace or supersede
[v10 (2010)](https://github.com/LANCommander/LANCommander.Redistributables.VisualCppV10),
[v11 (2012)](https://github.com/LANCommander/LANCommander.Redistributables.VisualCppV11),
[v12 (2013)](https://github.com/LANCommander/LANCommander.Redistributables.VisualCppV12)
or
[v14 (2015–2022)](https://github.com/LANCommander/LANCommander.Redistributables.VisualCppV14),
and a machine can legitimately carry all five.

Both architectures are bundled, at version `9.0.30729.6161` — SP1 plus the MFC
Security Update (KB2538243 / MS11-025), the final Microsoft build. By default each
client installs only the one the game's executable actually needs; set the
`Architecture` option to **Both** for .NET AnyCPU games, which report as 32-bit but
run 64-bit — see [Options](#options).

You do not need an older 2008 build alongside this one. A game linked against the
original `9.0.21022` assemblies still runs on this package, because the SP1 runtime
installs publisher policy files that redirect those bindings forward.

> The installers are bundled on the strength of the Distributable Code grant in the
> Visual Studio 2008 license terms. As with the 2010 package, and unlike 2012 and
> 2013, **Microsoft publishes no REDIST list for 2008** naming these files — and the
> one public page that says where that list lives cites the wrong year. The EULA
> inside the installer also contains a clause that sits against the grant. All of
> it, and what the position actually rests on, is set out in
> [`LICENSES/NOTICE.md`](LICENSES/NOTICE.md). Read it before relying on this
> package.

## Install it

Download the `.lcx` asset from the [latest release][latest] and import it
through your LANCommander server's **Redistributables** page, or from the CLI:

```
LANCommander.Launcher.CLI Import --Path LANCommander.Redistributables.VisualCppV9-v<version>.lcx --Type Redistributable
```

Then assign it to the games that need it, either from the game's
**Redistributables** field or from this redistributable's **Games** field.

Re-importing a newer release **updates** the existing entry rather than creating a
second one, because the identifiers in `redistributable.yml` are stable across
releases.

Alternatively, import once and let it update itself: the package ships a
`Package` script, which a LANCommander server runs on a schedule to pull new
versions straight from this repository's releases.

[latest]: https://github.com/LANCommander/LANCommander.Redistributables.VisualCppV9/releases/latest

## What is in the package

| Path | |
|---|---|
| `Manifest.yml` | Redistributable metadata, including the embedded option schema |
| `Archives/{guid}` | A ZIP of `vcredist_x86.exe`, `vcredist_x64.exe` and `LICENSE.txt`, extracted into the game's `.lancommander` metadata directory |
| `Scripts/{guid}` | One entry per PowerShell script |

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `Architecture` | choice — `both`, `auto`, `x86`, `x64` | `auto` | Which runtime to install. The default, **Match the game executable**, reads the game's PE header and installs only the runtime it actually needs. There is one case it gets wrong: a .NET AnyCPU executable reports as 32-bit even though it runs 64-bit, so set those games to **Both**. **Both** is also the right answer whenever you are unsure — 64-bit Windows still needs the x86 runtime because most games of this era are 32-bit, and installing both is never wrong, only occasionally more than necessary. |

Administrators can override this per game from the game's **Redistributables**
page. Values resolve as schema default, then per-game value, then per-action
override.

There is no `ia64` choice. Microsoft did ship an Itanium installer for 2008 — it is
named in the EULA's own title — but no LANCommander client is Itanium. There is no
ARM or ARM64 choice either, for a simpler reason: Microsoft never built one for
this version, and Windows on ARM postdates it by years.

## How this repository works

| File | Purpose |
|---|---|
| `redistributable.yml` | Identity, download links, stable script GUIDs |
| `source.ps1` | Downloads both installers under their upstream names and resolves the version from the Windows Installer package inside |
| `Schema.Overlay.yml` | The whole option schema, written by hand — there is no config file to parse |
| `OptionSchema.yml` | Built from the overlay. Do not edit by hand |
| `Scripts/*.ps1` | Client-side and server-side scripts |
| `LICENSES/` | Upstream attribution and license text |

`OptionSchema.yml` is generated, and the build fails if the committed copy does
not match what the overlay produces. To regenerate it locally:

```powershell
Import-Module <path-to>/LANCommander.Redistributables/module/LANCommander.Redistributables
Invoke-RedistributableBuild -RepositoryPath . -UpdateSchema
```

### How detection and install work

Detection for 2008 does not work the way it does for any other package in this
family, and the difference is not cosmetic.

Every sibling reads a registry key that the runtime writes about itself — v14, 2013
and 2012 under `Microsoft\VisualStudio\<n>.0\VC\Runtimes`, 2010 under
`...\VC\VCRedist`. **2008 writes no such key at all.** Verified on a machine
carrying `9.0.30729.6161` for both architectures:
`HKLM\SOFTWARE\Microsoft\VisualStudio\9.0\VC` and its `WOW6432Node` counterpart are
both absent. Microsoft's documented answer for 9.0 is to query a fixed list of MSI
product codes instead, which is unusable here because those codes differ per
servicing build *and* per installer locale.

So `DetectInstall` reads the Windows uninstall registry, under both
`HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall` and the `WOW6432Node`
path, and matches entries named `Microsoft Visual C++ 2008 Redistributable - x86|x64
<version>`. Three things about those entries shape the script:

- **The architecture is in the display name.** That is what makes the match survive
  registry redirection: on a 64-bit host the x64 entries land in the native hive
  and the x86 ones under `WOW6432Node`, and which of those the host PowerShell can
  see depends on its own bitness. Both are read regardless.
- **The precise build is *only* in the display name.** `DisplayVersion` comes from
  the MSI `ProductVersion`, which Windows Installer truncates to three fields — the
  SP1 entry reads `9.0.30729` where its name reads `9.0.30729.17`. The name is
  authoritative here and `DisplayVersion` is the fallback.
- **Several entries per architecture are normal.** Unlike 2010 and later, the 2008
  packages do not major-upgrade each other: RTM, SP1, the ATL update and the MFC
  update each keep their own uninstall entry and can all be present at once. The
  newest per architecture is the one that answers the question.

It reports "installed" only when every selected architecture is present *and* at
least as new as the build this package carries, because Microsoft's installer
refuses to downgrade and returns an error when a newer runtime is already present.

Versions are compared across **all four** components, where the sibling packages
compare three. 2008's entire servicing history lives in the revision field —
`9.0.30729.17`, `.4148`, `.6161` — so collapsing to `major.minor.build` would make
an unpatched SP1 machine look satisfied and silently deny it MS11-025.

`Install` runs each installer with `/q /norestart` and treats `1638` (a newer
version is already installed, also seen as `0x80070666`), `3010` and `1641` (reboot
pending or initiated) as success alongside `0`. `1638` is routine here rather than
an edge case, precisely because these packages stack rather than upgrade.

Those switches are the same pre-Burn pair 2010 uses; 2012, 2013 and v14 are Burn
bundles and take `/install /quiet /norestart` instead. Passing the Burn switches
here would show an installer window during what is supposed to be a silent install.

`Uninstall` deliberately does nothing. The runtime is shared machine-wide and
other software depends on it.

### Why the upstream check never reports anything

Visual Studio 2008 left extended support on 10 April 2018 and the runtime is pinned
to `9.0.30729.6161`, so the scheduled `check-upstream` workflow runs daily and
always finds the same version. That is correct rather than broken — it stays in
place in case Microsoft reissues a security update.

As with 2010 and 2012 there are no `aka.ms` permalinks for these packages; the
download links are raw `download.microsoft.com` paths, which also means they cannot
self-heal if Microsoft reorganises the CDN. Both architectures sit under the *same*
download folder GUID, which looks like a mistake in `redistributable.yml` and is not
one — it is the layout of the Download Center entry for KB2538243.

Both workflows pin `runs_on: windows-latest`, for a reason specific to this package.
The siblings do it because they read a PE version resource, which .NET cannot do on
Linux. Here the installer's own PE version is `9.0.30729.5677` — the stamp on the
self-extracting shell, which Microsoft left behind at the ATL Security Update and
never restamped. The package inside it is `9.0.30729.6161`, which is what the MSI
declares, what a client records once installed, and what every external index of
this download calls it. `source.ps1` therefore unpacks the installer with its own
documented `/x:` switch and reads `ProductVersion` out of `vc_red.msi` through
WindowsInstaller COM. Both steps are Windows-only; nothing is installed, and the
unpacked copy is discarded.

## Licensing

The scripts and workflows here are MIT licensed. The redistributed payload is not
ours — see [`LICENSES/NOTICE.md`](LICENSES/NOTICE.md) for attribution, the full
terms, and the reasoning behind how this package is distributed.
