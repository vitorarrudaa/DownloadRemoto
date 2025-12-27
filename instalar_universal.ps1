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

# --- ETAPA: IMPRESSAO (LÓGICA UNIFICADA) ---
if ($instalarPrint) {
    Write-Host "`n[$etapaAtual/$totalEtapas] DRIVER DE IMPRESSAO" -ForegroundColor Yellow
    $novoNome = Read-Host "  -> Nome desejado para a impressora"
    $ip = Read-Host "  -> Endereco IP"
    
    $nomeArquivo = "driver_print_" + ($modelo -replace '\s+','_') + ".exe"
    $filePrint = Obter-Arquivo -url $urlPrint -nomeDestino $nomeArquivo
    
    Write-Host "  -> Instalando driver... (Aguarde o instalador)" -ForegroundColor Gray
    Start-Process $filePrint -ArgumentList "/S" -Wait
    Start-Sleep -Seconds 10

    # Garantir porta IP
    if (-not (Get-PrinterPort $ip -ErrorAction SilentlyContinue)) { 
        Add-PrinterPort -Name $ip -PrinterHostAddress $ip 
    }

    Write-Host "  -> Localizando impressora criada pelo instalador..." -ForegroundColor Gray

    # === LÓGICA UNIFICADA ===
    # Busca qualquer fila que contenha o filtro do driver OU seja Universal Samsung
    $filaEncontrada = Get-Printer | Where-Object {
        $_.Name -like "*$filtroDriverWindows*" -or 
        $_.DriverName -like "*$filtroDriverWindows*" -or
        $_.DriverName -like "*Samsung Universal*" -or 
        $_.Name -like "*Samsung Universal*"
    } | Select-Object -First 1

    try {
        if ($filaEncontrada) {
            Write-Host "  -> Fila detectada: $($filaEncontrada.Name)" -ForegroundColor Gray
            
            # SEMPRE força o driver correto (resolve M4080 e garante M4020/M4070)
            Set-Printer -Name $filaEncontrada.Name -DriverName $filtroDriverWindows -PortName $ip -ErrorAction Stop
            
            # Renomeia para o nome desejado
            Rename-Printer -Name $filaEncontrada.Name -NewName $novoNome -ErrorAction Stop
            
            Write-Host "  -> OK: Impressora configurada com sucesso!" -ForegroundColor Green
        } 
        else {
            # Caso extremo: nenhuma fila foi criada, criar do zero
            Add-Printer -Name $novoNome -DriverName $filtroDriverWindows -PortName $ip
            Write-Host "  -> OK: Fila criada manualmente!" -ForegroundColor Green
        }
    } catch {
        Write-Host "  -> ERRO: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  -> Tentando criar fila manualmente..." -ForegroundColor Yellow
        try {
            Add-Printer -Name $novoNome -DriverName $filtroDriverWindows -PortName $ip
            Write-Host "  -> OK: Fila criada com sucesso!" -ForegroundColor Green
        } catch {
            Write-Host "  -> FALHA: Verifique se o driver '$filtroDriverWindows' foi instalado corretamente." -ForegroundColor Red
        }
    }
    
    # === LIMPEZA DE DUPLICATAS ===
    Start-Sleep -Seconds 2
    Write-Host "  -> Verificando filas duplicadas..." -ForegroundColor Gray
    
    $todasImpressoras = Get-Printer
    $duplicatas = $todasImpressoras | Where-Object { 
        $_.Name -ne $novoNome -and  # Não é a impressora que configuramos
        (
            $_.Name -like "*$filtroDriverWindows*" -or 
            $_.DriverName -like "*$filtroDriverWindows*" -or
            ($_.DriverName -like "*Samsung Universal*" -and $_.Name -like "*Samsung Universal*")  # Remove Universal sobrando
        ) -and
        $_.Name -notlike "*Fax*"  # Protege filas de Fax
    }
    
    if ($duplicatas) {
        Write-Host "  -> Removendo filas duplicadas:" -ForegroundColor Yellow
        foreach ($dup in $duplicatas) {
            try {
                Remove-Printer -Name $dup.Name -Confirm:$false -ErrorAction Stop
                Write-Host "     * Removida: $($dup.Name)" -ForegroundColor Gray
            } catch {
                Write-Host "     * Falha ao remover: $($dup.Name)" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "  -> Nenhuma duplicata encontrada. OK!" -ForegroundColor Green
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
