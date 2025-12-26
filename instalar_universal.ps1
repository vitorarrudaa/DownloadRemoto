param (
    [string]$modelo, [string]$urlPrint, [string]$temScan, [string]$urlScan,
    [string]$filtroDriverWindows, [bool]$instalarPrint, [bool]$instalarScan,
    [bool]$instalarEPM, [bool]$instalarEDC
)

# --- LINKS GLOBAIS ---
$urlEPM = "https://ftp.hp.com/pub/softlib/software13/printers/SS/Common_SW/WIN_EPM_V2.00.01.36.exe"
$urlEDC = "https://ftp.hp.com/pub/softlib/software13/printers/SS/SL-M5270LX/WIN_EDC_V2.02.61.exe"

$caminhoTemp = "$env:USERPROFILE\Downloads\Instalacao_Samsung"
if (-not (Test-Path $caminhoTemp)) { New-Item $caminhoTemp -ItemType Directory | Out-Null }

function Test-JaInstalado($nomePrograma) {
    $chaves = @("HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*","HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*")
    return [bool](Get-ItemProperty $chaves -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$nomePrograma*" })
}

function Obter-Arquivo($url, $nomeDestino) {
    $caminhoArquivo = Join-Path $caminhoTemp $nomeDestino
    if (Test-Path $caminhoArquivo) {
        Write-Host "  -> Arquivo $nomeDestino ja presente na pasta. Pulando download..." -ForegroundColor Cyan
    } else {
        Write-Host "  -> Baixando $nomeDestino..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $url -OutFile $caminhoArquivo
    }
    return $caminhoArquivo
}

$acoes = @(); if ($instalarPrint) { $acoes += "P" }; if ($instalarScan) { $acoes += "S" }; if ($instalarEPM) { $acoes += "M" }; if ($instalarEDC) { $acoes += "D" }
$totalEtapas = $acoes.Count; $etapaAtual = 1

Write-Host "`n>>> PROCESSANDO ETAPA ($totalEtapas Etapa(s))" -ForegroundColor Cyan

# --- ETAPA: IMPRESSAO ---
if ($instalarPrint) {
    Write-Host "`n[$etapaAtual/$totalEtapas] DRIVER DE IMPRESSAO" -ForegroundColor Yellow
    $novoNome = Read-Host "  -> Nome desejado para a impressora"
    $ip = Read-Host "  -> Endereco IP"
    
    $nomeArquivo = "driver_print_" + ($modelo -replace '\s+','_') + ".exe"
    $filePrint = Obter-Arquivo -url $urlPrint -nomeDestino $nomeArquivo
    
    Write-Host "  -> Instalando driver e extraindo arquivos..." -ForegroundColor Gray
    Start-Process $filePrint -ArgumentList "/S" -Wait
    Start-Sleep -Seconds 10

    $impGenerica = Get-Printer | Where-Object {$_.DriverName -like "*Samsung Universal*" -or $_.Name -like "*Samsung Universal*"} | Select-Object -First 1
    Write-Host "  -> Vinculando ao Driver Especifico ($filtroDriverWindows)..." -ForegroundColor Gray
    
    if (-not (Get-PrinterPort $ip -ErrorAction SilentlyContinue)) { 
        Add-PrinterPort -Name $ip -PrinterHostAddress $ip 
    }

    try {
        if ($impGenerica) {
            Set-Printer -Name $impGenerica.Name -DriverName $filtroDriverWindows -PortName $ip
            Rename-Printer -Name $impGenerica.Name -NewName $novoNome
        } else {
            Add-Printer -Name $novoNome -DriverName $filtroDriverWindows -PortName $ip
        }
        Write-Host "  -> OK: Fila configurada com o driver especifico!" -ForegroundColor Green
    } catch {
        Write-Host "  -> AVISO: Nao foi possivel forçar o driver '$filtroDriverWindows'." -ForegroundColor Yellow
    }
    $etapaAtual++
}

# --- ETAPA: SCAN ---
if ($instalarScan) {
    Write-Host "`n[$etapaAtual/$totalEtapas] DRIVER DE SCAN" -ForegroundColor Yellow
    $nomeArquivoScan = "driver_scan_" + ($modelo -replace '\s+','_') + ".exe"
    $fileScan = Obter-Arquivo -url $urlScan -nomeDestino $nomeArquivoScan
    Start-Process $fileScan -ArgumentList "/S" -Wait
    Write-Host "  -> OK: Scan instalado!" -ForegroundColor Green
    $etapaAtual++
}

# --- ETAPA: EPM ---
if ($instalarEPM) {
    Write-Host "`n[$etapaAtual/$totalEtapas] EASY PRINTER MANAGER" -ForegroundColor Yellow
    if (-not (Test-JaInstalado "Easy Printer Manager")) {
        $fileEPM = Obter-Arquivo -url $urlEPM -nomeDestino "EPM_Universal.exe"
        Start-Process $fileEPM -ArgumentList "/S" -Wait
        Write-Host "  -> OK: Instalado!" -ForegroundColor Green
    } else { Write-Host "  -> Ja instalado no sistema." -ForegroundColor Cyan }
    $etapaAtual++
}

# --- ETAPA: EDC ---
if ($instalarEDC) {
    Write-Host "`n[$etapaAtual/$totalEtapas] EASY DOCUMENT CREATOR" -ForegroundColor Yellow
    if (-not (Test-JaInstalado "Easy Document Creator")) {
        $fileEDC = Obter-Arquivo -url $urlEDC -nomeDestino "EDC_Universal.exe"
        Start-Process $fileEDC -ArgumentList "/S" -Wait
        Write-Host "  -> OK: Instalado!" -ForegroundColor Green
    } else { Write-Host "  -> Ja instalado no sistema." -ForegroundColor Cyan }
    $etapaAtual++
}

Write-Host "`nEtapa finalizada! Voltando ao menu..." -ForegroundColor Green
Start-Sleep -Seconds 2
