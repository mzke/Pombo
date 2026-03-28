@{
    ModuleVersion     = '1.0.0'
    GUID              = 'b4e5a1c2-d3f6-4789-8a0b-c1d2e3f40011'
    Author            = 'Richard R Manzke' 
    Description       = 'PowerShell MongoDB Objects - Abstrai operacoes MongoDB para PSCustomObject'
    PowerShellVersion = '7.4'
    RootModule        = 'Pombo.psm1'
    FunctionsToExport = @('Get-Pombo', 'New-Pombo', 'Set-Pombo', 'Remove-Pombo')
    PrivateData       = @{
        PSData = @{
            Tags = @('MongoDB', 'Database', 'NoSQL')
        }
    }
}
