# GraphEssentials

PowerShell module for Microsoft 365 and Entra ID administration through
Microsoft Graph: apps and credentials, users, guests, devices, roles,
Defender, licensing and usage reports, with HTML report output.

## Layout

- `Public/`: exported functions, one function per file.
- `Private/`: internal helpers, one function per file.
- `Tests/`: Pester 5 tests. `GraphEssentials.Tests.ps1` at the root runs them.
- `Build/Build-Module.ps1`: build, documentation and publishing through
  PSPublishModule.
- `Docs/` and `en-US/GraphEssentials-help.xml`: generated from comment-based help.
- `Examples/`: runnable usage examples.

## Build and test

```powershell
./GraphEssentials.Tests.ps1                                # run the Pester suite
./Build/Build-Module.ps1                                   # build the module
./Build/Build-Module.ps1 -RunMode Documentation            # regenerate Docs/ and help
```

Publishing (`-RunMode Publish`) signs the module and pushes to the PowerShell
Gallery and GitHub. Only run it for a release.

## Generated files

`Docs/*.md` and `en-US/GraphEssentials-help.xml` come from the comment-based
help in `Public/`. Edit the help in the function, then regenerate. Never edit
the generated files by hand.

## Conventions

- Support Windows PowerShell 5.1 and PowerShell 7. Don't use PowerShell 7-only
  syntax.
- K&R/OTBS braces and full parameter names.
- Comment-based help goes inside the function, after the `function` line and
  before `[CmdletBinding()]`, with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`
  and `.EXAMPLE`.
- Build arrays with `$list = foreach (...) { ... }` or a generic list, not `+=`.
  Avoid `Where-Object` inside loops.
- Commit and PR titles use Conventional Commits with Gitmoji:
  `fix(devices): 🐛 Keep Intune records when ...`.

## Gotchas

- Most commands call live Graph endpoints. Tests mock Graph calls. Don't run
  commands against a tenant unless the task asks for it.
