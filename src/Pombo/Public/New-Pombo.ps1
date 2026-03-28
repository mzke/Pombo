function New-Pombo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$InputObject,

        [Parameter(Mandatory)]
        [string]$Collection
    )

    process {
        $col = Get-PomboCollection -Collection $Collection
        $doc = ConvertTo-BsonDocument -Object $InputObject
        [PomboHelper]::InsertOne($col, $doc)
        # O driver adiciona _id ao $doc apos InsertOne; retorna o objeto com ID gerado
        ConvertFrom-BsonDocument -Document $doc
    }
}
