function Remove-Pombo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $InputObject,

        [Parameter(Mandatory)]
        [string]$Collection
    )

    process {
        if ($InputObject -is [string]) {
            $idString = $InputObject
        } elseif ($InputObject -is [PSCustomObject]) {
            $idProp = $InputObject.PSObject.Properties |
                Where-Object { $_.Name -in @('id', 'Id', 'ID') } |
                Select-Object -First 1

            if (-not $idProp) {
                throw "O objeto nao possui propriedade 'ID', 'Id' ou 'id'."
            }
            $idString = $idProp.Value.ToString()
        } else {
            $idString = $InputObject.ToString()
        }

        $oid    = [MongoDB.Bson.ObjectId]::Parse($idString)
        $filter = [MongoDB.Bson.BsonDocument]::new('_id', [MongoDB.Bson.BsonObjectId]::new($oid))

        $col = Get-PomboCollection -Collection $Collection
        [PomboHelper]::DeleteOne($col, $filter)
    }
}
