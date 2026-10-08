# Настройка Kimi Code и GLM Coding Plan на Windows. Совместимо с PowerShell 5.1+.
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('kimi', 'glm')]
    [string]$Provider
)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Этот установщик предназначен для Windows.' }

$taskUserRoot = [Environment]::GetFolderPath('UserProfile')
$profileDir = Join-Path $taskUserRoot '.config\china-models'
$profileFile = Join-Path $profileDir "$Provider.json"
$stateFile = Join-Path $taskUserRoot '.claude.json'
$binDir = Join-Path $taskUserRoot '.local\bin'
$env:PATH = "$binDir;$env:PATH"
$backupSuffix = '.china-models-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmssfff') + "-$PID"
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Read-JsonObject([string]$File) {
    if (-not (Test-Path -LiteralPath $File)) { return [pscustomobject]@{} }
    try {
        $value = Get-Content -LiteralPath $File -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch { throw "Некорректный JSON в $File. Файл не изменён." }
    if ($null -eq $value -or $value -isnot [pscustomobject]) {
        throw "В $File должен быть объект JSON. Файл не изменён."
    }
    return $value
}

function Protect-Path([string]$File, [bool]$Directory = $false) {
    $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    if ($Directory) {
        $acl = New-Object System.Security.AccessControl.DirectorySecurity
        $inherit = [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit'
    } else {
        $acl = New-Object System.Security.AccessControl.FileSecurity
        $inherit = [System.Security.AccessControl.InheritanceFlags]::None
    }
    $acl.SetOwner($sid)
    $acl.SetAccessRuleProtection($true, $false)
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $sid, [System.Security.AccessControl.FileSystemRights]::FullControl,
        $inherit, [System.Security.AccessControl.PropagationFlags]::None,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
    $acl.AddAccessRule($rule)
    Set-Acl -LiteralPath $File -AclObject $acl
}

function Save-WithBackup([string]$File, [string]$Content, [bool]$Private = $false) {
    if (Test-Path -LiteralPath $File) {
        $backup = "$File$backupSuffix"
        Copy-Item -LiteralPath $File -Destination $backup -ErrorAction Stop
        if ($Private) { Protect-Path $backup }
    }
    $temp = "$File.tmp-$([Guid]::NewGuid().ToString('N'))"
    try {
        [System.IO.File]::WriteAllText($temp, $Content, $utf8)
        if ($Private) { Protect-Path $temp }
        Move-Item -LiteralPath $temp -Destination $File -Force
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp }
    }
}

# Проверяем существующие настройки до их изменения.
$saved = Read-JsonObject $profileFile
$state = Read-JsonObject $stateFile
if ($Provider -eq 'kimi') {
    Write-Host 'Подписка Kimi Code: https://api.kimi.ai/coding/'
    Write-Host 'Ключ: https://www.kimi.ai/code/console'
    Write-Host '1 - K3 256K: Plus и выше'
    Write-Host '2 - K3 1M: Pro и выше'
    Write-Host '3 - K2.8 Preview: Plus и выше'
    Write-Host '4 - HighSpeed: Pro и выше'
    $choice = Read-Host 'Выбери модель [1-4, Enter = 1]'
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }
    switch ($choice) {
        '1' { $model = 'k3-256k'; $context = '262144' }
        '2' { $model = 'k3[1m]'; $context = '1048576' }
        '3' { $model = 'kimi-for-coding'; $context = '1048576' }
        '4' { $model = 'kimi-for-coding-highspeed'; $context = '262144' }
        default { throw 'Нужен номер от 1 до 4. Повтори настройку.' }
    }
    $baseUrl = 'https://api.kimi.ai/coding/'
} else {
    Write-Host 'Подписка GLM Coding Plan. Ключ: https://z.ai/manage-apikey/apikey-list'
    Write-Host '1 - GLM-5.3: сложная логика и разработка'
    Write-Host '2 - GLM-5.3-Flash: повседневная работа и скриншоты'
    $choice = Read-Host 'Выбери модель [1-2, Enter = 1]'
    if ([string]::IsNullOrWhiteSpace($choice)) { $choice = '1' }
    switch ($choice) {
        '1' { $model = 'glm-5.3[1m]' }
        '2' { $model = 'glm-5.3-flash[1m]' }
        default { throw 'Нужен номер 1 или 2. Повтори настройку.' }
    }
    $context = '1000000'
    $baseUrl = 'https://api.z.ai/api/anthropic'
}
Write-Host 'Вставь ключ. Символы не отображаются. При повторной настройке Enter сохраняет ключ.'
$secureKey = Read-Host 'Ключ подключения' -AsSecureString
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureKey)
try { $key = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer); $secureKey.Dispose() }
if ([string]::IsNullOrEmpty($key)) { $key = $saved.env.ANTHROPIC_AUTH_TOKEN }
if ([string]::IsNullOrEmpty($key)) { throw 'Ключ не введён. Повтори настройку.' }
if ($key -match '\s') { throw 'В ключе есть пробелы или переносы строк. Скопируй его заново.' }

if (-not (Get-Command claude -CommandType Application -ErrorAction SilentlyContinue)) {
    Write-Host 'Устанавливаем Claude Code...'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-RestMethod 'https://claude.ai/install.ps1' | Invoke-Expression
}
if (-not (Get-Command claude -CommandType Application -ErrorAction SilentlyContinue)) {
    throw 'Claude Code не найден. Открой новое окно PowerShell и повтори настройку.'
}

$modelEnv = [ordered]@{
    ANTHROPIC_BASE_URL = $baseUrl
    ANTHROPIC_AUTH_TOKEN = $key
    ANTHROPIC_API_KEY = ''
    CLAUDE_CODE_OAUTH_TOKEN = ''
    ANTHROPIC_SMALL_FAST_MODEL = ''
    CLAUDE_CODE_USE_BEDROCK = '0'
    CLAUDE_CODE_USE_VERTEX = '0'
    CLAUDE_CODE_USE_FOUNDRY = '0'
    ANTHROPIC_MODEL = $model
    ANTHROPIC_DEFAULT_FABLE_MODEL = $model
    ANTHROPIC_DEFAULT_OPUS_MODEL = $model
    ANTHROPIC_DEFAULT_SONNET_MODEL = $model
    ANTHROPIC_DEFAULT_HAIKU_MODEL = $model
    CLAUDE_CODE_SUBAGENT_MODEL = $model
    CLAUDE_CODE_AUTO_COMPACT_WINDOW = $context
    CLAUDE_CODE_MAX_CONTEXT_TOKENS = $context
    CLAUDE_CODE_EFFORT_LEVEL = 'high'
}
if ($Provider -eq 'glm') {
    $modelEnv.ANTHROPIC_DEFAULT_HAIKU_MODEL = 'glm-5.3-flash[1m]'
    $modelEnv.CLAUDE_CODE_EFFORT_LEVEL = 'max'
    $modelEnv['CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC'] = '1'
    $modelEnv['API_TIMEOUT_MS'] = '3000000'
}
$profileText = @{ env = $modelEnv } | ConvertTo-Json -Depth 100
$key = $null
New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
Protect-Path $profileDir $true
New-Item -ItemType Directory -Path $binDir -Force | Out-Null
Save-WithBackup $profileFile $profileText $true
if (-not $state.hasCompletedOnboarding) {
    $state | Add-Member -NotePropertyName hasCompletedOnboarding -NotePropertyValue $true -Force
    Save-WithBackup $stateFile ($state | ConvertTo-Json -Depth 100) $true
}

# Профиль передаётся через --settings; ключ не появляется в аргументах процесса.
$runner = @'
$ErrorActionPreference = 'Stop'
$taskUserRoot = [Environment]::GetFolderPath('UserProfile')
$env:PATH = "$(Join-Path $taskUserRoot '.local\bin');$env:PATH"
$profileFile = Join-Path $PSScriptRoot '__PROVIDER__.json'
if (-not (Test-Path -LiteralPath $profileFile)) { throw 'Повтори настройку через setup.ps1.' }
$vars = @(
    'CLAUDE_CONFIG_DIR', 'ANTHROPIC_BASE_URL', 'ANTHROPIC_API_KEY', 'ANTHROPIC_AUTH_TOKEN',
    'CLAUDE_CODE_OAUTH_TOKEN', 'ANTHROPIC_MODEL', 'ANTHROPIC_SMALL_FAST_MODEL',
    'CLAUDE_CODE_SUBAGENT_MODEL', 'ANTHROPIC_DEFAULT_FABLE_MODEL',
    'ANTHROPIC_DEFAULT_OPUS_MODEL', 'ANTHROPIC_DEFAULT_SONNET_MODEL', 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
    'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX', 'CLAUDE_CODE_USE_FOUNDRY',
    'CLAUDE_CODE_AUTO_COMPACT_WINDOW', 'CLAUDE_CODE_MAX_CONTEXT_TOKENS', 'CLAUDE_CODE_EFFORT_LEVEL'
)
foreach ($name in $vars) { [Environment]::SetEnvironmentVariable($name, $null, 'Process') }
$claudeCommand = Get-Command claude -CommandType Application -ErrorAction Stop | Select-Object -First 1
& $claudeCommand.Source --settings $profileFile @args
exit $LASTEXITCODE
'@
$runner = $runner.Replace('__PROVIDER__', $Provider)
Save-WithBackup (Join-Path $profileDir "claude-$Provider.ps1") $runner $true
$launcher = "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%USERPROFILE%\.config\china-models\claude-$Provider.ps1`" %*`r`nexit /b %errorlevel%`r`n"
Save-WithBackup (Join-Path $binDir "claude-$Provider.cmd") $launcher

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$pathItems = @($userPath -split ';' | Where-Object { $_ })
$hasBin = @($pathItems | Where-Object {
    [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') -ieq $binDir.TrimEnd('\')
}).Count -gt 0
if (-not $hasBin) {
    Save-WithBackup (Join-Path $profileDir "user-path$backupSuffix.txt") ([string]$userPath) $true
    [Environment]::SetEnvironmentVariable('Path', (($pathItems + $binDir) -join ';'), 'User')
}
Write-Host "Готово. Модель: $model"
Write-Host "Закрой терминал полностью, открой новый и запусти: claude-$Provider"
Write-Host 'Внутри сессии введи /status, чтобы проверить подключение.'
