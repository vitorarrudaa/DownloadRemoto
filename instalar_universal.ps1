# ================================================================================
# SCRIPT: Motor de Instalação Universal - Impressoras Samsung
# VERSÃO: 2.0 (Otimizado)
# DESCRIÇÃO: Instalador universal para drivers Samsung M4020/M4070/M4080
# ================================================================================

param (
    [Parameter(Mandatory=$true)]
    [string]$modelo,
    
    [Parameter(Mandatory=$true)]
    [string]$urlPrint,
    
    [Parameter(Mandatory=$true)]
    [string]$temScan,
    
    [Parameter(Mandatory=$false)]
    [string]$urlScan = "",
    
    [Parameter(Mandatory=$true)]
    [string]$filtroDriverWindows,
    
    [Parameter(Mandatory=$true)]
    [bool]$instalarPrint,
    
    [Parameter(Mandatory=$true)]
    [bool]$instalarScan,
    
    [Parameter(Mandatory=$true)]
    [bool]$instalarEPM,
    
    [Parameter(Mandatory=$true)]
    [bool]$instalarEDC
)

# --- CONFIGURAÇÃO GLOBAL ---
$Global:Config = @{
    UrlEPM        = "https://ftp.hp.com/pub/softlib/software13/printers/SS/Common_SW/WIN_EPM_V2.00.01.36.exe"
    UrlEDC        = "https://ftp.hp.com/pub/softlib/software13/printers/SS/SL-M5270LX/WIN_EDC_V2.02.61.exe"
    CaminhoTemp   = "$env:USERPROFILE\Downloads\Instalacao_Samsung"
    TempoEspera   = 10
}

# Criar pasta temporária
if (-not (Test-Path $Global:Config.CaminhoTemp)) {
    New-Item $Global:Config.CaminhoTemp -ItemType Directory -Force | Out-Null
}

# --- FUNÇÕES AUXILIARES ---

function Test-ProgramaInstalado {
    param([string]$nomePrograma)
    
    $chaves = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    
    $programas = Get-ItemProperty $chaves -ErrorAction SilentlyContinue | 
                 Where-Object { $_.DisplayName -like "*$nomePrograma*" }
    
    return [bool]$programas
}

function Get-ArquivoLocal {
    param(
        [string]$url,
        [string]$nomeDestino
    )
    
    $caminhoCompleto = Join-Path $Global:Config.CaminhoTemp $nomeDestino
    
    if (Test-Path $caminhoCompleto) {
        Write-Host "  → Arquivo já existe localmente. Reutilizando..." -ForegroundColor Cyan
        return $caminhoCompleto
    }
    
    try {
        Write-Host "  → Baixando: $nomeDestino..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $url -OutFile $caminhoCompleto -ErrorAction Stop -UseBasicParsing
        Write-Host "  → Download concluído!" -ForegroundColor Green
        return $caminhoCompleto
    }
    catch {
        Write-Host "  → [ERRO] Falha ao baixar arquivo" -ForegroundColor Red
        Write-Host "  → Detalhes: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Pressione ENTER para continuar"
        return $null
    }
}

function Remove-FilaDuplicada {
    param([string]$nomeConfigurado)
    
    Write-Host "  → Verificando filas duplicadas..." -ForegroundColor Gray
    
    # Lista exata de nomes que o instalador cria (padrão de fábrica)
    $nomesPadraoInstalador = @(
        "Samsung M332x 382x 402x Series",
        "Samsung M337x 387x 407x Series",
        "Samsung M408x Series",
        "Samsung Universal Print Driver",
        "Samsung Universal Print Driver 2",
        "Samsung Universal Print Driver 3"
    )
    
    $todasImpressoras = Get-Printer -ErrorAction SilentlyContinue
    
    # Remover apenas filas com nomes padrão do instalador OU com "(Copy X)"
    $duplicatas = $todasImpressoras | Where-Object {
        $_.Name -ne $nomeConfigurado -and
        (
            $nomesPadraoInstalador -contains $_.Name -or
            $_.Name -match '^(Samsung .+) \(Copy \d+\)$'
        ) -and
        $_.Name -notlike "*Fax*"
    }
    
    if ($duplicatas) {
        Write-Host "  → Removendo filas duplicadas do instalador:" -ForegroundColor Yellow
        foreach ($fila in $duplicatas) {
            try {
                Remove-Printer -Name $fila.Name -Confirm:$false -ErrorAction Stop
                Write-Host "    ✓ Removida: $($fila.Name)" -ForegroundColor Gray
            }
            catch {
                Write-Host "    ✗ Falha ao remover: $($fila.Name)" -ForegroundColor Red
            }
        }
    }
    else {
        Write-Host "  → Nenhuma duplicata encontrada!" -ForegroundColor Green
    }
}

# --- CÁLCULO DE ETAPAS ---
$etapas = @()
if ($instalarPrint) { $etapas += "PRINT" }
if ($instalarScan)  { $etapas += "SCAN" }
if ($instalarEPM)   { $etapas += "EPM" }
if ($instalarEDC)   { $etapas += "EDC" }

$totalEtapas = $etapas.Count
$etapaAtual = 1

Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  PROCESSANDO $totalEtapas ETAPA(S) - $modelo" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# ================================================================================
# ETAPA 1: DRIVER DE IMPRESSÃO
# ================================================================================

if ($instalarPrint) {
    Write-Host "[$etapaAtual/$totalEtapas] ═══ DRIVER DE IMPRESSÃO ═══" -ForegroundColor Yellow
    Write-Host ""
    
    # Coletar informações
    $nomeImpressora = Read-Host "  → Nome da impressora"
    $enderecoIP = Read-Host "  → Endereço IP"
    
    # Validar IP
    if ($enderecoIP -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
        Write-Host "`n  [AVISO] IP inválido! Usando padrão 192.168.1.100" -ForegroundColor Yellow
        $enderecoIP = "192.168.1.100"
    }
    
    # Download do driver
    $nomeArquivo = "driver_print_" + ($modelo -replace '\s+', '_') + ".exe"
    $arquivoDriver = Get-ArquivoLocal -url $urlPrint -nomeDestino $nomeArquivo
    
    if (-not $arquivoDriver) {
        Write-Host "  [ERRO] Não foi possível obter o arquivo. Pulando etapa...`n" -ForegroundColor Red
        $etapaAtual++
    }
    else {
        # Instalar driver
        Write-Host "  → Instalando driver... (Aguarde)" -ForegroundColor Gray
        Start-Process $arquivoDriver -ArgumentList "/S" -Wait -NoNewWindow
        Start-Sleep -Seconds $Global:Config.TempoEspera
        
        # Criar porta IP
        if (-not (Get-PrinterPort $enderecoIP -ErrorAction SilentlyContinue)) {
            Add-PrinterPort -Name $enderecoIP -PrinterHostAddress $enderecoIP -ErrorAction SilentlyContinue
            Write-Host "  → Porta IP criada: $enderecoIP" -ForegroundColor Gray
        }
        
        Write-Host "  → Configurando fila de impressão..." -ForegroundColor Gray
        
        # Buscar fila criada pelo instalador
        $filaEspecifica = Get-Printer -ErrorAction SilentlyContinue | 
                         Where-Object {
                             $_.Name -like "*$filtroDriverWindows*" -or 
                             $_.DriverName -like "*$filtroDriverWindows*"
                         } | Select-Object -First 1
        
        $filaUniversal = $null
        if (-not $filaEspecifica) {
            $filaUniversal = Get-Printer -ErrorAction SilentlyContinue | 
                            Where-Object {
                                $_.DriverName -like "*Samsung Universal*" -or 
                                $_.Name -like "*Samsung Universal*"
                            } | Select-Object -First 1
        }
        
        # Configurar impressora
        try {
            if ($filaEspecifica) {
                # Caso M4020/M4070: Fila específica já criada
                Set-Printer -Name $filaEspecifica.Name -PortName $enderecoIP -ErrorAction Stop
                Rename-Printer -Name $filaEspecifica.Name -NewName $nomeImpressora -ErrorAction Stop
                Write-Host "  ✓ Impressora configurada com sucesso!" -ForegroundColor Green
            }
            elseif ($filaUniversal) {
                # Caso M4080: Fila Universal criada, tentar trocar driver
                try {
                    Set-Printer -Name $filaUniversal.Name -DriverName $filtroDriverWindows -PortName $enderecoIP -ErrorAction Stop
                    Rename-Printer -Name $filaUniversal.Name -NewName $nomeImpressora -ErrorAction Stop
                    Write-Host "  ✓ Fila Universal convertida para driver específico!" -ForegroundColor Green
                }
                catch {
                    # Se falhar troca de driver, manter Universal
                    Write-Host "  ! Driver específico não disponível. Usando Universal..." -ForegroundColor Yellow
                    Set-Printer -Name $filaUniversal.Name -PortName $enderecoIP -ErrorAction Stop
                    Rename-Printer -Name $filaUniversal.Name -NewName $nomeImpressora -ErrorAction Stop
                    Write-Host "  ✓ Impressora configurada com driver Universal!" -ForegroundColor Green
                }
            }
            else {
                # Nenhuma fila encontrada: criar manualmente
                Add-Printer -Name $nomeImpressora -DriverName $filtroDriverWindows -PortName $enderecoIP -ErrorAction Stop
                Write-Host "  ✓ Fila criada manualmente!" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "  ✗ [ERRO] Falha ao configurar impressora" -ForegroundColor Red
            Write-Host "  → Detalhes: $($_.Exception.Message)" -ForegroundColor Red
            
            # Listar drivers disponíveis
            Write-Host "`n  → Drivers Samsung disponíveis no sistema:" -ForegroundColor Yellow
            Get-PrinterDriver -ErrorAction SilentlyContinue | 
                Where-Object { $_.Name -like "*Samsung*" } | 
                ForEach-Object { Write-Host "    • $($_.Name)" -ForegroundColor Cyan }
            
            Read-Host "`n  Pressione ENTER para continuar"
        }
        
        # Limpar duplicatas
        Start-Sleep -Seconds 2
        Remove-FilaDuplicada -nomeConfigurado $nomeImpressora
        
        $etapaAtual++
        Write-Host ""
    }
}

# ================================================================================
# ETAPA 2: DRIVER DE DIGITALIZAÇÃO
# ================================================================================

if ($instalarScan) {
    Write-Host "[$etapaAtual/$totalEtapas] ═══ DRIVER DE DIGITALIZAÇÃO ═══" -ForegroundColor Yellow
    Write-Host ""
    
    if ([string]::IsNullOrWhiteSpace($urlScan)) {
        Write-Host "  [AVISO] URL de scan não disponível. Pulando...`n" -ForegroundColor Yellow
    }
    else {
        $nomeArquivoScan = "driver_scan_" + ($modelo -replace '\s+', '_') + ".exe"
        $arquivoScan = Get-ArquivoLocal -url $urlScan -nomeDestino $nomeArquivoScan
        
        if ($arquivoScan) {
            Write-Host "  → Instalando driver de scan..." -ForegroundColor Gray
            Start-Process $arquivoScan -ArgumentList "/S" -Wait -NoNewWindow
            Write-Host "  ✓ Driver de scan instalado!" -ForegroundColor Green
        }
    }
    
    $etapaAtual++
    Write-Host ""
}

# ================================================================================
# ETAPA 3: EASY PRINTER MANAGER
# ================================================================================

if ($instalarEPM) {
    Write-Host "[$etapaAtual/$totalEtapas] ═══ EASY PRINTER MANAGER ═══" -ForegroundColor Yellow
    Write-Host ""
    
    if (Test-ProgramaInstalado "Easy Printer Manager") {
        Write-Host "  → Já instalado no sistema!" -ForegroundColor Cyan
    }
    else {
        $arquivoEPM = Get-ArquivoLocal -url $Global:Config.UrlEPM -nomeDestino "EPM_Universal.exe"
        
        if ($arquivoEPM) {
            Write-Host "  → Instalando Easy Printer Manager..." -ForegroundColor Gray
            Start-Process $arquivoEPM -ArgumentList "/S" -Wait -NoNewWindow
            Write-Host "  ✓ Easy Printer Manager instalado!" -ForegroundColor Green
        }
    }
    
    $etapaAtual++
    Write-Host ""
}

# ================================================================================
# ETAPA 4: EASY DOCUMENT CREATOR
# ================================================================================

if ($instalarEDC) {
    Write-Host "[$etapaAtual/$totalEtapas] ═══ EASY DOCUMENT CREATOR ═══" -ForegroundColor Yellow
    Write-Host ""
    
    if (Test-ProgramaInstalado "Easy Document Creator") {
        Write-Host "  → Já instalado no sistema!" -ForegroundColor Cyan
    }
    else {
        $arquivoEDC = Get-ArquivoLocal -url $Global:Config.UrlEDC -nomeDestino "EDC_Universal.exe"
        
        if ($arquivoEDC) {
            Write-Host "  → Instalando Easy Document Creator..." -ForegroundColor Gray
            Start-Process $arquivoEDC -ArgumentList "/S" -Wait -NoNewWindow
            Write-Host "  ✓ Easy Document Creator instalado!" -ForegroundColor Green
        }
    }
    
    $etapaAtual++
    Write-Host ""
}

# ================================================================================
# FINALIZAÇÃO
# ================================================================================

Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  PROCESSO CONCLUÍDO COM SUCESSO!                      ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Start-Sleep -Seconds 3
