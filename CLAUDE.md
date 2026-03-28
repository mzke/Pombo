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