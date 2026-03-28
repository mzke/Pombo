$script:ModuleRoot = $PSScriptRoot

$dotnetVersion = [System.Environment]::Version
if ($dotnetVersion.Major -lt 8) {
    throw "Pombo requer .NET 8 ou superior. Versao detectada: $dotnetVersion"
}

Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -ErrorAction Stop |
    ForEach-Object { . $_.FullName }

Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction Stop |
    ForEach-Object { . $_.FullName }

Initialize-Driver -ModuleRoot $script:ModuleRoot
