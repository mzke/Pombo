#Requires -Modules Pester

# Import no escopo do script: roda durante a discovery do Pester,
# garantindo que InModuleScope encontre o modulo ao registrar os testes.
$modulePath = Join-Path $PSScriptRoot '../src/Pombo/Pombo.psd1'
Import-Module $modulePath -Force

# BeforeAll: roda antes da execucao dos testes, garantindo que o modulo
# e os assemblies do MongoDB estejam carregados na fase de run.
BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../src/Pombo/Pombo.psd1') -Force
}

# ---------------------------------------------------------------------------
# ConvertTo-BsonDocument
# ---------------------------------------------------------------------------
Describe 'ConvertTo-BsonDocument' -Tag 'Unit' {
    InModuleScope 'Pombo' {

        It 'converte string para BsonString' {
            $doc = ConvertTo-BsonDocument -Object ([PSCustomObject]@{ Nome = 'Richard' })
            $doc['Nome'].BsonType.ToString() | Should -Be 'String'
            $doc['Nome'].AsString           | Should -Be 'Richard'
        }

        It 'converte Int32 para BsonInt32' {
            $doc = ConvertTo-BsonDocument -Object ([PSCustomObject]@{ Idade = [int]30 })
            $doc['Idade'].BsonType.ToString() | Should -Be 'Int32'
            $doc['Idade'].AsInt32            | Should -Be 30
        }

        It 'converte Int64 para BsonInt64' {
            $doc = ConvertTo-BsonDocument -Object ([PSCustomObject]@{ Contador = [long]9999999999 })
            $doc['Contador'].BsonType.ToString() | Should -Be 'Int64'
            $doc['Contador'].AsInt64            | Should -Be 9999999999
        }

        It 'converte Double para BsonDouble' {
            $doc = ConvertTo-BsonDocument -Object ([PSCustomObject]@{ Preco = [double]9.99 })
            $doc['Preco'].BsonType.ToString() | Should -Be 'Double'
            $doc['Preco'].AsDouble           | Should -Be 9.99
        }

        It 'converte Boolean para BsonBoolean' {
            $doc = ConvertTo-BsonDocument -Object ([PSCustomObject]@{ Ativo = $true })
            $doc['Ativo'].BsonType.ToString() | Should -Be 'Boolean'
            $doc['Ativo'].AsBoolean          | Should -BeTrue
        }

        It 'converte null para BsonNull' {
            $doc = ConvertTo-BsonDocument -Object ([PSCustomObject]@{ Vazio = $null })
            $doc['Vazio'].BsonType.ToString() | Should -Be 'Null'
        }

        It 'converte propriedade ID para _id como ObjectId' {
            $id  = '507f1f77bcf86cd799439011'
            $doc = ConvertTo-BsonDocument -Object ([PSCustomObject]@{ ID = $id; Nome = 'Ana' })
            $doc.Contains('_id')               | Should -BeTrue
            $doc['_id'].BsonType.ToString()    | Should -Be 'ObjectId'
            $doc['_id'].AsObjectId.ToString()  | Should -Be $id
        }

        It 'nao adiciona _id quando ID e nulo ou vazio' {
            $doc = ConvertTo-BsonDocument -Object ([PSCustomObject]@{ ID = $null; Nome = 'Sem ID' })
            $doc.Contains('_id') | Should -BeFalse
        }

        It 'converte sufixo Id para ObjectId' {
            $id  = '507f1f77bcf86cd799439011'
            $doc = ConvertTo-BsonDocument -Object ([PSCustomObject]@{ ClienteId = $id })
            $doc['ClienteId'].BsonType.ToString() | Should -Be 'ObjectId'
            $doc['ClienteId'].AsObjectId.ToString() | Should -Be $id
        }

        It 'nao converte string sem formato ObjectId como ObjectId' {
            $doc = ConvertTo-BsonDocument -Object ([PSCustomObject]@{ ClienteId = 'nao-e-um-objectid' })
            $doc['ClienteId'].BsonType.ToString() | Should -Be 'String'
        }

        It 'converte PSCustomObject aninhado para BsonDocument' {
            $obj = [PSCustomObject]@{
                Endereco = [PSCustomObject]@{ Cidade = 'Blumenau' }
            }
            $doc = ConvertTo-BsonDocument -Object $obj
            $doc['Endereco'].BsonType.ToString()       | Should -Be 'Document'
            $doc['Endereco']['Cidade'].AsString        | Should -Be 'Blumenau'
        }

        It 'converte array para BsonArray' {
            $obj = [PSCustomObject]@{ Tags = @('a', 'b', 'c') }
            $doc = ConvertTo-BsonDocument -Object $obj
            $doc['Tags'].BsonType.ToString()    | Should -Be 'Array'
            $doc['Tags'].Values.Count           | Should -Be 3
            $doc['Tags'][0].AsString            | Should -Be 'a'
        }

        It 'retorna BsonDocument (nao System.Object[])' {
            $doc = ConvertTo-BsonDocument -Object ([PSCustomObject]@{ Nome = 'Teste' })
            # Nao usa pipeline: BsonDocument implementa IEnumerable<BsonElement> e seria
            # desfeito em elementos antes de chegar ao Should
            ($doc -is [MongoDB.Bson.BsonDocument]) | Should -BeTrue
        }
    }
}

# ---------------------------------------------------------------------------
# ConvertFrom-BsonDocument
# ---------------------------------------------------------------------------
Describe 'ConvertFrom-BsonDocument' -Tag 'Unit' {
    InModuleScope 'Pombo' {

        It 'converte _id para propriedade ID como string' {
            $oid = [MongoDB.Bson.ObjectId]::GenerateNewId()
            $doc = [MongoDB.Bson.BsonDocument]::new()
            $null = $doc.Add('_id', [MongoDB.Bson.BsonObjectId]::new($oid))
            $obj  = ConvertFrom-BsonDocument -Document $doc
            $obj.ID | Should -Be $oid.ToString()
        }

        It 'converte BsonString para string' {
            $doc = [MongoDB.Bson.BsonDocument]::new()
            $null = $doc.Add('Nome', [MongoDB.Bson.BsonString]::new('Richard'))
            $obj  = ConvertFrom-BsonDocument -Document $doc
            $obj.Nome             | Should -Be 'Richard'
            $obj.Nome             | Should -BeOfType [string]
        }

        It 'converte BsonInt32 para int' {
            $doc = [MongoDB.Bson.BsonDocument]::new()
            $null = $doc.Add('Idade', [MongoDB.Bson.BsonInt32]::new(30))
            $obj  = ConvertFrom-BsonDocument -Document $doc
            $obj.Idade | Should -Be 30
        }

        It 'converte BsonInt64 para long' {
            $doc = [MongoDB.Bson.BsonDocument]::new()
            $null = $doc.Add('Contador', [MongoDB.Bson.BsonInt64]::new(9999999999))
            $obj  = ConvertFrom-BsonDocument -Document $doc
            $obj.Contador | Should -Be 9999999999
        }

        It 'converte BsonDouble para double' {
            $doc = [MongoDB.Bson.BsonDocument]::new()
            $null = $doc.Add('Preco', [MongoDB.Bson.BsonDouble]::new(9.99))
            $obj  = ConvertFrom-BsonDocument -Document $doc
            $obj.Preco | Should -Be 9.99
        }

        It 'converte BsonBoolean para bool' {
            $doc = [MongoDB.Bson.BsonDocument]::new()
            $null = $doc.Add('Ativo', [MongoDB.Bson.BsonBoolean]::new($true))
            $obj  = ConvertFrom-BsonDocument -Document $doc
            $obj.Ativo | Should -BeTrue
        }

        It 'converte BsonNull para null' {
            $doc = [MongoDB.Bson.BsonDocument]::new()
            $null = $doc.Add('Vazio', [MongoDB.Bson.BsonNull]::Value)
            $obj  = ConvertFrom-BsonDocument -Document $doc
            $obj.Vazio | Should -BeNullOrEmpty
        }

        It 'converte BsonDocument aninhado para PSCustomObject' {
            $inner = [MongoDB.Bson.BsonDocument]::new()
            $null  = $inner.Add('Cidade', [MongoDB.Bson.BsonString]::new('Blumenau'))
            $outer = [MongoDB.Bson.BsonDocument]::new()
            $null  = $outer.Add('Endereco', $inner)
            $obj   = ConvertFrom-BsonDocument -Document $outer
            $obj.Endereco        | Should -BeOfType [PSCustomObject]
            $obj.Endereco.Cidade | Should -Be 'Blumenau'
        }

        It 'converte BsonArray para array PowerShell' {
            $arr  = [MongoDB.Bson.BsonArray]::new()
            $null = $arr.Add([MongoDB.Bson.BsonString]::new('x'))
            $null = $arr.Add([MongoDB.Bson.BsonString]::new('y'))
            $doc  = [MongoDB.Bson.BsonDocument]::new()
            $null = $doc.Add('Itens', $arr)
            $obj  = ConvertFrom-BsonDocument -Document $doc
            $obj.Itens        | Should -HaveCount 2
            $obj.Itens[0]     | Should -Be 'x'
            $obj.Itens[1]     | Should -Be 'y'
        }

        It 'retorna PSCustomObject' {
            $doc = [MongoDB.Bson.BsonDocument]::new()
            $null = $doc.Add('Nome', [MongoDB.Bson.BsonString]::new('Teste'))
            $obj  = ConvertFrom-BsonDocument -Document $doc
            $obj  | Should -BeOfType [PSCustomObject]
        }
    }
}

# ---------------------------------------------------------------------------
# Validacao de entrada (sem conexao MongoDB)
# ---------------------------------------------------------------------------
Describe 'Set-Pombo — validacao' -Tag 'Unit' {
    InModuleScope 'Pombo' {
        It 'lanca erro quando objeto nao tem propriedade ID' {
            Mock Get-PomboCollection { throw 'nao deve ser chamado' }
            $obj = [PSCustomObject]@{ Nome = 'Sem ID' }
            { $obj | Set-Pombo -Collection 'col' } | Should -Throw "*nao possui propriedade*"
        }
    }
}

Describe 'Remove-Pombo — validacao' -Tag 'Unit' {
    InModuleScope 'Pombo' {
        It 'lanca erro quando objeto nao tem propriedade ID' {
            Mock Get-PomboCollection { throw 'nao deve ser chamado' }
            $obj = [PSCustomObject]@{ Nome = 'Sem ID' }
            { $obj | Remove-Pombo -Collection 'col' } | Should -Throw "*nao possui propriedade*"
        }
    }
}

Describe 'Get-PomboCollection — validacao' -Tag 'Unit' {
    InModuleScope 'Pombo' {
        It 'lanca erro quando variavel POMBO nao esta definida' {
            $prev      = $env:POMBO
            $env:POMBO = $null
            try {
                { Get-PomboCollection -Collection 'col' } | Should -Throw "*POMBO*"
            } finally {
                $env:POMBO = $prev
            }
        }
    }
}

Describe 'Get-Pombo — validacao' -Tag 'Unit' {
    InModuleScope 'Pombo' {
        It 'lanca erro quando ID nao e um ObjectId valido' {
            Mock Get-PomboCollection { }
            { Get-Pombo -Collection 'col' -ID 'nao-e-um-objectid' } | Should -Throw
        }
    }
}

# ---------------------------------------------------------------------------
# Testes de integracao — requerem $env:POMBO apontando para MongoDB real
# ---------------------------------------------------------------------------
Describe 'Integracao CRUD' -Tag 'Integration' -Skip:(-not $env:POMBO) {

    BeforeAll {
        $script:TestCol = '_pombo_test_'
        # Remove documentos residuais de execucoes anteriores
        Get-Pombo -Collection $script:TestCol -ErrorAction SilentlyContinue |
            ForEach-Object { $_ | Remove-Pombo -Collection $script:TestCol -ErrorAction SilentlyContinue }
    }

    AfterAll {
        Get-Pombo -Collection $script:TestCol -ErrorAction SilentlyContinue |
            ForEach-Object { $_ | Remove-Pombo -Collection $script:TestCol -ErrorAction SilentlyContinue }
    }

    It 'New-Pombo insere documento e retorna objeto com ID gerado' {
        $obj    = [PSCustomObject]@{ Nome = 'Pester'; Valor = 42; Ativo = $true }
        $result = $obj | New-Pombo -Collection $script:TestCol

        $result             | Should -Not -BeNullOrEmpty
        $result             | Should -BeOfType [PSCustomObject]
        $result.ID          | Should -Not -BeNullOrEmpty
        $result.ID          | Should -Match '^[0-9a-fA-F]{24}$'
        $result.Nome        | Should -Be 'Pester'
        $result.Valor       | Should -Be 42
        $result.Ativo       | Should -BeTrue

        $script:InsertedID = $result.ID
    }

    It 'Get-Pombo retorna documento inserido' {
        $docs  = Get-Pombo -Collection $script:TestCol
        $found = $docs | Where-Object { $_.ID -eq $script:InsertedID }

        $found       | Should -Not -BeNullOrEmpty
        $found.Nome  | Should -Be 'Pester'
        $found.Valor | Should -Be 42
    }

    It 'Get-Pombo -ID retorna documento especifico' {
        $result = Get-Pombo -Collection $script:TestCol -ID $script:InsertedID

        $result      | Should -Not -BeNullOrEmpty
        $result.ID   | Should -Be $script:InsertedID
        $result.Nome | Should -Be 'Pester'
    }

    It 'Get-Pombo -ID retorna vazio para ID inexistente' {
        $fakeId = '000000000000000000000001'
        $result = Get-Pombo -Collection $script:TestCol -ID $fakeId

        $result | Should -BeNullOrEmpty
    }

    It 'Set-Pombo atualiza documento existente' {
        $obj = [PSCustomObject]@{ ID = $script:InsertedID; Nome = 'Pester Atualizado'; Valor = 99 }
        { $obj | Set-Pombo -Collection $script:TestCol } | Should -Not -Throw

        $updated = Get-Pombo -Collection $script:TestCol | Where-Object { $_.ID -eq $script:InsertedID }
        $updated.Nome  | Should -Be 'Pester Atualizado'
        $updated.Valor | Should -Be 99
    }

    It 'Remove-Pombo remove documento por PSCustomObject' {
        $obj = [PSCustomObject]@{ ID = $script:InsertedID }
        { $obj | Remove-Pombo -Collection $script:TestCol } | Should -Not -Throw

        $found = Get-Pombo -Collection $script:TestCol | Where-Object { $_.ID -eq $script:InsertedID }
        $found | Should -BeNullOrEmpty
    }

    It 'Remove-Pombo remove documento por string de ID' {
        $inserted = [PSCustomObject]@{ Nome = 'ParaRemover'; Valor = 1 } |
                        New-Pombo -Collection $script:TestCol

        { $inserted.ID | Remove-Pombo -Collection $script:TestCol } | Should -Not -Throw

        $found = Get-Pombo -Collection $script:TestCol | Where-Object { $_.ID -eq $inserted.ID }
        $found | Should -BeNullOrEmpty
    }

    It 'New-Pombo preserva documento aninhado' {
        $obj = [PSCustomObject]@{
            Nome     = 'Aninhado'
            Endereco = [PSCustomObject]@{ Rua = 'Rua das Flores'; Cidade = 'Blumenau' }
            Itens    = @('A', 'B', 'C')
        }
        $result = $obj | New-Pombo -Collection $script:TestCol

        $result.Endereco        | Should -BeOfType [PSCustomObject]
        $result.Endereco.Cidade | Should -Be 'Blumenau'
        $result.Itens           | Should -HaveCount 3
        $result.Itens[1]        | Should -Be 'B'

        # Limpa
        $result | Remove-Pombo -Collection $script:TestCol
    }

    It 'New-Pombo preserva ClienteId como ObjectId (roundtrip)' {
        $clienteId = '507f1f77bcf86cd799439011'
        $obj       = [PSCustomObject]@{ Nome = 'ComFK'; ClienteId = $clienteId }
        $result    = $obj | New-Pombo -Collection $script:TestCol

        $result.ClienteId | Should -Be $clienteId

        $result | Remove-Pombo -Collection $script:TestCol
    }
}
