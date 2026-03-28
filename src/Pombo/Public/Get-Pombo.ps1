function Get-Pombo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Collection,

        [Parameter()]
        [string]$ID
    )

    $col = Get-PomboCollection -Collection $Collection

    if ($ID) {
        $oid    = [MongoDB.Bson.ObjectId]::Parse($ID)
        $filter = [MongoDB.Bson.BsonDocument]::new('_id', [MongoDB.Bson.BsonObjectId]::new($oid))
        $cursor = [PomboHelper]::FindById($col, $filter)
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
