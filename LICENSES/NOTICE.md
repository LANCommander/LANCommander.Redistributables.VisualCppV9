# Attribution and licensing

This repository contains two separately licensed things. Keeping them distinct
matters, because only one of them is ours to license.

## What we authored

The packaging scripts, workflows, option schema, curation overlay and
documentation in this repository are copyright (c) 2026 LANCommander and are
released under the MIT License, in `LICENSE`.

## What we redistribute

The published `.LCX` package contains `vcredist_x86.exe` and `vcredist_x64.exe`,
which we did not author and do not license. Those files remain under their own
terms:

| | |
|---|---|
| Project | Visual C++ v9 Redistributable (2008) |
| Homepage | https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist |
| Copyright | (c) Microsoft Corporation |
| License | Microsoft Software License Terms — Microsoft Visual C++ 2008 Runtime Libraries (x86, ia64 and x64), Service Pack 1 |
| Version | 9.0.30729.6161 |

The full terms are in `UPSTREAM-LICENSE.txt`, taken verbatim from `eula.1033.txt`
inside the installer itself. As with the 2010, 2012 and 2013 terms there is no
published URL for this document — it ships only inside the package. Like 2010's,
and unlike 2012's and 2013's, it carries **no EULAID**, so its title is the only
identifier it has. `source.ps1` also copies it into the payload as `LICENSE.txt`,
so the terms reach the machine the runtime is installed on rather than only living
here.

Both the x86 and x64 packages embed a byte-identical copy — the same
`eula.1033.txt`, SHA-256
`C68A0FD93E8C64139A42AF4FCD4670C6FAEA3A5D5D1E9DD35B197F7D5268D92B`, in each.

Extraction is easier here than for any other version in this family. 2008 predates
Burn, so there is no UX container and no manifest indirection, and the EULAs are
plain UTF-16 text rather than the RTF 2010 ships — one file per LCID, English at
`eula.1033.txt`. The installer's own `/x:<dir> /q` switch unpacks it without
third-party tooling.

### What the redistribution grant rests on, and why that is thinner here

This section deliberately does not read like its counterparts in
`LANCommander.Redistributables.VisualCppV11` and `...V12`. It cannot, and
pretending otherwise would be the dishonest option. It is closest to
`...V10`'s, and thinner again.

For 2012 and 2013, Microsoft publishes a version-specific **REDIST list** on
Microsoft Learn that names `vcredist_x86.exe` and `vcredist_x64.exe` outright as
distributable. Those pages are what the 2012 and 2013 packages in this
organisation rely on, and they can be quoted and linked.

**There is no such page for 2008.** The public REDIST lists begin at 2012; the
equivalent slugs under `/visualstudio/releases/` return 404 for 2008 as they do for
2010. Visual Studio 2008's own documentation says where the list lives instead:

> Only some Visual C++ files can be redistributed with your application. See the
> Microsoft Software License Terms for Visual Studio 2005 and the Redist.txt file
> to see which files can be redistributed with your application. EULA.txt is in the
> \Setup directory on the first Visual C++ 2008 product CD or on the DVD, and
> Redist.txt is located in the Program Files\Microsoft Visual Studio 2005 directory
> on the second CD or on the DVD.

<https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2008/ms235299(v=vs.90)>

Read that quotation again. **It is the Visual C++ 2008 page, and it points at the
Visual Studio 2005 license terms and the Visual Studio 2005 directory.** That is
not a transcription error here; it is what the page says, apparently carried over
from its 2005 predecessor and never corrected. So the single public pointer to
where the 2008 grant lives names the wrong product, and the document it points at
is on physical media for a product that left support in 2018. Neither is citable
by URL, and neither is reproduced here, because we are not going to quote a
document from memory in a licensing notice.

What can be shown is this. The same page names the redistributable package as the
intended deployment vehicle, which at least settles that Microsoft expected these
files to travel with third-party applications:

> The Visual C++ Redistributable Package (VCRedist_x86.exe, VCRedist_x64.exe,
> VCRedist_ia64.exe) has to be executed on the target system as a prerequisite to
> installation of the application. This package installs and registers all Visual
> C++ libraries.

And Microsoft's current download page for the whole Visual C++ Redistributable
family states the condition that applies across every version, 2008 included:

> Redistribution is permitted only for licensed Visual Studio users, as described
> in the Visual Studio license terms.

<https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist>

That is the whole public evidential base for 2008. It is weaker than what 2012 and
2013 have, and weaker than 2010's by the width of that wrong-year citation. The
honest summary is that this package rests on the general Visual Studio 2008
Distributable Code grant rather than on a version-specific list we can point at.

Given that, the package is shaped to stay inside whatever that grant covers:

- The installers are carried byte-for-byte as Microsoft served them —
  4,483,040 bytes for x86 and 5,211,080 for x64. Nothing here repacks, extracts or
  patches them. The SHA-256 digests are
  `8742BCBF24EF328A72D2A27B693CC7071E38D3BB4B9B44DEC42AA3D2C8D61D92` (x86) and
  `C5E273A4A16AB4D5471E91C7477719A2F45DDADB76C7F98A38FA5074A6838654` (x64),
  computed from the files the URLs in `redistributable.yml` returned and matching
  the digests in Microsoft's own winget manifests for
  `Microsoft.VCRedist.2008.x86` and `Microsoft.VCRedist.2008.x64`.
- `source.ps1` does unpack a copy while resolving the version, because the only
  place this package's real version is written down is the `ProductVersion` of the
  `vc_red.msi` inside it. That copy is read in a temporary directory and thrown
  away; what is packaged is the untouched self-extractor.
- They keep their **upstream filenames**. For 2012 and 2013 there is a positive
  reason to do that — their REDIST lists enumerate those names. Here there is no
  such list to match, so the reason is simply that renaming a file we are relying
  on a redistribution grant to carry is a change with no upside.
- No copyright, trademark or patent notices have been altered or removed, and the
  license text travels with the binaries.

An `ia64` installer also exists and is not shipped. That is a targeting decision,
not a licensing one — no LANCommander client is Itanium, though 2008 is late enough
that the EULA above still names it in its own title. Microsoft never built an ARM
or ARM64 runtime for 2008 at all, so unlike the 2012 package there is nothing
further to leave out.

### The clause that sits against it

The EULA inside the installer — the one in `UPSTREAM-LICENSE.txt` — contains **no
Distributable Code section of its own**, and under *Scope of License* says you may
not:

> publish the software for others to copy;
>
> rent, lease or lend the software;
>
> transfer the software or this agreement to any third party; or

That is the same prohibition the 2010, 2012 and 2013 EULAs carry, and it points in
a different direction from the Visual Studio license terms. In the 2012 and 2013
packages that tension is resolved by the REDIST list being the more specific
instrument — it names those exact files for this exact purpose. For 2008 the more
specific instrument exists but is not public, and the only public signpost to it
cites the wrong year, so the resolution is the same in substance and weaker in
evidence than any other package in this family.

Stated plainly: this is the thinnest position of the four Visual C++ packages in
this organisation that rest on a per-version grant, and still a better one than
`...V14`, whose standalone terms carry no redistribution grant anywhere and which
does not have a per-version list either. It is not free of tension. Saying so is
more useful than implying otherwise.

Automated policy screening (`Test-RedistributableLicense`) returns `conditional` /
requires-human-review for these terms, as it does for every Visual C++ EULA in this
organisation. The decision to bundle was taken by a human with the clauses above in
front of them, not by that tool.

### If you would rather we did not

If you are at Microsoft, or anyone else with standing here, open an issue and we
will switch this package to `Source.Mode: none` without argument. The packaging
module already supports it and `LANCommander.Redistributables.dgVoodoo2` is a
working example: the `.LCX` then ships scripts only, and the runtime is fetched
from Microsoft rather than from us.

The uninstall-registry detection, architecture option, exit-code handling and
update workflow in this repository are all ours and are unaffected by that change.
Only where the bytes come from would differ.
