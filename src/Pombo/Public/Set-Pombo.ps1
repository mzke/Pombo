function Set-Pombo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$InputObject,

        [Parameter(Mandatory)]
        [string]$Collection
    )

    process {
        $idProp = $InputObject.PSObject.Properties |
            Where-Object { $_.Name -in @('id', 'Id', 'ID') } |
            Select-Object -First 1

        if (-not $idProp) {
            throw "O objeto nao possui propriedade 'ID', 'Id' ou 'id'."
        }

        $oid    = [MongoDB.Bson.ObjectId]::Parse($idProp.Value.ToString())
        $filter = [MongoDB.Bson.BsonDocument]::new('_id', [MongoDB.Bson.BsonObjectId]::new($oid))
        $doc    = ConvertTo-BsonDocument -Object $InputObject

        $col = Get-PomboCollection -Collection $Collection
        [PomboHelper]::ReplaceOne($col, $filter, $doc)
    }
}
