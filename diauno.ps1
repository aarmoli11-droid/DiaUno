<#
.SYNOPSIS
    DiaUno: diagnostico, ejecucion local, compilacion web y despliegue en Firebase Hosting.

.DESCRIPTION
    Unico punto de entrada para el proyecto. Nunca muestra valores de .env.local y
    nunca escribe sobre ese archivo. Los defines de Flutter se generan en un JSON
    temporal fuera del repositorio y se eliminan al terminar, incluso si falla.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('doctor', 'run', 'build', 'deploy', 'help')]
    [string]$Command = 'help',

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ErrorActionPreference = 'Continue'

$ProjectRoot = $PSScriptRoot
$ExpectedFirebaseProject = 'flutter1-b1fc8'
$PublicHostingDir = 'build/web'
$SiteUrl = 'https://flutter1-b1fc8.web.app'
$EnvFile = Join-Path $ProjectRoot '.env.local'
$FirebaseConfig = Join-Path $ProjectRoot 'firebase.json'
$Firebaserc = Join-Path $ProjectRoot '.firebaserc'
$IndexHtml = Join-Path $ProjectRoot 'build/web/index.html'

# Variables que la aplicacion lee en lib/core/config/env.dart.
$AppEnvKeys = @(
    'SUPABASE_URL',
    'SUPABASE_ANON_KEY',
    'SUPABASE_PUBLISHABLE_KEY',
    'SUPABASE_PROJECT_REF',
    'ENABLE_GOOGLE_OAUTH'
)

# Patron solo para nombres. Nunca se imprimen valores.
$SecretNamePattern = 'SERVICE|SECRET|PASSWORD|PRIVATE|DATABASE|DB_|CREDENTIAL'

function Protect-Output {
    param([string]$Text)
    return $Text -replace 'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+', '<jwt>' `
                  -replace 'sb_secret_[A-Za-z0-9_-]+', '<secreto>' `
                  -replace 'sb_publishable_[A-Za-z0-9_-]+', '<publicable>'
}

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-WarnMsg {
    param([string]$Message)
    Write-Host "[AVISO] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Fail {
    param([string]$Message)
    throw $Message
}

function Get-ToolPath {
    param([string]$Name)

    $all = @(Get-Command $Name -ErrorAction SilentlyContinue -All)
    if ($all.Count -eq 0) {
        Fail "No se encontro '$Name' en el PATH del sistema."
    }

    foreach ($extension in @('.exe', '.cmd', '.bat', '.ps1')) {
        $hit = $all | Where-Object { [System.IO.Path]::GetExtension($_.Source) -ieq $extension } | Select-Object -First 1
        if ($hit) { return $hit.Source }
    }
    return $all[0].Source
}

function Invoke-Native {
    param(
        [string]$Executable,
        [string[]]$Arguments = @(),
        [string]$Description,
        [switch]$Capture
    )

    Write-Step $Description
    if ($Capture) {
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $output = & $Executable @Arguments 2>&1 | Out-String
        }
        finally {
            $ErrorActionPreference = $previous
        }
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            if (-not [string]::IsNullOrWhiteSpace($output)) {
                Write-Host (Protect-Output -Text $output) -ForegroundColor DarkGray
            }
            Fail "$Description fallo con codigo de salida $code."
        }
        return $output
    }

    & $Executable @Arguments
    $code = $LASTEXITCODE
    if ($code -ne 0) { Fail "$Description fallo con codigo de salida $code." }
}

function Read-EnvFile {
    if (-not (Test-Path -LiteralPath $EnvFile -PathType Leaf)) {
        Fail 'No se encontro .env.local en la raiz del proyecto.'
    }

    $raw = Get-Content -LiteralPath $EnvFile -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        Fail '.env.local esta vacio.'
    }

    $values = @{}
    $firstLine = ($raw -split "`r?`n" | Where-Object {
        $t = $_.Trim()
        $t -ne '' -and -not $t.StartsWith('#') -and -not $t.StartsWith(';')
    } | Select-Object -First 1)

    if ($firstLine -and $firstLine.Trim().StartsWith('{')) {
        $script:EnvFormat = 'JSON'
        try {
            $obj = $raw | ConvertFrom-Json
        }
        catch {
            Fail ('.env.local parece JSON pero no es valido: ' + $_.Exception.Message)
        }
        foreach ($property in $obj.PSObject.Properties) {
            $values[$property.Name] = [string]$property.Value
        }
    }
    else {
        $script:EnvFormat = 'dotenv'
        foreach ($line in ($raw -split "`r?`n")) {
            $text = $line.Trim()
            if ($text -eq '' -or $text.StartsWith('#') -or $text.StartsWith(';')) { continue }
            if ($text.StartsWith('export ')) { $text = $text.Substring(7).Trim() }

            $match = [regex]::Match($text, '^([^=]+)=(.*)$')
            if (-not $match.Success) {
                Fail 'Hay una linea no valida en .env.local; se espera el formato CLAVE=VALOR.'
            }
            $key = $match.Groups[1].Value.Trim()
            $value = $match.Groups[2].Value.Trim()
            if ($value.Length -ge 2 -and (
                ($value.StartsWith('"') -and $value.EndsWith('"')) -or
                ($value.StartsWith("'") -and $value.EndsWith("'")))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            $values[$key] = $value
        }
    }

    if ($values.ContainsKey('ENABLE_GOOGLE_OAUTH')) {
        $values['ENABLE_GOOGLE_OAUTH'] = ([string]$values['ENABLE_GOOGLE_OAUTH']).ToLowerInvariant()
    }
    return $values
}

function Get-JwtRole {
    param([string]$Value)

    if ($Value -notmatch '^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$') { return $null }
    try {
        $payload = $Value.Split('.')[1].Replace('-', '+').Replace('_', '/')
        while (($payload.Length % 4) -ne 0) { $payload += '=' }
        $json = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
        return [string]$json.role
    }
    catch {
        return $null
    }
}

function Test-SecretVariable {
    param(
        [string]$Name,
        [string]$Value
    )

    if ($Name -match $SecretNamePattern) { return $true }
    if ($Value -match 'sb_secret_|service_role') { return $true }

    $role = Get-JwtRole -Value $Value
    if ($role -and $role -notin @('anon', 'authenticated')) { return $true }
    return $false
}

function Get-PublicDefines {
    param([hashtable]$Values)

    $defines = @{}
    foreach ($key in $AppEnvKeys) {
        if (-not $Values.ContainsKey($key)) { continue }
        $value = [string]$Values[$key]
        if ([string]::IsNullOrWhiteSpace($value)) { continue }
        if (Test-SecretVariable -Name $key -Value $value) {
            Fail "La variable '$key' parece secreta y no puede inyectarse en Flutter Web."
        }
        $defines[$key] = $value
    }
    return $defines
}

function Assert-RequiredVariables {
    param([hashtable]$Values)

    $errors = @()
    $warnings = @()

    $url = if ($Values.ContainsKey('SUPABASE_URL')) { [string]$Values['SUPABASE_URL'] } else { '' }
    $anon = if ($Values.ContainsKey('SUPABASE_ANON_KEY')) { [string]$Values['SUPABASE_ANON_KEY'] } else { '' }
    $publishable = if ($Values.ContainsKey('SUPABASE_PUBLISHABLE_KEY')) { [string]$Values['SUPABASE_PUBLISHABLE_KEY'] } else { '' }
    $projectRef = if ($Values.ContainsKey('SUPABASE_PROJECT_REF')) { [string]$Values['SUPABASE_PROJECT_REF'] } else { '' }

    if ([string]::IsNullOrWhiteSpace($url)) {
        $errors += 'Falta SUPABASE_URL o esta vacia.'
    }
    elseif ($url -notmatch '^https://') {
        $errors += 'SUPABASE_URL debe comenzar con https://.'
    }

    if ([string]::IsNullOrWhiteSpace($anon) -and [string]::IsNullOrWhiteSpace($publishable)) {
        $errors += 'Falta una clave publica: SUPABASE_PUBLISHABLE_KEY o SUPABASE_ANON_KEY.'
    }
    if ([string]::IsNullOrWhiteSpace($anon)) {
        $warnings += 'SUPABASE_ANON_KEY no esta definida (legacy).'
    }
    if ([string]::IsNullOrWhiteSpace($publishable)) {
        $warnings += 'SUPABASE_PUBLISHABLE_KEY no esta definida; se usara la clave anon.'
    }
    if ([string]::IsNullOrWhiteSpace($projectRef)) {
        $warnings += 'SUPABASE_PROJECT_REF no esta definida (no es obligatoria para la app).'
    }
    if (-not $Values.ContainsKey('ENABLE_GOOGLE_OAUTH')) {
        $warnings += 'ENABLE_GOOGLE_OAUTH no esta definida; la app usa false por defecto.'
    }

    # Falla si alguna variable que se va a inyectar parece secreta.
    $null = Get-PublicDefines -Values $Values

    return @{ Errors = $errors; Warnings = $warnings }
}

function Assert-ProjectLayout {
    $required = @('pubspec.yaml', 'firebase.json', '.firebaserc', 'lib\core\config\env.dart')
    foreach ($relative in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $relative) -PathType Leaf)) {
            Fail "Falta el archivo del proyecto: $relative"
        }
    }

    $pubspec = Get-Content -LiteralPath (Join-Path $ProjectRoot 'pubspec.yaml') -Raw
    if ($pubspec -notmatch '(?m)^name:\s*diauno\s*$') {
        Fail 'pubspec.yaml no corresponde al proyecto DiaUno.'
    }
    Write-Ok "Proyecto DiaUno localizado en $ProjectRoot"
}

function Assert-FirebaseConfig {
    try {
        $config = Get-Content -LiteralPath $FirebaseConfig -Raw | ConvertFrom-Json
    }
    catch {
        Fail 'firebase.json no es un JSON valido.'
    }
    if ([string]$config.hosting.public -ne $PublicHostingDir) {
        Fail "firebase.json debe publicar '$PublicHostingDir'."
    }
    Write-Ok "firebase.json publica $PublicHostingDir"
}

function Assert-FirebaseProject {
    try {
        $config = Get-Content -LiteralPath $Firebaserc -Raw | ConvertFrom-Json
    }
    catch {
        Fail '.firebaserc no es un JSON valido.'
    }
    $default = [string]$config.projects.default
    if ($default -ne $ExpectedFirebaseProject) {
        Fail "El proyecto Firebase configurado no es $ExpectedFirebaseProject."
    }
    Write-Ok "Proyecto Firebase confirmado: $ExpectedFirebaseProject"
}

function Assert-GitIgnore {
    $git = Get-ToolPath -Name 'git'
    $null = & $git -C $ProjectRoot check-ignore -q .env.local 2>&1
    if ($LASTEXITCODE -ne 0) {
        Fail '.env.local no esta excluido de Git.'
    }
    Write-Ok '.env.local esta excluido de Git'
}

function Assert-FirebaseAuth {
    $firebase = Get-ToolPath -Name 'firebase'
    $output = Invoke-Native -Executable $firebase -Arguments @('login:list', '--json') -Description 'Verificando autenticacion de Firebase' -Capture

    try {
        $result = $output | ConvertFrom-Json
        $loggedIn = ($result.status -eq 'success' -and @($result.result).Count -gt 0)
    }
    catch {
        $loggedIn = ($output -match 'Logged in as')
    }
    if (-not $loggedIn) {
        Fail 'Firebase CLI no tiene una sesion autenticada. Ejecuta: firebase login'
    }
    Write-Ok 'Firebase CLI autenticado'
}

function New-TempDefineFile {
    param([hashtable]$Values)

    $defines = Get-PublicDefines -Values $Values
    if ($defines.Count -eq 0) {
        Fail 'No hay variables publicas para inyectar en Flutter.'
    }

    $json = $defines | ConvertTo-Json -Compress -Depth 4
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ("diauno-env-{0}.json" -f [guid]::NewGuid().ToString('N'))
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($path, $json, $encoding)

    # El archivo solo contiene credenciales publicas, pero se restringe al usuario actual.
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, 'FullControl', 'Allow')
        $acl = Get-Acl -LiteralPath $path
        $acl.SetAccessRuleProtection($true, $false)
        $acl.SetAccessRule($rule)
        Set-Acl -LiteralPath $path -AclObject $acl
    }
    catch {
        Write-WarnMsg 'No se pudo restringir el ACL del archivo temporal; se eliminara al terminar.'
    }

    Write-Step "JSON temporal creado fuera del repositorio con $($defines.Count) variables publicas."
    return $path
}

function Remove-TempDefineFile {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        try {
            Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
            Write-Ok 'Archivo temporal eliminado.'
        }
        catch {
            Write-WarnMsg "No se pudo eliminar el archivo temporal: $($_.Exception.Message)"
        }
    }
}

function Invoke-FlutterWebBuild {
    param([string]$TempDefinePath)

    Invoke-Native -Executable $script:Fly -Arguments @(
        'build', 'web', '--release', "--dart-define-from-file=$TempDefinePath"
    ) -Description 'Compilando Flutter Web (release)' | Out-Null

    if (-not (Test-Path -LiteralPath $IndexHtml -PathType Leaf)) {
        Fail 'No se genero build/web/index.html.'
    }
    Write-Ok 'Compilacion web verificada: build/web/index.html'
}

function Assert-Ready {
    param([switch]$NeedFirebase)

    $script:Fly = Get-ToolPath -Name 'flutter'
    $null = Get-ToolPath -Name 'dart'
    if ($NeedFirebase) {
        $script:Firebase = Get-ToolPath -Name 'firebase'
    }

    Assert-ProjectLayout

    $values = Read-EnvFile
    $check = Assert-RequiredVariables -Values $Values
    foreach ($warning in $check.Warnings) { Write-WarnMsg $warning }
    foreach ($error in $check.Errors) { Fail $error }
    Write-Ok "Variables validadas (formato .env.local: $script:EnvFormat; valores no mostrados)."
    return $values
}

function Invoke-Doctor {
    $issues = New-Object System.Collections.Generic.List[string]

    function Test-Step {
        param([string]$Name, [scriptblock]$Action)
        try {
            & $Action
            Write-Ok $Name
        }
        catch {
            $message = $_.Exception.Message
            $issues.Add("$Name`: $message")
            Write-Fail "$Name`: $message"
        }
    }

    Write-Step 'Diagnostico de DiaUno'

    Test-Step 'Herramientas instaladas' {
        $script:Fly = Get-ToolPath -Name 'flutter'
        $null = Get-ToolPath -Name 'dart'
        $null = Get-ToolPath -Name 'firebase'
        $null = Get-ToolPath -Name 'git'
    }

    Test-Step 'Estructura del proyecto' { Assert-ProjectLayout }
    Test-Step 'Archivo .env.local' {
        $script:DoctorValues = Read-EnvFile
    }
    Test-Step 'Variables requeridas' {
        if (-not $script:DoctorValues) { Fail 'No se pudo leer .env.local.' }
        $check = Assert-RequiredVariables -Values $script:DoctorValues
        foreach ($warning in $check.Warnings) { Write-WarnMsg $warning }
        foreach ($error in $check.Errors) { Fail $error }
        Write-Host "   Formato detectado: $script:EnvFormat (valores no mostrados)."
    }
    Test-Step 'Secretos excluidos de Flutter Web' {
        if (-not $script:DoctorValues) { Fail 'No se pudo leer .env.local.' }
        $excluded = @($script:DoctorValues.Keys | Where-Object {
            $_ -match $SecretNamePattern -and $_ -notin $AppEnvKeys
        })
        if ($excluded.Count -gt 0) {
            Write-WarnMsg "Variables sensibles detectadas y NO inyectadas: $($excluded -join ', ')."
        }
        else {
            Write-Host '   No hay variables sensibles adicionales en .env.local.'
        }
    }
    Test-Step 'firebase.json' { Assert-FirebaseConfig }
    Test-Step 'Proyecto Firebase' { Assert-FirebaseProject }
    Test-Step 'Exclusion Git de .env.local' { Assert-GitIgnore }

    if ($issues.Count -gt 0) {
        Write-Fail "Diagnostico terminado con $($issues.Count) problema(s)."
        return $false
    }
    Write-Ok 'Diagnostico sin errores.'
    return $true
}

function Invoke-Run {
    param([string[]]$ExtraArguments)

    $values = Assert-Ready
    $temp = New-TempDefineFile -Values $Values
    try {
        Write-Step 'Iniciando Flutter en Chrome...'
        & $script:Fly run -d chrome "--dart-define-from-file=$temp" @ExtraArguments
        $code = $LASTEXITCODE
        if ($code -ne 0) { Fail "flutter run termino con codigo de salida $code." }
        Write-Ok 'flutter run finalizo correctamente.'
    }
    finally {
        Remove-TempDefineFile -Path $temp
    }
}

function Invoke-Build {
    param([string[]]$ExtraArguments)

    $values = Assert-Ready
    $temp = New-TempDefineFile -Values $Values
    try {
        if ($ExtraArguments.Count -gt 0) {
            Invoke-Native -Executable $script:Fly -Arguments (@(
                'build', 'web', '--release', "--dart-define-from-file=$temp"
            ) + $ExtraArguments) -Description 'Compilando Flutter Web (release)' | Out-Null
        }
        else {
            Invoke-FlutterWebBuild -TempDefinePath $temp
        }
        if (-not (Test-Path -LiteralPath $IndexHtml -PathType Leaf)) {
            Fail 'No se genero build/web/index.html.'
        }
        Write-Ok 'Compilacion web finalizada correctamente.'
    }
    finally {
        Remove-TempDefineFile -Path $temp
    }
}

function Invoke-Deploy {
    $values = Assert-Ready -NeedFirebase
    Assert-FirebaseConfig
    Assert-FirebaseProject
    Assert-FirebaseAuth

    $temp = New-TempDefineFile -Values $Values
    try {
        Invoke-FlutterWebBuild -TempDefinePath $temp

        if (-not (Test-Path -LiteralPath $IndexHtml -PathType Leaf)) {
            Fail 'No se genero build/web/index.html; no se desplegara.'
        }

        $output = Invoke-Native -Executable $script:Firebase -Arguments @(
            'deploy', '--only', 'hosting', '--project', $ExpectedFirebaseProject
        ) -Description "Desplegando Hosting en $ExpectedFirebaseProject" -Capture

        if ($output -notmatch 'Deploy complete!' -and $output -notmatch [regex]::Escape($SiteUrl)) {
            Fail 'Firebase termino sin confirmar el despliegue.'
        }

        Write-Ok "Despliegue confirmado. Sitio publicado en $SiteUrl"
    }
    finally {
        Remove-TempDefineFile -Path $temp
    }
}

function Show-Help {
    Write-Host 'Uso: .\diauno.ps1 <comando> [argumentos adicionales]'
    Write-Host ''
    Write-Host 'Comandos:'
    Write-Host '  doctor   Comprueba herramientas, configuracion, variables y seguridad.'
    Write-Host '  run      Ejecuta Flutter en Chrome con .env.local.'
    Write-Host '  build    Compila Flutter Web en modo release.'
    Write-Host '  deploy   Compila y despliega en Firebase Hosting.'
    Write-Host '  help     Muestra esta ayuda.'
}

$exitCode = 0
$previousLocation = Get-Location
try {
    Set-Location -LiteralPath $ProjectRoot
    switch ($Command.ToLowerInvariant()) {
        'doctor' { if (-not (Invoke-Doctor)) { $exitCode = 1 } }
        'run' { Invoke-Run -ExtraArguments @($Rest) }
        'build' { Invoke-Build -ExtraArguments @($Rest) }
        'deploy' { Invoke-Deploy }
        default { Show-Help }
    }
}
catch {
    Write-Fail $_.Exception.Message
    $exitCode = 1
}
finally {
    Set-Location -LiteralPath $previousLocation.Path
}

exit $exitCode
