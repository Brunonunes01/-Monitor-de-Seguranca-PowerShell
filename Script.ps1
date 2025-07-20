
#Bruno Henrique Borascho Nunes


# ==================== CONFIGURAÇÕES ====================
$configuracao = @{
    CaminhoFFmpeg = "C:\Users\bruno\.spotdl\ffmpeg.exe"
    DiretorioFotos = "C:\Fotos"
    DiretorioVideos = "C:\Videos"
    DiretorioLogs = "C:\Logs"
    DuracaoGravacao = 60
    IntervaloVerificacao = 2
    IntervaloStatus = 30
    AtivarFotos = $true
    AtivarGravacao = $true
    ProcessosMonitorados = @(
        "powershell", "cmd", "msedge", "firefox", 
        "regedit", "taskmgr", "WhatsApp", "Telegram", "Discord"                                            
    )
}

# ==================== VARIÁVEIS GLOBAIS ====================
$pidsConhecidos = @{}
$gravacoesAtivas = @{}
$contador = 0

# ==================== FUNÇÕES PRINCIPAIS ====================
function Initialize-Diretorios {
    @($configuracao.DiretorioFotos, $configuracao.DiretorioVideos, $configuracao.DiretorioLogs) | ForEach-Object {
        if (!(Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
    }
}

function Write-Log {
    param([string]$mensagem, [string]$nivel = "INFO")
    
    $dataHora = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entradaLog = "[$dataHora] [$nivel] $mensagem"
    
    # Saída no console com cores
    $cor = switch ($nivel) {
        "ERROR" { "Red" }
        "WARN" { "Yellow" }
        "SUCCESS" { "Green" }
        "ALERT" { "Magenta" }
        default { "White" }
    }
    
    Write-Host $entradaLog -ForegroundColor $cor
    
    # Arquivo de log
    try {
        $arquivoLog = Join-Path $configuracao.DiretorioLogs "monitor_$(Get-Date -Format 'yyyy-MM-dd').log"
        Add-Content -Path $arquivoLog -Value $entradaLog -ErrorAction SilentlyContinue
    } catch {}
}

function Get-PidsProcesso {
    param([string]$nomeProcesso)
    
    try {
        $processos = Get-Process -Name $nomeProcesso -ErrorAction SilentlyContinue
        return $processos ? $processos.Id : @()
    } catch { return @() }
}

function Get-ResolucaoTela {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $tela = [System.Windows.Forms.Screen]::PrimaryScreen
        $largura = $tela.Bounds.Width
        $altura = $tela.Bounds.Height
        return "${largura}x${altura}"
    } catch {
        return "1920x1080"  # Fallback padrão
    }
}

function Invoke-CapturaFoto {
    param([string]$nomeProcesso, [int]$pidProcesso = 0)
    
    if (!$configuracao.AtivarFotos) { return $null }
    
    $dataHora = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $nomeArquivo = "${nomeProcesso}_${pidProcesso}_${dataHora}.jpg"
    $caminhoArquivo = Join-Path $configuracao.DiretorioFotos $nomeArquivo
    
    Write-Log "📸 Capturando foto: $nomeProcesso (PID: $pidProcesso)" "ALERT"
    
    try {
        if (!(Test-Path $configuracao.CaminhoFFmpeg)) { throw "FFmpeg não encontrado" }
        
        $nomesCamera = @("USB2.0 HD UVC WebCam", "Integrated Camera", "USB Camera", "HD WebCam")
        
        foreach ($camera in $nomesCamera) {
            try {
                $argumentos = "-f dshow -i video=`"$camera`" -frames:v 1 -y `"$caminhoArquivo`""
                $processo = Start-Process -FilePath $configuracao.CaminhoFFmpeg -ArgumentList $argumentos -NoNewWindow -PassThru -Wait
                
                if ($processo.ExitCode -eq 0 -and (Test-Path $caminhoArquivo)) {
                    $tamanho = [math]::Round((Get-Item $caminhoArquivo).Length / 1KB, 2)
                    Write-Log "✅ Foto: $nomeArquivo ($tamanho KB)" "SUCCESS"
                    return $caminhoArquivo
                }
            } catch { continue }
        }
        
        Write-Log "❌ Falha ao capturar foto" "ERROR"
        return $null
    } catch {
        Write-Log "❌ Erro: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Start-GravacaoTela {
    param([string]$nomeProcesso, [int]$pidProcesso)
    
    if (!$configuracao.AtivarGravacao) { return }
    
    $chaveGravacao = "${nomeProcesso}_${pidProcesso}"
    if ($gravacoesAtivas.ContainsKey($chaveGravacao)) {
        Write-Log "⚠️ Gravação já ativa para $nomeProcesso (PID: $pidProcesso)" "WARN"
        return
    }
    
    $dataHora = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $nomeArquivo = "${nomeProcesso}_${pidProcesso}_${dataHora}.mp4"
    $caminhoArquivo = Join-Path $configuracao.DiretorioVideos $nomeArquivo
    
    try {
        $resolucaoTela = Get-ResolucaoTela
        Write-Log "🖥️ Resolução detectada: $resolucaoTela" "INFO"
        
        $argumentosFFmpeg = @(
            "-f", "gdigrab",
            "-framerate", "30",
            "-draw_mouse", "1",
            "-show_region", "1",
            "-offset_x", "0",
            "-offset_y", "0",
            "-video_size", $resolucaoTela,
            "-i", "desktop",
            "-t", "$($configuracao.DuracaoGravacao)",
            "-c:v", "libx264",
            "-preset", "ultrafast",
            "-tune", "zerolatency",
            "-crf", "23",
            "-pix_fmt", "yuv420p",
            "-movflags", "+faststart",
            "-profile:v", "baseline",
            "-level", "3.1",
            "-threads", "0",
            "-probesize", "10M",
            "-analyzeduration", "0",
            "-fflags", "+nobuffer",
            "-flags", "+low_delay",
            "-avoid_negative_ts", "make_zero",
            "-max_delay", "0",
            "-y",
            "`"$caminhoArquivo`""
        )
        
        Write-Log "🎥 Iniciando gravação DINÂMICA: $nomeProcesso (PID: $pidProcesso)" "ALERT"
        Write-Log "📊 Configuração: 30fps, Resolução: $resolucaoTela, Preset: ultrafast" "INFO"
        
        $scriptBloco = {
            param($caminhoFFmpeg, $argumentos, $arquivoSaida, $duracao)
            
            try {
                $infoProcesso = New-Object System.Diagnostics.ProcessStartInfo
                $infoProcesso.FileName = $caminhoFFmpeg
                $infoProcesso.Arguments = $argumentos -join " "
                $infoProcesso.UseShellExecute = $false
                $infoProcesso.CreateNoWindow = $true
                $infoProcesso.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
                
                $processo = [System.Diagnostics.Process]::Start($infoProcesso)
                $completo = $processo.WaitForExit(($duracao + 15) * 1000)
                
                if (!$completo) { 
                    $processo.Kill()
                    return @{ Sucesso = $false; Erro = "Timeout na gravação após $($duracao + 15)s" }
                }
                
                Start-Sleep -Seconds 3
                
                if (Test-Path $arquivoSaida) {
                    $infoArquivo = Get-Item $arquivoSaida
                    $tamanhoMB = [math]::Round($infoArquivo.Length / 1MB, 2)
                    
                    if ($infoArquivo.Length -gt 10000) {
                        return @{ 
                            Sucesso = $true
                            CaminhoArquivo = $arquivoSaida
                            TamanhoMB = $tamanhoMB
                            CodigoSaida = $processo.ExitCode
                        }
                    } else {
                        return @{ Sucesso = $false; Erro = "Arquivo muito pequeno: $($infoArquivo.Length) bytes" }
                    }
                } else {
                    return @{ Sucesso = $false; Erro = "Arquivo não foi criado" }
                }
            } catch {
                return @{ Sucesso = $false; Erro = $_.Exception.Message }
            }
        }
        
        $trabalho = Start-Job -ScriptBlock $scriptBloco -ArgumentList $configuracao.CaminhoFFmpeg, $argumentosFFmpeg, $caminhoArquivo, $configuracao.DuracaoGravacao
        
        $gravacoesAtivas[$chaveGravacao] = @{
            CaminhoArquivo = $caminhoArquivo
            HoraInicio = Get-Date
            NomeProcesso = $nomeProcesso
            PidProcesso = $pidProcesso
            Trabalho = $trabalho
            Resolucao = $resolucaoTela
        }
        
        Register-ObjectEvent -InputObject $trabalho -EventName StateChanged -Action {
            $trabalho = $Event.Sender
            if ($trabalho.State -eq 'Completed') {
                try {
                    $resultado = Receive-Job -Job $trabalho -ErrorAction SilentlyContinue
                    
                    if ($resultado -and $resultado.Sucesso) {
                        Write-Log "✅ Gravação DINÂMICA concluída: $($resultado.CaminhoArquivo) ($($resultado.TamanhoMB) MB)" "SUCCESS"
                        if ($resultado.CodigoSaida -ne 0) {
                            Write-Log "⚠️ FFmpeg exit code: $($resultado.CodigoSaida)" "WARN"
                        }
                    } else {
                        Write-Log "❌ Falha na gravação: $($resultado.Erro)" "ERROR"
                        
                        if ($resultado.CaminhoArquivo -and (Test-Path $resultado.CaminhoArquivo)) {
                            try {
                                Remove-Item $resultado.CaminhoArquivo -Force -ErrorAction SilentlyContinue
                                Write-Log "🗑️ Arquivo corrompido removido" "INFO"
                            } catch {}
                        }
                    }
                } catch {
                    Write-Log "❌ Erro ao processar resultado: $($_.Exception.Message)" "ERROR"
                } finally {
                    $chaveGravacao = $gravacoesAtivas.Keys | Where-Object { $gravacoesAtivas[$_].Trabalho.Id -eq $trabalho.Id } | Select-Object -First 1
                    if ($chaveGravacao) { $gravacoesAtivas.Remove($chaveGravacao) }
                    
                    Remove-Job -Job $trabalho -Force -ErrorAction SilentlyContinue
                    Unregister-Event -SourceIdentifier $Event.SourceIdentifier -ErrorAction SilentlyContinue
                }
            }
        } | Out-Null
        
    } catch {
        Write-Log "❌ Erro ao iniciar gravação: $($_.Exception.Message)" "ERROR"
    }
}

function Show-Status {
    $processosAtivos = @()
    foreach ($nomeProcesso in $configuracao.ProcessosMonitorados) {
        if ($pidsConhecidos[$nomeProcesso].Count -gt 0) {
            $processosAtivos += $nomeProcesso
        }
    }
    
    $dataHora = Get-Date -Format "HH:mm:ss"
    Write-Log "👁️ [$dataHora] Processos ativos: $($processosAtivos -join ', ')" "INFO"
    
    if ($gravacoesAtivas.Count -gt 0) {
        $detalhesGravacoes = @()
        foreach ($gravacao in $gravacoesAtivas.Values) {
            $tempoDecorrido = [math]::Round(((Get-Date) - $gravacao.HoraInicio).TotalSeconds, 0)
            $detalhesGravacoes += "$($gravacao.NomeProcesso)($($tempoDecorrido)s)"
        }
        Write-Log "🎬 Gravações ativas ($($gravacoesAtivas.Count)): $($detalhesGravacoes -join ', ')" "INFO"
    }
}

# ==================== INICIALIZAÇÃO ====================
Initialize-Diretorios

Write-Log "🔒 MONITOR DE SEGURANÇA INICIADO" "SUCCESS"
Write-Log "📊 Monitorando $($configuracao.ProcessosMonitorados.Count) processos" "INFO"
Write-Log "🖥️ Resolução da tela: $(Get-ResolucaoTela)" "INFO"
Write-Log "💡 Pressione Ctrl+C para parar" "INFO"

# Inicializar PIDs conhecidos
foreach ($nomeProcesso in $configuracao.ProcessosMonitorados) {
    $pidsConhecidos[$nomeProcesso] = Get-PidsProcesso -nomeProcesso $nomeProcesso
}

# ==================== LOOP PRINCIPAL ====================
try {
    while ($true) {
        Start-Sleep -Seconds $configuracao.IntervaloVerificacao
        $contador++
        
        foreach ($nomeProcesso in $configuracao.ProcessosMonitorados) {
            $pidsAtuais = Get-PidsProcesso -nomeProcesso $nomeProcesso
            $pidsAnteriores = $pidsConhecidos[$nomeProcesso]
            
            foreach ($pidAtual in $pidsAtuais) {
                if ($pidAtual -notin $pidsAnteriores) {
                    Write-Log "🚨 NOVO PROCESSO: $nomeProcesso (PID: $pidAtual)" "ALERT"
                    Invoke-CapturaFoto -nomeProcesso $nomeProcesso -pidProcesso $pidAtual
                    Start-GravacaoTela -nomeProcesso $nomeProcesso -pidProcesso $pidAtual
                }
            }
            
            $pidsConhecidos[$nomeProcesso] = $pidsAtuais
        }
        
        Get-Job | Where-Object { $_.State -eq 'Completed' -or $_.State -eq 'Failed' } | Remove-Job -Force -ErrorAction SilentlyContinue
        
        if ($contador % ($configuracao.IntervaloStatus / $configuracao.IntervaloVerificacao) -eq 0) {
            Show-Status
            Write-Host ""
        }
    }
} finally {
    Write-Log "🛑 Parando todas as gravações..." "WARN"
    foreach ($gravacao in $gravacoesAtivas.Values) {
        try {
            if ($gravacao.Trabalho -and $gravacao.Trabalho.State -eq 'Running') {
                Stop-Job -Job $gravacao.Trabalho -ErrorAction SilentlyContinue
            }
        } catch {}
    }
    
    Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
    Write-Host "`n🔒 Monitor de segurança finalizado" -ForegroundColor Yellow
}
#para listar os dispositivo, para saber o id da câmera: ffmpeg -list_devices true -f dshow -i dummy#

# Initialize-Diretorios
# Cria as pastas de Fotos, Vídeos e Logs se elas não existirem.

# Write-Log
# Exibe e salva mensagens de log no console e em um arquivo de texto com data e hora.

# Get-PidsProcesso
# Retorna os PIDs (códigos dos processos) de um processo pelo nome.

# Get-ResolucaoTela
# Pega a resolução atual da tela do computador.

# Invoke-CapturaFoto
# Usa o FFmpeg para tirar uma foto pela webcam e salva com nome do processo e PID.

# Start-GravacaoTela
# Inicia uma gravação da tela quando um processo monitorado for detectado, com configurações específicas do FFmpeg.

# Show-Status
# Exibe no console quais processos monitorados estão ativos e quais gravações estão em andamento.

# =======================
# Fora das funções:
# - Define as configurações (pastas, duração, processos a monitorar).
# - Inicializa as pastas e variáveis.
# - Entra em um loop infinito que:
#     - Verifica a cada poucos segundos se um processo novo apareceu.
#     - Se sim, tira uma foto e começa a gravar a tela.
#     - Mostra status de tempos em tempos.
#     - Encerra todas as gravações ao finalizar.
