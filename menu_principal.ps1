# ================================================================================
# SCRIPT: Menu Principal - Sistema de Instalacao de Impressoras Samsung
# VERSAO: 2.0 (Otimizado)
# DESCRICAO: Menu interativo para instalacao remota de drivers Samsung
# ================================================================================

# --- VERIFICACAO DE PRIVILEGIOS ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Host "`n[ERRO] Este script requer privilegios de ADMINISTRADOR" -ForegroundColor Red
    Write-Host "Abra o PowerShell como Administrador e execute novamente.`n" -ForegroundColor Yellow
    Read-Host "Pressione ENTER para sair"
    exit
}

Set-ExecutionPolicy Bypass -Scope Process -Force

# --- CONFIGURACAO DO REPOSITORIO GITHUB ---
$Config = @{
    Usuario     = "vitorarrudaa"
    Repositorio = "DownloadRemoto"
    Branch      = "main"
}
$Config.BaseUrl = "https://raw.githubusercontent.com/$($Config.Usuario)/$($Config.Repositorio)/$($Config.Branch)"

# --- DIRETORIOS LOCAIS ---
$Paths = @{
    Raiz   = "$env:USERPROFILE\Downloads\Suporte_Tech3"
    CSV    = "$env:USERPROFILE\Downloads\Suporte_Tech3\dados_impressoras.csv"
    Motor  = "$env:USERPROFILE\Downloads\Suporte_Tech3\instalar_universal.ps1"
}

# Criar diretorio se nao existir
if (-not (Test-Path $Paths.Raiz)) {
    New-Item $Paths.Raiz -ItemType Directory -Force | Out-Null
}

# --- FUNCAO: SINCRONIZAR ARQUIVOS DO GITHUB ---
function Sync-GitHubFiles {
    Write-Host "`n[INFO] Sincronizando arquivos com GitHub..." -ForegroundColor Cyan
    
    try {
        # Download do CSV
        Invoke-WebRequest -Uri "$($Config.BaseUrl)/dados_impressoras.csv" `
                         -OutFile $Paths.CSV `
                         -ErrorAction Stop `
                         -UseBasicParsing
        
        # Download do script de instalacao
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
        Write-Host "Verifique sua conexao com a internet e o repositorio.`n" -ForegroundColor Yellow
        Read-Host "Pressione ENTER para sair"
        return $false
    }
}

# --- FUNCAO: CARREGAR DADOS DAS IMPRESSORAS ---
function Get-PrinterData {
    try {
        $dados = Import-Csv -Path $Paths.CSV -Delimiter "," -ErrorAction Stop
        
        if ($dados.Count -eq 0) {
            throw "CSV esta vazio"
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

# --- FUNCAO: EXIBIR MENU DE MODELOS ---
function Show-ModelMenu {
    param($listaModelos)
    
    Clear-Host
    Write-Host "========================================================" -ForegroundColor Magenta
    Write-Host "    TECH3 - INSTALADOR DE IMPRESSORAS SAMSUNG" -ForegroundColor Magenta
    Write-Host "========================================================" -ForegroundColor Magenta
    Write-Host ""
    
    foreach ($item in $listaModelos) {
        $temScan = if ($item.TemScan -eq "S") { "(Impressao + Scan)" } else { "(Apenas Impressao)" }
        Write-Host "  $($item.ID)) $($item.Modelo) $temScan" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "  Q) Sair" -ForegroundColor Gray
    Write-Host ""
}

# --- FUNCAO: EXIBIR MENU DE CONFIGURACAO ---
function Show-ConfigMenu {
    param($modelo)
    
    Clear-Host
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "  MODELO SELECIONADO: $($modelo.Modelo)" -ForegroundColor Cyan
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1) Instalacao Completa (Todos os componentes)" -ForegroundColor White
    Write-Host "  2) Instalacao Personalizada (Escolher componentes)" -ForegroundColor White
    Write-Host ""
    Write-Host "  V) Voltar ao menu anterior" -ForegroundColor Gray
    Write-Host ""
}

# --- FUNCAO: EXIBIR MENU PERSONALIZADO ---
function Show-CustomMenu {
    param($modelo)
    
    Clear-Host
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "  INSTALACAO PERSONALIZADA: $($modelo.Modelo)" -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1) Driver de Impressao" -ForegroundColor White
    
    if ($modelo.TemScan -eq "S") {
        Write-Host "  2) Driver de Digitalizacao (Scan)" -ForegroundColor White
        Write-Host "  3) Easy Document Creator (EDC)" -ForegroundColor White
        Write-Host "  4) Easy Printer Manager (EPM)" -ForegroundColor White
    } else {
        Write-Host "  2) Easy Printer Manager (EPM)" -ForegroundColor White
    }
    
    Write-Host ""
    Write-Host "  V) Voltar" -ForegroundColor Gray
    Write-Host ""
}

# --- FUNCAO: EXECUTAR INSTALACAO ---
function Invoke-Installation {
    param(
        [hashtable]$parametros
    )
    
    try {
        & $Paths.Motor @parametros
    }
    catch {
        Write-Host "`n[ERRO] Falha ao executar instalacao" -ForegroundColor Red
        Write-Host "Detalhes: $($_.Exception.Message)`n" -ForegroundColor Red
        Read-Host "Pressione ENTER para continuar"
    }
}

# --- SINCRONIZACAO INICIAL ---
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
        Write-Host "`n[AVISO] Opcao invalida! Tente novamente.`n" -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        continue
    }
    
    # --- SUBMENU: TIPO DE INSTALACAO ---
    $continuarNoMo
