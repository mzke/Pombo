$script:PomboClient           = $null
$script:PomboConnectionString = $null

function Get-PomboCollection {
    param(
        [Parameter(Mandatory)]
        [string]$Collection
    )

    $connectionString = $env:POMBO
    if (-not $connectionString) {
        throw "Variavel de ambiente 'POMBO' nao definida. Configure com a string de conexao do MongoDB (ex: mongodb://host/meu_banco)."
    }

    if ($null -eq $script:PomboClient -or $script:PomboConnectionString -ne $connectionString) {
        $script:PomboClient           = [MongoDB.Driver.MongoClient]::new($connectionString)
        $script:PomboConnectionString = $connectionString
    }

    $mongoUrl = [MongoDB.Driver.MongoUrl]::new($connectionString)
    $dbName   = $mongoUrl.DatabaseName

    if (-not $dbName) {
        throw "A string de conexao nao contem o nome do banco de dados. Exemplo: mongodb://host/meu_banco"
    }

    $database = $script:PomboClient.GetDatabase($dbName)
    return [PomboHelper]::GetCollection($database, $Collection)
}
