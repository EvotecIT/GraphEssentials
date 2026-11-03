# Build and publish

The build uses PSPublishModule 3.0.185 or later. Run the same entrypoint for local
validation, generated help and public publication:

```powershell
./Build/Build-Module.ps1
./Build/Build-Module.ps1 -RunMode Documentation
./Build/Build-Module.ps1 -RunMode Publish
```

`Build` and `Documentation` default to unsigned operation. `Publish` builds and
signs the module, then publishes to PowerShell Gallery and GitHub using the
configured local API-key files. Use `-PublishGitHub:$false` only when deliberately
publishing to PowerShell Gallery alone.

Signing uses `AllowedCertificateThumbprints`. Its default contains the established
release identity. Supply the approved identities available on another signing
machine as an array; PowerForge selects an eligible certificate from that list.
Use `-CertificateThumbprint` to select one approved identity explicitly. A local
build does not require the release key:

```powershell
./Build/Build-Module.ps1 -RunMode Build -SignModule:$false
./Build/Build-Module.ps1 -RunMode Publish -AllowedCertificateThumbprints $approvedThumbprints
```

The shared builder creates module and archive output under `Artefacts`, including
the configured dependencies. Generated packages remain outside source control;
do not move module files or recreate ZIPs manually. `Documentation` regenerates
command Markdown and external help from function comments.
