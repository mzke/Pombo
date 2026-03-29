function ConvertTo-MongoFilter {
    param(
        [Parameter(Mandatory)]
        [ScriptBlock]$Filter
    )

    $stmts = $Filter.Ast.EndBlock.Statements
    if ($stmts.Count -ne 1) {
        throw "O filtro deve conter uma unica expressao booleana."
    }

    $pipeline = $stmts[0]
    if ($pipeline -isnot [System.Management.Automation.Language.PipelineAst] -or
        $pipeline.PipelineElements.Count -ne 1 -or
        $pipeline.PipelineElements[0] -isnot [System.Management.Automation.Language.CommandExpressionAst]) {
        throw "O filtro deve ser uma expressao de comparacao (ex: { `$_.Campo -eq 'valor' })."
    }

    Write-Output -NoEnumerate (Invoke-FilterAstNode -Node $pipeline.PipelineElements[0].Expression)
}

function Invoke-FilterAstNode {
    param($Node)

    if ($Node -isnot [System.Management.Automation.Language.BinaryExpressionAst]) {
        throw "Expressao invalida no filtro: '$($Node.Extent.Text)'. Use operadores de comparacao (-eq, -gt, etc.) ou logicos (-and, -or)."
    }

    $op = $Node.Operator.ToString()

    # -and / -or: recursao nos dois lados
    if ($op -in 'And', 'Or') {
        $left    = Invoke-FilterAstNode -Node $Node.Left
        $right   = Invoke-FilterAstNode -Node $Node.Right
        $mongoOp = if ($op -eq 'And') { '$and' } else { '$or' }
        $arr = [MongoDB.Bson.BsonArray]::new()
        $arr.Add($left)  | Out-Null
        $arr.Add($right) | Out-Null
        Write-Output -NoEnumerate ([MongoDB.Bson.BsonDocument]::new($mongoOp, $arr))
        return
    }

    $fieldName  = Get-FilterFieldName -Node $Node.Left
    $mongoField = if ($fieldName -in 'id', 'Id', 'ID') { '_id' } else { $fieldName }

    # -like / -notlike: converte wildcard do PowerShell para regex
    # BsonDocument implementa IEnumerable<BsonElement> — usar .Add() evita que o PS
    # desenrole o objeto no pipeline ao atribuir via expressao if-else.
    if ($op -in 'Ilike', 'Clike', 'Inotlike', 'Cnotlike') {
        $regexStr = ConvertFrom-LikePattern -Pattern (Get-FilterLiteralString -Node $Node.Right)
        $regexDoc = [MongoDB.Bson.BsonDocument]::new()
        $regexDoc.Add('$regex', [MongoDB.Bson.BsonString]::new($regexStr)) | Out-Null
        $result = [MongoDB.Bson.BsonDocument]::new()
        if ($op -in 'Inotlike', 'Cnotlike') {
            $notDoc = [MongoDB.Bson.BsonDocument]::new()
            $notDoc.Add('$not', $regexDoc) | Out-Null
            $result.Add($mongoField, $notDoc) | Out-Null
        } else {
            $result.Add($mongoField, $regexDoc) | Out-Null
        }
        Write-Output -NoEnumerate $result
        return
    }

    # -match / -notmatch: usa o valor como padrao regex literal
    if ($op -in 'Imatch', 'Cmatch', 'Inotmatch', 'Cnotmatch') {
        $regexStr = Get-FilterLiteralString -Node $Node.Right
        $regexDoc = [MongoDB.Bson.BsonDocument]::new()
        $regexDoc.Add('$regex', [MongoDB.Bson.BsonString]::new($regexStr)) | Out-Null
        $result = [MongoDB.Bson.BsonDocument]::new()
        if ($op -in 'Inotmatch', 'Cnotmatch') {
            $notDoc = [MongoDB.Bson.BsonDocument]::new()
            $notDoc.Add('$not', $regexDoc) | Out-Null
            $result.Add($mongoField, $notDoc) | Out-Null
        } else {
            $result.Add($mongoField, $regexDoc) | Out-Null
        }
        Write-Output -NoEnumerate $result
        return
    }

    # Comparacao e inclusao
    $opMap = @{
        'Ieq'    = '$eq';  'Ceq'    = '$eq'
        'Ine'    = '$ne';  'Cne'    = '$ne'
        'Igt'    = '$gt';  'Cgt'    = '$gt'
        'Ige'    = '$gte'; 'Cge'    = '$gte'
        'Ilt'    = '$lt';  'Clt'    = '$lt'
        'Ile'    = '$lte'; 'Cle'    = '$lte'
        'Iin'    = '$in';  'Cin'    = '$in'
        'Inotin' = '$nin'; 'Cnotin' = '$nin'
    }

    if (-not $opMap.ContainsKey($op)) {
        throw "Operador '$op' nao suportado no filtro Pombo."
    }

    $mongoOp   = $opMap[$op]
    $bsonValue = Get-FilterBsonValue -Node $Node.Right -FieldName $fieldName
    $fieldDoc  = [MongoDB.Bson.BsonDocument]::new($mongoOp, $bsonValue)
    Write-Output -NoEnumerate ([MongoDB.Bson.BsonDocument]::new($mongoField, $fieldDoc))
}

function Get-FilterFieldName {
    param($Node)

    if ($Node -isnot [System.Management.Automation.Language.MemberExpressionAst]) {
        throw "O lado esquerdo deve ser uma propriedade de '`$_' (ex: `$_.Nome). Encontrado: '$($Node.Extent.Text)'"
    }

    $parts   = [System.Collections.Generic.List[string]]::new()
    $current = $Node

    while ($current -is [System.Management.Automation.Language.MemberExpressionAst]) {
        $parts.Insert(0, $current.Member.Value)
        $current = $current.Expression
    }

    if ($current -isnot [System.Management.Automation.Language.VariableExpressionAst] -or
        $current.VariablePath.UserPath -ne '_') {
        throw "O lado esquerdo deve comecar com '`$_' (ex: `$_.Nome). Encontrado: '$($Node.Extent.Text)'"
    }

    return $parts -join '.'
}

function Get-FilterBsonValue {
    param($Node, [string]$FieldName)

    # 'a', 'b' → ArrayLiteralAst
    # @('a', 'b') → ArrayExpressionAst cujo corpo contem um ArrayLiteralAst
    $elements = $null
    if ($Node -is [System.Management.Automation.Language.ArrayLiteralAst]) {
        $elements = $Node.Elements
    } elseif ($Node -is [System.Management.Automation.Language.ArrayExpressionAst]) {
        $inner = $Node.SubExpression.Statements
        if ($inner.Count -eq 1 -and
            $inner[0] -is [System.Management.Automation.Language.PipelineAst] -and
            $inner[0].PipelineElements[0] -is [System.Management.Automation.Language.CommandExpressionAst] -and
            $inner[0].PipelineElements[0].Expression -is [System.Management.Automation.Language.ArrayLiteralAst]) {
            $elements = $inner[0].PipelineElements[0].Expression.Elements
        }
    }

    if ($null -ne $elements) {
        $arr = [MongoDB.Bson.BsonArray]::new()
        foreach ($elem in $elements) {
            $arr.Add((Get-FilterScalarBsonValue -Node $elem -FieldName $FieldName)) | Out-Null
        }
        Write-Output -NoEnumerate $arr
        return
    }

    Get-FilterScalarBsonValue -Node $Node -FieldName $FieldName
}

function Get-FilterScalarBsonValue {
    param($Node, [string]$FieldName)

    $value = Get-FilterLiteralValue -Node $Node

    if ($null -eq $value) {
        return [MongoDB.Bson.BsonNull]::Value
    }

    # Deteccao de ObjectId: mesmo criterio de ConvertTo-BsonDocument
    if ($FieldName -match '(id|Id|ID)$' -and $value -is [string] -and $value -match '^[0-9a-fA-F]{24}$') {
        return [MongoDB.Bson.BsonObjectId]::new([MongoDB.Bson.ObjectId]::Parse($value))
    }

    switch ($value.GetType().Name) {
        'String'   { return [MongoDB.Bson.BsonString]::new($value) }
        'Int16'    { return [MongoDB.Bson.BsonInt32]::new([int]$value) }
        'Int32'    { return [MongoDB.Bson.BsonInt32]::new($value) }
        'Int64'    { return [MongoDB.Bson.BsonInt64]::new($value) }
        'Single'   { return [MongoDB.Bson.BsonDouble]::new([double]$value) }
        'Double'   { return [MongoDB.Bson.BsonDouble]::new($value) }
        'Decimal'  { return [MongoDB.Bson.BsonDecimal128]::new([MongoDB.Bson.Decimal128]::Parse($value.ToString())) }
        'Boolean'  { return [MongoDB.Bson.BsonBoolean]::new($value) }
        'DateTime' { return [MongoDB.Bson.BsonDateTime]::new($value) }
        default    { return [MongoDB.Bson.BsonString]::new($value.ToString()) }
    }
}

function Get-FilterLiteralValue {
    param($Node)

    # $true, $false, $null sao VariableExpressionAst no PowerShell
    if ($Node -is [System.Management.Automation.Language.VariableExpressionAst]) {
        switch ($Node.VariablePath.UserPath.ToLower()) {
            'true'  { return $true }
            'false' { return $false }
            'null'  { return $null }
            default { throw "Variaveis externas nao sao suportadas: '`$$($Node.VariablePath.UserPath)'. Use apenas literais." }
        }
    }

    if ($Node -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
        $Node -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
        return $Node.Value
    }

    if ($Node -is [System.Management.Automation.Language.ConstantExpressionAst]) {
        return $Node.Value
    }

    throw "Valor invalido no filtro: '$($Node.Extent.Text)'. Use literais (strings, numeros, booleanos, arrays)."
}

function Get-FilterLiteralString {
    param($Node)
    $value = Get-FilterLiteralValue -Node $Node
    if ($value -isnot [string]) {
        throw "O operador requer um valor de string. Encontrado: '$($Node.Extent.Text)'"
    }
    return $value
}

function ConvertFrom-LikePattern {
    param([string]$Pattern)
    # Escapa metacaracteres de regex, depois desfaz o escape de * e ? para equivalentes regex
    $escaped = [System.Text.RegularExpressions.Regex]::Escape($Pattern)
    $regex   = $escaped -replace '\\\*', '.*' -replace '\\\?', '.'
    return "^$regex$"
}
