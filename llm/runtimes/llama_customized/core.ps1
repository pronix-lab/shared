# CORE
param([string]$ProfileName = "")


## PATHS | 경로
$Here                  = $PSScriptRoot
$Root                  = (Resolve-Path (Join-Path $Here "..\..")).Path
$ModelDir              = Join-Path $Root "model"
$LlamaVer              = "_source\b12549__cuda_12.4"




## CONFIGURATION | 설정
$Common                = @{
    Ngl                = 29                                           # GPU layers (99 = all)
    NCpuMoe            = 0                                            # MoE expert layers on CPU (0 = off)
    KvK                = "q8_0"                                       # K cache type
    KvV                = "q8_0"                                       # V cache type

    PresencePenalty    = 0
    Temperature        = 1.0

    TopP               = 0.95
    TopK               = 20
    MinP               = 0

    ReasoningBudget    = -1                                           # -1 = unlimited
    BindHost           = "127.0.0.1"
    Port               = 8080
                         }




## PROFILES | 프로파일
$Profiles                 = [ordered] @{

    "Qwen 3.6 35B UD-Q2"   = @{
        Alias             = "Qwen 3.6 35B-A3B UD-Q2"

        Model             = "qwen-3-6_35b-a3b_ud-q2_K_xl.gguf"        # Provided by Unsloth
        Desc              = "MoE"                                     # Desription to display (text)    |    화면에 표시할 설명 문구
        Ctx               = 33000                                     # Context window size             |    컨텍스트 윈도우 크기
        Ngl               = 99
        NCpuMoe           = 28
        PresencePenalty   = 0.0
                            }

    "GPT OSS 20B"         = @{
        Alias             = "GPT OSS 20B-MXFP4"
        Model             = "gpt-oss-20b-MXFP4.gguf"
        Desc              = "MoE, OpenAI"
        ReasoningEffort   = "medium"
        Ctx               = 33000
        Ngl               = 99
        NCpuMoe           = 12
        KvK               = "f16"
        KvV               = "f16"
        Temperature       = 1.0
        TopP              = 1.0
        TopK              = 0
        PresencePenalty   = 0.0
                            }

    "Qwen 3.5 9B-UDQ4"    = @{
        Alias             = "Qwen 3.5 9B UD-Q4"
        Model             = "Qwen3.5-9B-UD-Q4_K_XL__unsloth.gguf"
        Desc              = "Balanced"
        Ctx               = 77000
                            }

    "Qwen 3.5_9B-IQ4"     = @{
        Alias             = "Qwen3.5 9B-IQ4"
        Model             = "Qwen3.5-9B-IQ4_XS__unsloth.gguf"
        Desc              = "Efficient"
        Ctx               = 110000
                            }}



## FUNCTIONS | 함수
function Stop-WithError([string]$Message) {
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    Read-Host  "Press Enter to exit"
    exit 1 }




## PROFILE SELECTION
$names = @($Profiles.Keys)

if (-not $ProfileName) {
    for ($i = 0; $i -lt $names.Count; $i++) {
        Write-Host ("{0}. {1,-8} - {2}" -f ($i + 1), $names[$i], $Profiles[$names[$i]].Desc) }
    Write-Host ""
    $ProfileName = Read-Host "Select number or name" }

if ($ProfileName -match '^\d+$') {
    $idx = [int]$ProfileName - 1
    if ($idx -ge 0 -and $idx -lt $names.Count) {
        $ProfileName = $names[$idx] } }

if (-not $Profiles.Contains($ProfileName)) {
    Stop-WithError "Unknown profile: $ProfileName" }

$cfg = $Common.Clone()
foreach ($k in $Profiles[$ProfileName].Keys) {
    $cfg[$k] = $Profiles[$ProfileName][$k] }




## EXECUTABLE
$LlamaExe = Join-Path $Here "$LlamaVer\llama-server.exe"

if (-not (Test-Path $LlamaExe)) {
    $found = Get-ChildItem -Path $Here -Filter "llama-server.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $LlamaExe = $found.FullName }
    else {
        Stop-WithError "llama-server.exe not found under: $Here" } }




## MODEL
$ModelPath = Join-Path $ModelDir $cfg.Model

if (-not (Test-Path $ModelPath)) {
    Write-Host "Files in model folder:"
    Get-ChildItem -Path $ModelDir -Filter "*.gguf" | ForEach-Object {
        Write-Host "$($_.Name)" }
    Stop-WithError "Model file not found: $ModelPath" }




## ARGUMENTS
$llamaArgs                  = @(
    "-m"                    , $ModelPath
    "-ngl"                  , $cfg.Ngl
    "-fa"                   , "on"
    "-c"                    , $cfg.Ctx
    "-ctk"                  , $cfg.KvK, "-ctv", $cfg.KvV
    "--temp"                , $cfg.Temperature
    "--top-p"               , $cfg.TopP
    "--top-k"               , $cfg.TopK
    "--min-p"               , $cfg.MinP
    "--presence-penalty"    , $cfg.PresencePenalty
    "-np"                   , 1
    "--host"                , $cfg.BindHost
    "--port"                , $cfg.Port
                            )

if ($cfg.ReasoningBudget -ge 0) {
    $llamaArgs += @("--reasoning-budget", $cfg.ReasoningBudget) }
if ($cfg.NCpuMoe -gt 0) {
    $llamaArgs += @("--n-cpu-moe", $cfg.NCpuMoe) }
if ($cfg.ReasoningEffort) {
    $llamaArgs += @("--reasoning-effort", $cfg.ReasoningEffort) }
if ($cfg.Alias) {
    $llamaArgs += @("--alias", $cfg.Alias) }




## ENVIRONMNET
# only for this process (not saved to the system)
$env:CUDA_CACHE_DISABLE = "1"




## EXECUTION
Write-Host  ""
Write-Host  "Profile     : $ProfileName"
Write-Host  "Alias       : $($cfg.Alias)"
Write-Host  "llama       : $LlamaExe"
Write-Host  "Model       : $($cfg.Model)"
Write-Host  "Context     : $($cfg.Ctx)   GPU layers: $($cfg.Ngl)   KV: $($cfg.KvK)/$($cfg.KvV)"
Write-Host  "Sampling    : temp $($cfg.Temperature), top_p $($cfg.TopP), top_k $($cfg.TopK), presence $($cfg.PresencePenalty)"
Write-Host  "URL         : http://$($cfg.BindHost):$($cfg.Port)"
Write-Host  ""




& $LlamaExe @llamaArgs

Read-Host "Press Enter to exit"
