# ================================================================================
# SCRIPT: Menu Principal - Sistema de Instalação de Impressoras Samsung
# VERSÃO: 2.0 (Otimizado)
# DESCRIÇÃO: Menu interativo para instalação remota de drivers Samsung
# ================================================================================

# --- VERIFICAÇÃO DE PRIVILÉGIOS ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Host "`n[ERRO] Este script requer privilégios de ADMINISTRADOR" -ForegroundColor Red
    Write-Host "Abra o PowerShell como Administrador e execute novamente.`n" -ForegroundColor Yellow
    Read-Host "Pressione ENTER para sair"
    exit
}

Set-ExecutionPolicy Bypass -Scope Process -Force

# --- CONFIGURAÇÃO DO REPOSITÓRIO GITHUB ---
$Config = @{
    Usuario    = "vitorarrudaa"
    Repositorio = "DownloadRemoto"
    Branch     = "main"
}
$Config.BaseUrl = "https://raw.githubusercontent.com/$($Config.Usuario)/$($Config.Repositorio)/$($Config.Branch)"

# --- DIRETÓRIOS LOCAIS ---
$Paths = @{
    Raiz   = "$env:USERPROFILE\Downloads\Suporte_Tech3"
    CSV    = "$env:USERPROFILE\Downloads\Suporte_Tech3\dados_impressoras.csv"
    Motor  = "$env:USERPROFILE\Downloads\Suporte_Tech3\instalar_universal.ps1"
}

# Criar diretório se não existir
if (-not (Test-Path $Paths.Raiz)) {
    New-Item $Paths.Raiz -ItemType Directory -Force | Out-Null
}

# --- FUNÇÃO: SINCRONIZAR ARQUIVOS DO GITHUB ---
function Sync-GitHubFiles {
    Write-Host "`n[INFO] Sincronizando arquivos com GitHub..." -ForegroundColor Cyan
    
    try {
        # Download do CSV
        Invoke-WebRequest -Uri "$($Config.BaseUrl)/dados_impressoras.csv" `
                         -OutFile $Paths.CSV `
                         -ErrorAction Stop `
                         -UseBasicParsing
        
        # Download do script de instalação
        Invoke-WebRequest -Uri "$($Config.BaseUrl)/instalar_universal.ps1" `
                         -OutFile $Paths.Motor `
                         -ErrorAction Stop `
                         -UseBasicParsing
        
        Write-Host "[OK] Arquivos sincronizados com sucesso!`n" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "`n[ERRO] Falha ao sincronizar arquivos do GitHub" -ForegroundColor Red
        Write-Host "Detalhes: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Verifique sua conexão com a internet e o repositório.`n" -ForegroundColor Yellow
        Read-Host "Pressione ENTER para sair"
        return $false
    }
}

# --- FUNÇÃO: CARREGAR DADOS DAS IMPRESSORAS ---
function Get-PrinterData {
    try {
        $dados = Import-Csv -Path $Paths.CSV -Delimiter "," -ErrorAction Stop
        
        if ($dados.Count -eq 0) {
            throw "CSV está vazio"
        }
        
        return $dados
    }
    catch {
        Write-Host "`n[ERRO] Falha ao carregar dados das impressoras" -ForegroundColor Red
        Write-Host "Detalhes: $($_.Exception.Message)`n" -ForegroundColor Red
        Read-Host "Pressione ENTER para sair"
        exit
    }
}

# --- FUNÇÃO: EXIBIR MENU DE MODELOS ---
function Show-ModelMenu {
    param($listaModelos)
    
    Clear-Host
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║       TECH3 - INSTALADOR DE IMPRESSORAS SAMSUNG       ║" -ForegroundColor Magenta
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
    Write-Host ""
    
    foreach ($item in $listaModelos) {
        $temScan = if ($item.TemScan -eq "S") { "(Impressão + Scan)" } else { "(Apenas Impressão)" }
        Write-Host "  $($item.ID)) $($item.Modelo) $temScan" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "  Q) Sair" -ForegroundColor Gray
    Write-Host ""
}

# --- FUNÇÃO: EXIBIR MENU DE CONFIGURAÇÃO ---
function Show-ConfigMenu {
    param($modelo)
    
    Clear-Host
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  MODELO SELECIONADO: $($modelo.Modelo.PadRight(31)) ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) Instalação Completa (Todos os componentes)" -ForegroundColor White
    Write-Host "  2) Instalação Personalizada (Escolher componentes)" -ForegroundColor White
    Write-Host ""
    Write-Host "  V) Voltar ao menu anterior" -ForegroundColor Gray
    Write-Host ""
}

# --- FUNÇÃO: EXIBIR MENU PERSONALIZADO ---
function Show-CustomMenu {
    param($modelo)
    
    Clear-Host
    Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║  INSTALAÇÃO PERSONALIZADA: $($modelo.Modelo.PadRight(25)) ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1) Driver de Impressão" -ForegroundColor White
    
    if ($modelo.TemScan -eq "S") {
        Write-Host "  2) Driver de Digitalização (Scan)" -ForegroundColor White
        Write-Host "  3) Easy Document Creator (EDC)" -ForegroundColor White
        Write-Host "  4) Easy Printer Manager (EPM)" -ForegroundColor White
    } else {
        Write-Host "  2) Easy Printer Manager (EPM)" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "  V) Voltar" -ForegroundColor Gray
    Write-Host ""
}

# --- FUNÇÃO: EXECUTAR INSTALAÇÃO ---
function Invoke-Installation {
    param(
        [hashtable]$parametros
    )
    
    try {
        & $Paths.Motor @parametros
    }
    catch {
        Write-Host "`n[ERRO] Falha ao executar instalação" -ForegroundColor Red
        Write-Host "Detalhes: $($_.Exception.Message)`n" -ForegroundColor Red
        Read-Host "Pressione ENTER para continuar"
    }
}

# --- SINCRONIZAÇÃO INICIAL ---
if (-not (Sync-GitHubFiles)) {
    exit
}

$listaImpressoras = Get-PrinterData

# ================================================================================
# LOOP PRINCIPAL DO MENU
# ================================================================================

do {
    Show-ModelMenu -listaModelos $listaImpressoras
    $escolhaModelo = Read-Host "Escolha o ID do modelo ou (Q) para sair"
    
    # Sair do sistema
    if ($escolhaModelo -eq "Q" -or $escolhaModelo -eq "q") {
        Write-Host "`n[INFO] Encerrando sistema...`n" -ForegroundColor Cyan
        break
    }
    
    # Buscar dados do modelo selecionado
    $modeloSelecionado = $listaImpressoras | Where-Object { $_.ID -eq $escolhaModelo }
    
    if (-not $modeloSelecionado) {
        Write-Host "`n[AVISO] Opção inválida! Tente novamente.`n" -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        continue
    }
    
    # --- SUBMENU: TIPO DE INSTALAÇÃO ---
    $continuarNoModelo = $true
    
    while ($continuarNoModelo) {
        Show-ConfigMenu -modelo $modeloSelecionado
        $tipoInstalacao = Read-Host "Escolha uma opção"
        
        # Voltar ao menu de modelos
        if ($tipoInstalacao -eq "V" -or $tipoInstalacao -eq "v") {
            $continuarNoModelo = $false
            break
        }
        
        # Preparar parâmetros base
        $params = @{
            modelo               = $modeloSelecionado.Modelo
            urlPrint            = $modeloSelecionado.UrlPrint
            temScan             = $modeloSelecionado.TemScan
            urlScan             = $modeloSelecionado.UrlScan
            filtroDriverWindows = $modeloSelecionado.FiltroDriver
            instalarPrint       = $false
            instalarScan        = $false
            instalarEPM         = $false
            instalarEDC         = $false
        }
        
        # --- OPÇÃO 1: INSTALAÇÃO COMPLETA ---
        if ($tipoInstalacao -eq "1") {
            $params.instalarPrint = $true
            $params.instalarEPM = $true
            
            if ($modeloSelecionado.TemScan -eq "S") {
                $params.instalarScan = $true
                $params.instalarEDC = $true
            }
            
            Invoke-Installation -parametros $params
            $continuarNoModelo = $false
        }
        # --- OPÇÃO 2: INSTALAÇÃO PERSONALIZADA ---
        elseif ($tipoInstalacao -eq "2") {
            $sairPersonalizado = $false
            
            while (-not $sairPersonalizado) {
                Show-CustomMenu -modelo $modeloSelecionado
                $componenteEscolhido = Read-Host "Escolha o componente"
                
                # Voltar ao menu anterior
                if ($componenteEscolhido -eq "V" -or $componenteEscolhido -eq "v") {
                    $sairPersonalizado = $true
                    break
                }
                
                # Resetar flags
                $params.instalarPrint = $false
                $params.instalarScan = $false
                $params.instalarEDC = $false
                $params.instalarEPM = $false
                
                # Configurar componente selecionado
                if ($modeloSelecionado.TemScan -eq "S") {
                    switch ($componenteEscolhido) {
                        "1" { $params.instalarPrint = $true }
                        "2" { $params.instalarScan = $true }
                        "3" { $params.instalarEDC = $true }
                        "4" { $params.instalarEPM = $true }
                        default {
                            Write-Host "`n[AVISO] Opção inválida!`n" -ForegroundColor Yellow
                            Start-Sleep -Seconds 2
                            continue
                        }
                    }
                } else {
                    switch ($componenteEscolhido) {
                        "1" { $params.instalarPrint = $true }
                        "2" { $params.instalarEPM = $true }
                        default {
                            Write-Host "`n[AVISO] Opção inválida!`n" -ForegroundColor Yellow
                            Start-Sleep -Seconds 2
                            continue
                        }
                    }
                }
                
                Invoke-Installation -parametros $params
            }
        }
        else {
            Write-Host "`n[AVISO] Opção inválida! Tente novamente.`n" -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }
    
} while ($true)
