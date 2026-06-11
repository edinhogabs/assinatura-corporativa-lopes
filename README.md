# Assinatura Corporativa

Projeto PowerShell para gerar assinaturas corporativas em massa usando dados de banco via ODBC.

## O Que O Projeto Gera

Para cada colaborador retornado pela consulta, o script cria:

```text
output/assinaturas/<login>/
  Assinatura Corporativa.htm
  Assinatura Corporativa.txt
  Assinatura Corporativa.png
  imagens da pasta assets/
```

Tambem cria uma pasta consolidada somente com PNGs:

```text
output/pngs/<login>.png
```

## Estrutura Necessaria

```text
assets/
config/
database/
scripts/
templates/
.env
.gitignore
gerar-assinaturas.bat
instalar-assinatura.bat
README.md
```

## Configuracao

Copie o exemplo, se ainda nao existir `config/config.json`:

```powershell
Copy-Item .\config\config.example.json .\config\config.json
```

Configure:

```json
{
  "Database": {
    "Dsn": "NOME_DSN_ODBC",
    "User": "USUARIO_ODBC",
    "PasswordEnvironmentVariable": "RM_ORACLE_PASSWORD"
  },
  "Company": {
    "Domain": "empresa.com.br",
    "SignatureName": "Assinatura Corporativa"
  },
  "Install": {
    "SignaturesSourceFolder": "\\\\SERVIDOR\\Compartilhamento\\Assinaturas"
  },
  "Paths": {
    "AllEmployeesQueryFile": "database/consulta_colaboradores.example.sql",
    "TemplateFile": "templates/assinatura-modelo.html",
    "AssetsFolder": "assets",
    "ImageBaseUrl": "https://assinaturas.empresa.com.br",
    "LocalOutputFolder": "output/assinaturas",
    "PngOutputFolder": "output/pngs"
  }
}
```

Nao salve senha no Git. Para uso local, mantenha a senha no `.env`:

```text
RM_ORACLE_PASSWORD=SUA_SENHA
```

## Assets

Os arquivos esperados em `assets/` sao:

```text
bg.png
email.png
facebook.png
instagram.png
linkedin.png
logo-lopes.png
logo-principal.png
web.png
whats.png
```

## Consulta SQL

O arquivo `database/consulta_colaboradores.example.sql` e apenas um modelo seguro para versionamento.

Para uso real, crie sua consulta local em `database/consulta_colaboradores.sql`, ajuste `config/config.json` para apontar para ela e mantenha esse arquivo fora do Git.

Campos esperados pela automacao:

```text
NOME_ASSINATURA
FUNCAO
EMAIL_ASSINATURA
TELEFONE
SITE
```

## Execucao

Rode pelo BAT:

```powershell
.\gerar-assinaturas.bat
```

Ou diretamente pelo PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\04_gerar_assinaturas_local.ps1
```

O script consulta o arquivo definido em `Paths.AllEmployeesQueryFile`, gera todas as assinaturas e recria as pastas de saida.

Comportamento importante:

```text
1. A pasta definida em Paths.LocalOutputFolder e limpa antes da nova geracao.
2. As assinaturas faltantes sao criadas novamente.
3. As assinaturas existentes sao substituidas pela versao atual.
4. Os PNGs consolidados sao salvos em Paths.PngOutputFolder para conferencia/publicacao HTTPS.
```

Para gerar diretamente em uma pasta de rede, configure `Paths.LocalOutputFolder` com um caminho UNC:

```json
"LocalOutputFolder": "\\\\SERVIDOR\\Compartilhamento\\Assinaturas"
```

## Instalacao No Outlook Do Usuario

Para instalar a assinatura na maquina do usuario, use:

```powershell
.\instalar-assinatura.bat
```

O instalador:

```text
1. Identifica o usuario logado pelo Windows.
2. Procura a pasta correspondente em `Install.SignaturesSourceFolder`.
3. Copia os arquivos .htm e .txt da assinatura para %APPDATA%\Microsoft\Signatures.
4. Configura o Outlook 2019 para usar essa assinatura em novas mensagens e respostas.
```

Para usar em outras maquinas, publique pelo menos estas pastas/arquivos em uma pasta de rede ou em um pacote interno:

```text
config/
scripts/05_instalar_assinatura_usuario.ps1
instalar-assinatura.bat
```

Depois ajuste em `config/config.json`:

```json
"SignaturesSourceFolder": "\\\\SERVIDOR\\AssinaturasCorporativas\\assinaturas"
```

Exemplo de estrutura na rede:

```text
\\SERVIDOR\AssinaturasCorporativas\
  instalar-assinatura.bat
  config\config.json
  scripts\05_instalar_assinatura_usuario.ps1
```

As assinaturas geradas devem ficar no caminho configurado em `Install.SignaturesSourceFolder`.
O instalador usa esse caminho para localizar a pasta do usuario logado e copiar somente a assinatura correspondente para `%APPDATA%\Microsoft\Signatures`.

## Observacoes

- `output/`, `logs/`, `.env` e `config/config.json` ficam fora do Git pelo `.gitignore`.
- `database/consulta_colaboradores.sql` tambem fica fora do Git, pois pode conter estrutura interna da empresa.
- A pasta definida em `Paths.LocalOutputFolder` pode ser local ou uma pasta de rede.
- A pasta `output/pngs` serve para conferencia visual rapida.
- Para evitar imagem quebrada no destinatario, hospede os PNGs de `output/pngs` em um endereco HTTPS e preencha `ImageBaseUrl`.

Exemplo:

```json
"ImageBaseUrl": "https://assinaturas.empresa.com.br"
```

Assim o HTML de `nome.usuario` apontara para:

```text
https://assinaturas.empresa.com.br/nome.usuario.png
```
