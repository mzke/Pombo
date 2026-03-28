```
        .--~~,__
:-....,-------`~~'._
 `-,,,  ,_      ;'~U'
  _,-' ,'`-__; '--.
 (_/'~~      ''''(;
```

# Pombo 🐦

**PO**werShell **M**ongoD**B** **O**bjects — Abstração de operações MongoDB para `PSCustomObject` do PowerShell.

Utiliza o driver oficial [MongoDB.Driver para .NET](https://www.nuget.org/packages/MongoDB.Driver). As dependências são baixadas automaticamente do NuGet na primeira importação.

---

## Requisitos

- PowerShell 7.4 ou superior (.NET 8+)
- Acesso à internet na primeira importação (para baixar o MongoDB.Driver)
- Uma instância MongoDB acessível

---

## Instalação

Clone o repositório e importe o módulo:

```powershell
git clone https://github.com/seu-usuario/Pombo.git
Import-Module .\Pombo\src\Pombo\Pombo.psd1
```

Na primeira importação, o módulo baixa automaticamente o `MongoDB.Driver` e suas dependências para `src/Pombo/lib/`.

---

## Configuração

Defina a string de conexão na variável de ambiente `POMBO`. O nome do banco de dados deve estar incluído na URL:

```powershell
$env:POMBO = "mongodb://localhost:27017/meu_banco"
```

Para tornar permanente, adicione ao seu `$PROFILE`.

---

## CmdLets

### `New-Pombo` — Inserir documento

Insere um `PSCustomObject` como novo documento na coleção. Retorna o objeto com o `ID` gerado pelo MongoDB.

```powershell
$pessoa = [PSCustomObject]@{
    Nome   = "Richard"
    Idade  = 30
    Cidade = "Blumenau"
}

$inserida = $pessoa | New-Pombo -Collection pessoas
$inserida.ID  # "507f1f77bcf86cd799439011"
```

### `Get-Pombo` — Buscar documentos

Retorna todos os documentos de uma coleção como lista de `PSCustomObject`.

```powershell
$pessoas = Get-Pombo -Collection pessoas
```

Use o parâmetro `-ID` para buscar um único documento pelo seu ObjectId:

```powershell
$pessoa = Get-Pombo -Collection pessoas -ID "507f1f77bcf86cd799439011"
```

Use `Where-Object` para filtrar via pipeline:

```powershell
Get-Pombo -Collection pessoas | Where-Object { $_.Cidade -eq "Blumenau" }
Get-Pombo -Collection pessoas | Where-Object { $_.Idade -gt 25 } | Sort-Object Nome
```

### `Set-Pombo` — Atualizar documento

Substitui um documento no MongoDB pelo `ID` presente no objeto. A propriedade pode se chamar `ID`, `Id` ou `id`.

```powershell
$pessoa.Cidade = "Joinville"
$pessoa | Set-Pombo -Collection pessoas
```

### `Remove-Pombo` — Remover documento

Remove um documento pelo `ID`. Aceita um `PSCustomObject` ou diretamente uma string com o ID.

```powershell
# Por objeto
$pessoa | Remove-Pombo -Collection pessoas

# Por string de ID
"507f1f77bcf86cd799439011" | Remove-Pombo -Collection pessoas
```

---

## Convenções

| Comportamento | Descrição |
|---|---|
| `ID`, `Id` ou `id` | Tratado como `ObjectId` do MongoDB (`_id`) |
| Sufixo `ID`, `Id` ou `id` em qualquer propriedade | Tratado como `ObjectId` (ex: `ClienteId`) |
| Documentos aninhados | Convertidos recursivamente para `PSCustomObject` |
| Arrays | Convertidos para arrays do PowerShell |

---

## Testes

Os testes usam [Pester 5](https://pester.dev). Instale se necessário:

```powershell
Install-Module Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck
```

### Testes unitários

Não requerem conexão com MongoDB. Cobrem as funções de conversão entre `PSCustomObject` e `BsonDocument`, além da validação de entrada dos cmdlets.

```powershell
Invoke-Pester ./tests/Pombo.Tests.ps1 -Tag Unit
```

### Testes de integração

Requerem uma instância MongoDB acessível. Executam o ciclo completo de CRUD contra a coleção `_pombo_test_`, que é limpa automaticamente ao final.

```powershell
$env:POMBO = "mongodb://localhost:27017/pombo_test"
Invoke-Pester ./tests/Pombo.Tests.ps1 -Tag Integration
```

### Todos os testes

```powershell
Invoke-Pester ./tests/Pombo.Tests.ps1
```

---

## Exemplos

### Fluxo completo

```powershell
# Inserir
$doc = [PSCustomObject]@{ Nome = "Ana"; Ativo = $true }
$doc = $doc | New-Pombo -Collection usuarios

# Buscar e filtrar
Get-Pombo -Collection usuarios | Where-Object { $_.Ativo }

# Atualizar
$doc.Ativo = $false
$doc | Set-Pombo -Collection usuarios

# Remover
$doc | Remove-Pombo -Collection usuarios
```

### Objetos aninhados

```powershell
$pedido = [PSCustomObject]@{
    ClienteId = "507f1f77bcf86cd799439011"   # convertido para ObjectId
    Endereco  = [PSCustomObject]@{
        Rua    = "Rua das Flores"
        Cidade = "Blumenau"
    }
    Itens = @("Produto A", "Produto B")
}

$pedido | New-Pombo -Collection pedidos
```

### Atualizar em massa via pipeline

```powershell
Get-Pombo -Collection pessoas |
    Where-Object { $_.Cidade -eq "Blumenau" } |
    ForEach-Object { $_.Cidade = "Joinville"; $_ } |
    Set-Pombo -Collection pessoas
```
