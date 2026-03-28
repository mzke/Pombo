function ConvertTo-BsonDocument {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Object
    )

    $doc = [MongoDB.Bson.BsonDocument]::new()

    $null = foreach ($prop in $Object.PSObject.Properties) {
        $name  = $prop.Name
        $value = $prop.Value

        if ($name -in @('id', 'Id', 'ID')) {
            if ($value) {
                $oid = [MongoDB.Bson.ObjectId]::Parse($value.ToString())
                $doc.Add('_id', [MongoDB.Bson.BsonObjectId]::new($oid))
            }
            continue
        }

        $doc.Add($name, (ConvertTo-BsonValue -Name $name -Value $value))
    }

    # BsonDocument implementa IEnumerable<BsonElement> — Write-Output -NoEnumerate
    # impede o PowerShell de "desenrolar" o documento em seus elementos
    Write-Output -NoEnumerate $doc
}

function ConvertTo-BsonValue {
    param(
        [string]$Name,
        $Value
    )

    if ($null -eq $Value) {
        return [MongoDB.Bson.BsonNull]::Value
    }

    if ($Value -is [PSCustomObject]) {
        # Usa Write-Output -NoEnumerate para preservar o BsonDocument aninhado
        Write-Output -NoEnumerate (ConvertTo-BsonDocument -Object $Value)
        return
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $arr = [MongoDB.Bson.BsonArray]::new()
        $null = foreach ($item in $Value) {
            $arr.Add((ConvertTo-BsonValue -Name $Name -Value $item))
        }
        # BsonArray tambem implementa IEnumerable<BsonValue>
        Write-Output -NoEnumerate $arr
        return
    }

    # Propriedades com sufixo id/Id/ID e valor que parece ObjectId
    if ($Name -match '(id|Id|ID)$' -and $Value -is [string] -and $Value -match '^[0-9a-fA-F]{24}$') {
        return [MongoDB.Bson.BsonObjectId]::new([MongoDB.Bson.ObjectId]::Parse($Value))
    }

    switch ($Value.GetType().Name) {
        'String'   { return [MongoDB.Bson.BsonString]::new($Value) }
        'Int16'    { return [MongoDB.Bson.BsonInt32]::new([int]$Value) }
        'Int32'    { return [MongoDB.Bson.BsonInt32]::new($Value) }
        'Int64'    { return [MongoDB.Bson.BsonInt64]::new($Value) }
        'Single'   { return [MongoDB.Bson.BsonDouble]::new([double]$Value) }
        'Double'   { return [MongoDB.Bson.BsonDouble]::new($Value) }
        'Decimal'  { return [MongoDB.Bson.BsonDecimal128]::new([MongoDB.Bson.Decimal128]::Parse($Value.ToString())) }
        'Boolean'  { return [MongoDB.Bson.BsonBoolean]::new($Value) }
        'DateTime' { return [MongoDB.Bson.BsonDateTime]::new($Value) }
        default    { return [MongoDB.Bson.BsonString]::new($Value.ToString()) }
    }
}
