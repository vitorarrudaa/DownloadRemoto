param (
    [string]$modelo, [string]$urlPrint, [string]$temScan, [string]$urlScan,
    [string]$filtroDriverWindows, [bool]$instalarPrint, [bool]$instalarScan,
    [bool]$instalarEPM, [bool]$instalarEDC
)

$urlEPM = "https://ftp.hp.com/pub/softlib/software13/printers/SS/Common_SW/WIN_EPM_V2.00.01.36.exe"
$urlEDC = "https://ftp.hp.com/pub/softlib/software13/printers/SS/SL-M5270LX/WIN_EDC_V2.02.61.exe"
$caminhoTemp = "$env:USERPROFILE\Downloads\Instalacao_Samsung"

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

Write-Host "`n>>> PROCESSANDO: $modelo" -ForegroundColor Cyan

if ($instalarPrint) {
    Write-Host "`n[$etapaAtual/$totalEtapas] DRIVER DE IMPRESSAO" -ForegroundColor Yellow
    $novoNome = Read-Host "  -> Nome desejado para a impressora"
    $ip = Read-Host "  -> Endereco IP"
    
    $nomeArquivo = "print_" + ($modelo -replace '\s+','_') + ".exe"
    $filePrint = Obter-Arquivo -url $urlPrint -nomeDestino $nomeArquivo
    
    Start-Process $filePrint -ArgumentList "/S" -Wait
    Start-Sleep -Seconds 10

    if (-not (Get-PrinterPort $ip -ErrorAction SilentlyContinue)) { Add-PrinterPort -Name $ip -PrinterHostAddress $ip }
    
    $imp = Get-Printer | Where-Object {$_.DriverName -like "*Samsung Universal*" -or $_.Name -like "*Samsung Universal*" -or $_.Name -like $filtroDriverWindows} | Select-Object -First 1
    
    try {
        if ($imp) {
            Set-Printer -Name $imp.Name -DriverName $filtroDriverWindows -PortName $ip
            Rename-Printer -Name $imp.Name -NewName $novoNome
            Write-Host "  -> OK: Impressora configurada com sucesso!" -ForegroundColor Green
        } else {
            Add-Printer -Name $novoNome -DriverName $filtroDriverWindows -PortName $ip
            Write-Host "  -> OK: Fila criada manualmente com driver especifico!" -ForegroundColor Green
        }
    } catch { Write-Host "  -> Erro na configuracao final. Verifique o FiltroDriver no CSV." -ForegroundColor Red }
    $etapaAtual++
}

if ($instalarScan) {
    Write-Host "`n[$etapaAtual/$totalEtapas] DRIVER DE SCAN" -ForegroundColor Yellow
    $nomeArquivoScan = "scan_" + ($modelo -replace '\s+','_') + ".exe"
    $fileScan = Obter-Arquivo -url $urlScan -nomeDestino $nomeArquivoScan
    Start-Process $fileScan -ArgumentList "/S" -Wait
    $etapaAtual++
}

if ($instalarEPM) {
    Write-Host "`n[$etapaAtual/$totalEtapas] EASY PRINTER MANAGER" -ForegroundColor Yellow
    if (-not (Test-JaInstalado "Easy Printer Manager")) {
        $fileEPM = Obter-Arquivo -url $urlEPM -nomeDestino "EPM_Universal.exe"
        Start-Process $fileEPM -ArgumentList "/S" -Wait
    } else { Write-Host "  -> Ja instalado." -ForegroundColor Cyan }
    $etapaAtual++
}

if ($instalarEDC) {
    Write-Host "`n[$etapaAtual/$totalEtapas] EASY DOCUMENT CREATOR" -ForegroundColor Yellow
    if (-not (Test-JaInstalado "Easy Document Creator")) {
        $fileEDC = Obter-Arquivo -url $urlEDC -nomeDestino "EDC_Universal.exe"
        Start-Process $fileEDC -ArgumentList "/S" -Wait
    } else { Write-Host "  -> Ja instalado." -ForegroundColor Cyan }
    $etapaAtual++
}

Write-Host "`nProcesso finalizado!" -ForegroundColor Green
Start-Sleep -Seconds 2
