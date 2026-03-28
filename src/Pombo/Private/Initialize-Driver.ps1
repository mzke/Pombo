function Initialize-Driver {
    param(
        [Parameter(Mandatory)]
        [string]$ModuleRoot
    )

    $libPath = Join-Path $ModuleRoot 'lib'

    if (-not (Test-Path $libPath)) {
        New-Item -ItemType Directory -Path $libPath | Out-Null
    }

    # Verifica presenca dos dois assemblies principais
    $driverPresent = (Test-Path (Join-Path $libPath 'MongoDB.Driver.dll')) -and
                     (Test-Path (Join-Path $libPath 'MongoDB.Bson.dll'))

    if (-not $driverPresent) {
        Write-Host 'Baixando MongoDB.Driver do NuGet...' -ForegroundColor Cyan
        Install-MongoDriver -LibPath $libPath
    }

    # Registra resolver para carregar dependencias do diretorio lib automaticamente
    $capturedLibPath = $libPath
    [System.AppDomain]::CurrentDomain.add_AssemblyResolve(
        {
            param($sender, $resolveArgs)
            $assemblyName = $resolveArgs.Name.Split(',')[0]
            $dllPath = Join-Path $capturedLibPath "$assemblyName.dll"
            if (Test-Path $dllPath) {
                return [System.Reflection.Assembly]::LoadFrom($dllPath)
            }
            return $null
        }.GetNewClosure()
    )

    # Carrega Bson e Driver explicitamente; sem isso, [MongoDB.Bson.*] so ficaria acessivel
    # apos a primeira chamada JIT a um metodo do Driver — o que quebra usos diretos dos tipos.
    [System.Reflection.Assembly]::LoadFrom((Join-Path $libPath 'MongoDB.Bson.dll'))   | Out-Null
    [System.Reflection.Assembly]::LoadFrom((Join-Path $libPath 'MongoDB.Driver.dll')) | Out-Null

    # Compila helper C# para contornar limitacoes de metodos genericos e extension methods no PowerShell
    if (-not ([System.Management.Automation.PSTypeName]'PomboHelper').Type) {
        $helperCode = @'
using MongoDB.Bson;
using MongoDB.Driver;

public static class PomboHelper
{
    public static IMongoCollection<BsonDocument> GetCollection(IMongoDatabase database, string name)
        => database.GetCollection<BsonDocument>(name, null);

    public static IAsyncCursor<BsonDocument> FindAll(IMongoCollection<BsonDocument> collection)
        => collection.FindSync(FilterDefinition<BsonDocument>.Empty, null, default);

    public static IAsyncCursor<BsonDocument> FindById(IMongoCollection<BsonDocument> collection, BsonDocument filter)
        => collection.FindSync(filter, null, default);

    public static void InsertOne(IMongoCollection<BsonDocument> collection, BsonDocument document)
        => collection.InsertOne(document, null, default);

    public static void ReplaceOne(IMongoCollection<BsonDocument> collection, BsonDocument filter, BsonDocument document)
        => collection.ReplaceOne(filter, document, (ReplaceOptions)null, default);

    public static void DeleteOne(IMongoCollection<BsonDocument> collection, BsonDocument filter)
        => collection.DeleteOne(filter, null, default);
}
'@
        $runtimeDir = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
        $refs = @(
            (Join-Path $libPath 'MongoDB.Driver.dll')
            (Join-Path $libPath 'MongoDB.Bson.dll')
            (Join-Path $runtimeDir 'System.Private.CoreLib.dll')
            (Join-Path $runtimeDir 'System.Runtime.dll')
            (Join-Path $runtimeDir 'System.Linq.Expressions.dll')
        ) | Where-Object { Test-Path $_ }

        $prev = $WarningPreference
        $WarningPreference = 'SilentlyContinue'
        Add-Type -TypeDefinition $helperCode -ReferencedAssemblies $refs -IgnoreWarnings
        $WarningPreference = $prev
    }
}

function Install-MongoDriver {
    param([string]$LibPath)

    $targetFrameworks = @('net8.0', 'net6.0', 'netstandard2.1', 'netstandard2.0')

    $version = Get-LatestNuGetVersion -PackageId 'MongoDB.Driver'
    if (-not $version) {
        throw 'Nao foi possivel obter a versao mais recente do MongoDB.Driver do NuGet.'
    }

    Write-Host "  MongoDB.Driver $version" -ForegroundColor Cyan

    $downloaded = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $queue = [System.Collections.Generic.Queue[PSCustomObject]]::new()
    $queue.Enqueue([PSCustomObject]@{ Id = 'MongoDB.Driver'; Version = $version })

    while ($queue.Count -gt 0) {
        $pkg = $queue.Dequeue()

        if ($downloaded.Contains($pkg.Id)) { continue }
        $downloaded.Add($pkg.Id) | Out-Null

        # Pula pacotes que fazem parte do runtime .NET
        if ($pkg.Id -match '^(System\.|Microsoft\.NETCore\.|NETStandard\.Library|runtime\.)') { continue }

        $pkgVersion = Resolve-PackageVersion -PackageId $pkg.Id -VersionSpec $pkg.Version
        if (-not $pkgVersion) {
            Write-Warning "  Versao nao resolvida para $($pkg.Id), pulando."
            continue
        }

        Write-Host "  $($pkg.Id) $pkgVersion" -ForegroundColor Gray

        # Baixa o .nupkg e extrai DLLs + dependencias em uma unica operacao
        $result = Install-NuGetPackage -PackageId $pkg.Id -Version $pkgVersion -LibPath $LibPath -TargetFrameworks $targetFrameworks

        foreach ($dep in $result.Dependencies) {
            if (-not $downloaded.Contains($dep.Id)) {
                $queue.Enqueue($dep)
            }
        }
    }
}

function Get-LatestNuGetVersion {
    param([string]$PackageId)

    $id = $PackageId.ToLower()
    try {
        $result = Invoke-RestMethod -Uri "https://api.nuget.org/v3-flatcontainer/$id/index.json" -UseBasicParsing
        return ($result.versions | Where-Object { $_ -notmatch '-' } | Select-Object -Last 1)
    } catch {
        return $null
    }
}

function Resolve-PackageVersion {
    param([string]$PackageId, [string]$VersionSpec)

    if (-not $VersionSpec) {
        return Get-LatestNuGetVersion -PackageId $PackageId
    }

    # Extrai o primeiro numero de versao da spec (ex: "[1.2.3, 2.0.0)" -> "1.2.3")
    if ($VersionSpec -match '(\d+\.\d+[\.\d]*)') {
        return $Matches[1]
    }

    return Get-LatestNuGetVersion -PackageId $PackageId
}

function Install-NuGetPackage {
    param(
        [string]$PackageId,
        [string]$Version,
        [string]$LibPath,
        [string[]]$TargetFrameworks
    )

    $id  = $PackageId.ToLower()
    $url = "https://api.nuget.org/v3-flatcontainer/$id/$Version/$id.$Version.nupkg"

    try {
        $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) "$id.$Version.nupkg"
        Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing

        $zip = [System.IO.Compression.ZipFile]::OpenRead($tempFile)

        # Extrai DLLs para o target framework mais especifico disponivel
        foreach ($tf in $TargetFrameworks) {
            $dlls = @($zip.Entries | Where-Object { $_.FullName -like "lib/$tf/*.dll" })
            if ($dlls.Count -gt 0) {
                foreach ($dll in $dlls) {
                    $dest = Join-Path $LibPath $dll.Name
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($dll, $dest, $true)
                }
                break
            }
        }

        # Extrai dependencias do .nuspec embutido no .nupkg
        $deps = @()
        $nuspecEntry = $zip.Entries | Where-Object { $_.Name -like '*.nuspec' } | Select-Object -First 1
        if ($nuspecEntry) {
            $reader  = [System.IO.StreamReader]::new($nuspecEntry.Open())
            $content = $reader.ReadToEnd()
            $reader.Close()

            $content = $content -replace ' xmlns="[^"]*"', ''
            [xml]$nuspec = $content
            $deps = Get-DepsFromNuspec -Nuspec $nuspec -TargetFrameworks $TargetFrameworks
        }

        $zip.Dispose()
        Remove-Item $tempFile -ErrorAction SilentlyContinue

        return [PSCustomObject]@{ Dependencies = $deps }
    } catch {
        Write-Warning "  Falha ao baixar $PackageId $Version`: $_"
        return [PSCustomObject]@{ Dependencies = @() }
    }
}

function Get-DepsFromNuspec {
    param([xml]$Nuspec, [string[]]$TargetFrameworks)

    $depGroups = $Nuspec.package.metadata.dependencies.group

    if (-not $depGroups) {
        return @($Nuspec.package.metadata.dependencies.dependency) |
            Where-Object { $_ } |
            ForEach-Object { [PSCustomObject]@{ Id = $_.id; Version = $_.version } }
    }

    foreach ($tf in $TargetFrameworks) {
        $group = @($depGroups) | Where-Object { $_.targetFramework -like "*$tf*" } | Select-Object -First 1
        if ($group) {
            return @($group.dependency) |
                Where-Object { $_ } |
                ForEach-Object { [PSCustomObject]@{ Id = $_.id; Version = $_.version } }
        }
    }

    # Fallback: grupo sem targetFramework ou o primeiro disponivel
    $fallback = (@($depGroups) | Where-Object { -not $_.targetFramework } | Select-Object -First 1)
    if (-not $fallback) { $fallback = @($depGroups)[0] }

    return @($fallback.dependency) |
        Where-Object { $_ } |
        ForEach-Object { [PSCustomObject]@{ Id = $_.id; Version = $_.version } }
}
