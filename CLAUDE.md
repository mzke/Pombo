# Pombo
Powershell MongoDB Objects

Modulo para Powershell que abstrai operações de banco de dados MongoDB para objetos `PSCustomObject` do Powershell.

Utiliza o driver para C#/.NET MongoDB.Driver

A string de conexão deve ser obtida de uma variável de ambiente chamada `POMBO`

## Convenções

- Entradas e saídas de operações são sempre `PSCustomObjects` do Poweshell.

- Propriedade com nome `id`, `Id` ou `ID` em um `PSCustomObject` devem ser tratados como tipo ObjectId do MongoDB.

- Propriedade com sufixo `id`, `Id` ou `ID` em um `PSCustomObject` devem ser tratados como tipo ObjectId do MongoDB.

## CmdLets

### New-Pombo

Inseri um `PSCustomObject` recebido pela pipeline como um novo documento em uma coleção do MongoDB.

```
$pessoa = [PSCustomObject]@{
    Nome  = "Richard"
    Idade = 30
    Cidade = "Blumenau"
}

$pessoa | New-Pombo -Collection pessoas
```

### Set-Pombo

Atualiza um documento do MongoDB a partir do `ID` de um `PSCustomObject`. 

```
$pessoa = [PSCustomObject]@{
    ID = "1234567890"
    Nome  = "Richard"
    Idade = 30
    Cidade = "Blumenau"
}

$pessoa | Set-Pombo -Collection pessoas
```

### Remove-Pombo

Remove um documento do MongoDB a partir do `ID` de um `PSCustomObject` ou `string`. 

```
$pessoa = [PSCustomObject]@{
    ID = "1234567890"
    Nome  = "Richard"
    Idade = 30
    Cidade = "Blumenau"
}

$pessoa | Remove-Pombo -Collection pessoas

$pessoaID = "1234567890"
$pessoaID | Remove-Pombo -Collection pessoas

```

### Get-Pombo

Obtem uma lista de documento do MongoDB como lista de `PSCustomObject`.

```
$pessoas = Get-Pombo -Collection pessoas
```

Use `-ID` para buscar um único documento pelo ObjectId:

```
$pessoa = Get-Pombo -Collection pessoas -ID "507f1f77bcf86cd799439011"
```

Use `-Filter` com expressões PowerShell para filtrar **server-side** no MongoDB. O ScriptBlock é parseado via AST e traduzido para filtro MongoDB — nenhum documento é trazido para memória antes do filtro.

```
Get-Pombo -Collection pessoas -Filter { $_.Cidade -eq "Blumenau" }
Get-Pombo -Collection pessoas -Filter { $_.Idade -gt 25 -and $_.Ativo -eq $true }
Get-Pombo -Collection pessoas -Filter { $_.Nome -like "Rich*" }
Get-Pombo -Collection pessoas -Filter { $_.Cidade -in @("Blumenau", "Joinville") }
Get-Pombo -Collection pedidos -Filter { $_.ClienteId -eq "507f1f77bcf86cd799439011" }
```

Operadores suportados: `-eq`, `-ne`, `-gt`, `-ge`, `-lt`, `-le`, `-like`, `-notlike`, `-match`, `-notmatch`, `-in`, `-notin`, `-and`, `-or`.

Restrições do `-Filter`:
- Lado esquerdo deve ser sempre `$_.Campo` (ou `$_.Campo.SubCampo` para aninhados)
- Valores devem ser literais (`"string"`, `42`, `$true`, `$false`, `$null`, `@(...)`)
- Variáveis externas não são suportadas
- `-ID` e `-Filter` são mutuamente exclusivos