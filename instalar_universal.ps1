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

# --- ETAPA: IMPRESSAO (LÓGICA HÍBRIDA ORIGINAL + REMOÇÃO DE DUPLICATAS + VALIDAÇÕES) ---
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

    Write-Host "  -> Localizando impressora para configuracao..." -ForegroundColor Gray

    # === LÓGICA HÍBRIDA ORIGINAL (ESSENCIAL) ===
    # 1. Tenta achar pelo nome do Driver (Caso M4070/M4020)
    $impEspecifica = Get-Printer | Where-Object {
        $_.Name -like "*$filtroDriverWindows*" -or 
        $_.DriverName -like "*$filtroDriverWindows*"
    } | Select-Object -First 1
    
    # 2. Se não achar, tenta achar pela Genérica/Universal (Caso M4080)
    $impGenerica = $null
    if (-not $impEspecifica) {
        $impGenerica = Get-Printer | Where-Object {
            $_.DriverName -like "*Samsung Universal*" -or 
            $_.Name -like "*Samsung Universal*"
        } | Select-Object -First 1
    }

    try {
        if ($impEspecifica) {
            # Se achou a fila específica (M4070/M4020), apenas aponta o IP e renomeia
            Write-Host "  -> Fila especifica detectada: $($impEspecifica.Name)" -ForegroundColor Gray
            Set-Printer -Name $impEspecifica.Name -PortName $ip -ErrorAction Stop
            Rename-Printer -Name $impEspecifica.Name -NewName $novoNome -ErrorAction Stop
            Write-Host "  -> OK: Impressora especifica configurada!" -ForegroundColor Green
        } 
        elseif ($impGenerica) {
            # Se achou a Universal (M4080), troca o driver para o específico e renomeia
            Write-Host "  -> Fila Universal detectada: $($impGenerica.Name)" -ForegroundColor Gray
            Write-Host "  -> Trocando para driver especifico: $filtroDriverWindows" -ForegroundColor Gray
            Set-Printer -Name $impGenerica.Name -DriverName $filtroDriverWindows -PortName $ip -ErrorAction Stop
            Rename-Printer -Name $impGenerica.Name -NewName $novoNome -ErrorAction Stop
            Write-Host "  -> OK: Fila Universal convertida para especifica!" -ForegroundColor Green
        } 
        else {
            # Se o instalador não criou nada, cria do zero
            Write-Host "  -> Nenhuma fila detectada. Criando do zero..." -ForegroundColor Yellow
            Add-Printer -Name $novoNome -DriverName $filtroDriverWindows -PortName $ip -ErrorAction Stop
            Write-Host "  -> OK: Fila criada manualmente do zero!" -ForegroundColor Green
        }
    } catch {
        Write-Host "  -> ERRO: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  -> Detalhes completos do erro:" -ForegroundColor Red
        Write-Host ($_.Exception | Format-List -Force | Out-String)
        Read-Host "Pressione ENTER para continuar e tentar criar fila manualmente"
        
        Write-Host "  -> Tentando criar fila manualmente..." -ForegroundColor Yellow
        try {
            Add-Printer -Name $novoNome -DriverName $filtroDriverWindows -PortName $ip -ErrorAction Stop
            Write-Host "  -> OK: Fila criada com sucesso!" -ForegroundColor Green
        } catch {
            Write-Host "  -> FALHA CRITICA: Nao foi possivel criar a fila" -ForegroundColor Red
            Write-Host "  -> Erro detalhado:" -ForegroundColor Red
            Write-Host ($_.Exception | Format-List -Force | Out-String)
            Write-Host "  -> Drivers disponiveis no sistema:" -ForegroundColor Yellow
            Get-PrinterDriver | Where-Object { $_.Name -like "*Samsung*" } | ForEach-Object { 
                Write-Host "     * $($_.Name)" -ForegroundColor Cyan 
            }
            Read-Host "Pressione ENTER para voltar ao menu"
            $etapaAtual++
            continue
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
            $_.DriverName -like "*$filtroDriverWindows*"
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
                Write-Host "       Motivo: $($_.Exception.Message)" -ForegroundColor Red
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
