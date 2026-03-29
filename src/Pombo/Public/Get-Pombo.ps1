function Get-Pombo {
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(Mandatory)]
        [string]$Collection,

        [Parameter(ParameterSetName = 'ById')]
        [string]$ID,

        [Parameter(ParameterSetName = 'ByFilter')]
        [ScriptBlock]$Filter
    )

    $col = Get-PomboCollection -Collection $Collection

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $oid       = [MongoDB.Bson.ObjectId]::Parse($ID)
        $filterDoc = [MongoDB.Bson.BsonDocument]::new('_id', [MongoDB.Bson.BsonObjectId]::new($oid))
        $cursor    = [PomboHelper]::FindById($col, $filterDoc)
    } elseif ($PSCmdlet.ParameterSetName -eq 'ByFilter') {
        $filterDoc = ConvertTo-MongoFilter -Filter $Filter
        $cursor    = [PomboHelper]::FindById($col, $filterDoc)
    } else {
        $cursor = [PomboHelper]::FindAll($col)
    }

    try {
        while ($cursor.MoveNext([System.Threading.CancellationToken]::None)) {
            foreach ($doc in $cursor.Current) {
                ConvertFrom-BsonDocument -Document $doc
            }
        }
    } finally {
        $cursor.Dispose()
    }
}
