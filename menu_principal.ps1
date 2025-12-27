# --- CONFIGURACAO DE AMBIENTE (ADMIN E PERMISSOES) ---
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "Este script precisa ser executado como ADMINISTRADOR."
    Write-Host "Por favor, abra o PowerShell como Administrador antes de rodar o comando." -ForegroundColor Yellow
    Pause; exit
}
Set-ExecutionPolicy Bypass -Scope Process -Force

# --- CONFIGURACAO DO REPOSITORIO GITHUB ---
$usuarioGithub = "vitorarrudaa"
$repoGithub    = "DownloadRemoto"
$branch        = "main"
$baseUrl       = "https://raw.githubusercontent.com/$usuarioGithub/$repoGithub/$branch"

# Pasta temporaria local para execucao
$raiz = "$env:USERPROFILE\Downloads\Suporte_Tech3"
if (-not (Test-Path $raiz)) { New-Item $raiz -ItemType Directory | Out-Null }

$csvPath = Join-Path $raiz "dados_impressoras.csv"
$motorPath = Join-Path $raiz "instalar_universal.ps1"

# --- SINCRONIZACAO COM GITHUB ---
Write-Host "Sincronizando arquivos com o GitHub..." -ForegroundColor Gray
try {
    Invoke-WebRequest -Uri "$baseUrl/dados_impressoras.csv" -OutFile $csvPath -ErrorAction Stop
    Invoke-WebRequest -Uri "$baseUrl/instalar_universal.ps1" -OutFile $motorPath -ErrorAction Stop
} catch {
    Write-Error "Falha ao baixar arquivos do GitHub. Verifique a conexao ou o Repositorio."
    Pause; exit
}

$lista = Import-Csv -Path $csvPath -Delimiter ","

# --- INICIO DA LOGICA DE MENU ---
do {
    Clear-Host
    Write-Host "=== SELETOR TECH3 ===" -ForegroundColor Magenta
    foreach ($item in $lista) { Write-Host "$($item.ID)) $($item.Modelo)" }
    Write-Host "q) Sair do Script"
    $escolha = Read-Host "`nEscolha o ID do Modelo"

    if ($escolha -eq "q") { break }
    $dados = $lista | Where-Object { $_.ID -eq $escolha }

    if ($dados) {
        $continuarNoModelo = $true
        do {
            Clear-Host
            Write-Host "=== CONFIGURACAO: $($dados.Modelo) ===" -ForegroundColor Cyan
            Write-Host "1) Instalacao Completa (Tudo)"
            Write-Host "2) Escolher Componente Especifico (Personalizado)"
            Write-Host "v) Voltar ao Menu de Modelos"
            $modo = Read-Host "`nOpcao"

            if ($modo -eq "v") { $continuarNoModelo = $false; break }

            $params = @{
                modelo = $dados.Modelo; urlPrint = $dados.UrlPrint; temScan = $dados.TemScan; 
                urlScan = $dados.UrlScan; filtroDriverWindows = $dados.FiltroDriver;
                instalarPrint = $false; instalarScan = $false; instalarEPM = $false; instalarEDC = $false
            }

            if ($modo -eq "1") {
                $params.instalarPrint = $true; $params.instalarEPM = $true
                if ($dados.TemScan -eq "S") { $params.instalarScan = $true; $params.instalarEDC = $true }
                & $motorPath @params
                $continuarNoModelo = $false 
            } 
            elseif ($modo -eq "2") {
                $sairPersonalizado = $false
                do {
                    Clear-Host
                    Write-Host "=== MENU PERSONALIZADO: $($dados.Modelo) ===" -ForegroundColor Yellow
                    Write-Host "1 - Driver de Impressao"
                    if ($dados.TemScan -eq "S") {
                        Write-Host "2 - Driver de Digitalizacao (Scan)"
                        Write-Host "3 - Easy Document Creator (EDC)"
                        Write-Host "4 - Easy Printer Manager (EPM)"
                    } else {
                        Write-Host "2 - Easy Printer Manager (EPM)"
                    }
                    Write-Host "v - Voltar"
                    $peca = Read-Host "`nO que deseja instalar agora?"
                    if ($peca -eq "v") { $sairPersonalizado = $true; break }

                    $params.instalarPrint = $false; $params.instalarScan = $false; 
                    $params.instalarEDC = $false; $params.instalarEPM = $false

                    if ($dados.TemScan -eq "S") {
                        switch ($peca) {
                            "1" { $params.instalarPrint = $true }
                            "2" { $params.instalarScan  = $true }
                            "3" { $params.instalarEDC   = $true }
                            "4" { $params.instalarEPM   = $true }
                        }
                    } else {
                        switch ($peca) {
                            "1" { $params.instalarPrint = $true }
                            "2" { $params.instalarEPM   = $true }
                        }
                    }
                    & $motorPath @params
                } while (-not $sairPersonalizado)
            }
        } while ($continuarNoModelo)
    }
} while ($true)

