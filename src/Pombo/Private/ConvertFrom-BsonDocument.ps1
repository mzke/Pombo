function ConvertFrom-BsonDocument {
    param(
        [Parameter(Mandatory)]
        $Document
    )

    $result = [ordered]@{}

    foreach ($element in $Document.Elements) {
        $name          = if ($element.Name -eq '_id') { 'ID' } else { $element.Name }
        $result[$name] = ConvertFrom-BsonValue -Value $element.Value
    }

    return [PSCustomObject]$result
}

function ConvertFrom-BsonValue {
    param($Value)

    switch ($Value.BsonType.ToString()) {
        'Document'   { return ConvertFrom-BsonDocument -Document $Value }
        'Array'      { return @($Value.Values | ForEach-Object { ConvertFrom-BsonValue -Value $_ }) }
        'ObjectId'   { return $Value.AsObjectId.ToString() }
        'Boolean'    { return $Value.AsBoolean }
        'DateTime'   { return $Value.ToUniversalTime() }
        'Int32'      { return $Value.AsInt32 }
        'Int64'      { return $Value.AsInt64 }
        'Double'     { return $Value.AsDouble }
        'Decimal128' { return [decimal]::Parse($Value.AsDecimal128.ToString()) }
        'String'     { return $Value.AsString }
        'Null'       { return $null }
        'Undefined'  { return $null }
        default      { return $Value.ToString() }
    }
}
