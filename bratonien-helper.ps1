# Bratonien Manifold Helper fuer Windows
# Eigenstaendiges Hilfsskript. Veraendert keine Manifold-Quelldateien.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = $PSScriptRoot
$ClientDir = Join-Path $RepoRoot "client"
$PackageJson = Join-Path $ClientDir "package.json"
$WebpackJs = Join-Path $ClientDir "node_modules\webpack\bin\webpack.js"

function Write-Header {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor DarkYellow
    Write-Host " Bratonien Manifold - Helfer" -ForegroundColor Yellow
    Write-Host "============================================================" -ForegroundColor DarkYellow
    Write-Host ""
}

function Write-Info([string]$Text) {
    Write-Host "[INFO] $Text" -ForegroundColor Cyan
}

function Write-Ok([string]$Text) {
    Write-Host "[OK]   $Text" -ForegroundColor Green
}

function Write-Warn([string]$Text) {
    Write-Host "[HINWEIS] $Text" -ForegroundColor Yellow
}

function Write-Fail([string]$Text) {
    Write-Host "[FEHLER] $Text" -ForegroundColor Red
}

function Wait-ForUser {
    Write-Host ""
    Read-Host "Enter druecken, um zum Menue zurueckzukehren" | Out-Null
}

function Test-Repository {
    if (-not (Test-Path $PackageJson)) {
        Write-Fail "Das Skript liegt nicht im Stammverzeichnis des Bratonien-Manifold-Repositories."
        Write-Host "Erwartet wurde: $PackageJson"
        return $false
    }
    return $true
}

function Get-CommandVersion([string]$Command, [string[]]$Arguments) {
    try {
        $output = & $Command @Arguments 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        return ($output | Select-Object -First 1).ToString().Trim()
    }
    catch {
        return $null
    }
}

function Show-Environment {
    Write-Header
    Write-Host "Systempruefung" -ForegroundColor White
    Write-Host ""

    $nodeVersion = Get-CommandVersion "node" @("--version")
    if ($nodeVersion) {
        $major = [int](($nodeVersion -replace '^v','').Split('.')[0])
        if ($major -eq 22) {
            Write-Ok "Node.js $nodeVersion"
        }
        else {
            Write-Fail "Node.js $nodeVersion - Manifold erwartet Node.js 22.x."
        }
    }
    else {
        Write-Fail "Node.js wurde nicht gefunden."
    }

    $yarnVersion = Get-CommandVersion "yarn" @("--version")
    if ($yarnVersion) {
        if ($yarnVersion.StartsWith("4.")) {
            Write-Ok "Yarn $yarnVersion"
        }
        else {
            Write-Warn "Yarn $yarnVersion - das Projekt erwartet Yarn 4.x."
        }
    }
    else {
        Write-Fail "Yarn wurde nicht gefunden."
        Write-Warn "Corepack kann ueber Menuepunkt 2 eingerichtet werden."
    }

    $gitVersion = Get-CommandVersion "git" @("--version")
    if ($gitVersion) { Write-Ok $gitVersion } else { Write-Warn "Git wurde nicht gefunden." }

    if (Test-Path $WebpackJs) {
        Write-Ok "Client-Abhaengigkeiten sind vorhanden."
    }
    else {
        Write-Warn "Client-Abhaengigkeiten fehlen oder sind unvollstaendig."
        Write-Warn "Fuehre Menuepunkt 2 aus."
    }

    Write-Host ""
    Write-Host "Repository: $RepoRoot"
    Write-Host "Client:     $ClientDir"
    Wait-ForUser
}

function Install-Dependencies {
    Write-Header
    Write-Host "Client vorbereiten" -ForegroundColor White
    Write-Host ""

    Push-Location $ClientDir
    try {
        Write-Info "Corepack wird aktiviert ..."
        & corepack enable
        if ($LASTEXITCODE -ne 0) { throw "Corepack konnte nicht aktiviert werden." }

        Write-Info "Abhaengigkeiten werden mit Yarn installiert ..."
        & yarn install
        if ($LASTEXITCODE -ne 0) { throw "yarn install wurde mit Fehlern beendet." }

        Write-Ok "Client ist vorbereitet."
    }
    catch {
        Write-Fail $_.Exception.Message
    }
    finally {
        Pop-Location
    }
    Wait-ForUser
}

function Test-BuildPrerequisites {
    $nodeVersion = Get-CommandVersion "node" @("--version")
    if (-not $nodeVersion) {
        Write-Fail "Node.js wurde nicht gefunden."
        return $false
    }

    $major = [int](($nodeVersion -replace '^v','').Split('.')[0])
    if ($major -ne 22) {
        Write-Fail "Installiert ist $nodeVersion. Fuer dieses Projekt wird Node.js 22.x benoetigt."
        return $false
    }

    if (-not (Test-Path $WebpackJs)) {
        Write-Fail "Webpack ist noch nicht installiert. Fuehre zuerst Menuepunkt 2 aus."
        return $false
    }

    return $true
}

function Invoke-ManifoldBuild([ValidateSet("browser", "ssr")] [string]$Target) {
    Write-Header

    if ($Target -eq "browser") {
        Write-Host "Produktions-Build: Browser" -ForegroundColor White
        $config = ".\webpack\config\browser-prd.config.js"
    }
    else {
        Write-Host "Produktions-Build: SSR" -ForegroundColor White
        $config = ".\webpack\config\ssr-prd.config.js"
    }
    Write-Host ""

    if (-not (Test-BuildPrerequisites)) {
        Wait-ForUser
        return $false
    }

    Push-Location $ClientDir
    $oldIsBuild = $env:IS_BUILD
    $oldNodeEnv = $env:NODE_ENV
    try {
        $env:IS_BUILD = "true"
        $env:NODE_ENV = "production"

        Write-Info "Build wird gestartet. Das kann einige Zeit dauern."
        & node --max_old_space_size=4096 -r '@babel/register' '.\node_modules\webpack\bin\webpack.js' --color --mode production --config $config
        $exitCode = $LASTEXITCODE

        Write-Host ""
        if ($exitCode -eq 0) {
            Write-Ok "Build wurde erfolgreich abgeschlossen."
            return $true
        }
        else {
            Write-Fail "Build wurde mit Fehlern beendet (Exit-Code $exitCode)."
            Write-Warn "Die eigentliche Webpack-Ausgabe direkt darueber enthaelt die Ursache."
            return $false
        }
    }
    catch {
        Write-Fail $_.Exception.Message
        return $false
    }
    finally {
        $env:IS_BUILD = $oldIsBuild
        $env:NODE_ENV = $oldNodeEnv
        Pop-Location
    }
}

function Build-Browser {
    [void](Invoke-ManifoldBuild "browser")
    Wait-ForUser
}

function Build-Ssr {
    [void](Invoke-ManifoldBuild "ssr")
    Wait-ForUser
}

function Build-All {
    Write-Header
    Write-Host "Vollstaendigen Client pruefen" -ForegroundColor White
    Write-Host ""
    Write-Info "Zuerst wird der Browser-Build ausgefuehrt, danach der SSR-Build."
    Write-Host ""

    if (-not (Test-BuildPrerequisites)) {
        Wait-ForUser
        return
    }

    $browserOk = Invoke-ManifoldBuild "browser"
    if (-not $browserOk) {
        Write-Host ""
        Write-Warn "Der Browser-Build hat Fehler. Der SSR-Build wird trotzdem geprueft."
        Start-Sleep -Seconds 1
    }

    $ssrOk = Invoke-ManifoldBuild "ssr"

    Write-Host ""
    if ($browserOk -and $ssrOk) {
        Write-Ok "Browser und SSR wurden fehlerfrei gebaut."
    }
    else {
        Write-Fail "Mindestens ein Build enthaelt Fehler."
    }
    Wait-ForUser
}

function Show-GitStatus {
    Write-Header
    Write-Host "Git-Status" -ForegroundColor White
    Write-Host ""

    try {
        Push-Location $RepoRoot
        & git status --short --branch
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "Git-Status konnte nicht gelesen werden."
        }
    }
    catch {
        Write-Fail $_.Exception.Message
    }
    finally {
        Pop-Location
    }
    Wait-ForUser
}

if (-not (Test-Repository)) {
    Write-Host ""
    Read-Host "Enter druecken zum Beenden" | Out-Null
    exit 1
}

do {
    Write-Header
    Write-Host "Was moechtest du tun?" -ForegroundColor White
    Write-Host ""
    Write-Host "  1  System und Voraussetzungen pruefen"
    Write-Host "  2  Client-Abhaengigkeiten installieren / aktualisieren"
    Write-Host "  3  Browser-Produktions-Build pruefen"
    Write-Host "  4  SSR-Produktions-Build pruefen"
    Write-Host "  5  Browser und SSR komplett pruefen"
    Write-Host "  6  Git-Status anzeigen"
    Write-Host ""
    Write-Host "  0  Beenden"
    Write-Host ""

    $choice = Read-Host "Auswahl"

    switch ($choice) {
        "1" { Show-Environment }
        "2" { Install-Dependencies }
        "3" { Build-Browser }
        "4" { Build-Ssr }
        "5" { Build-All }
        "6" { Show-GitStatus }
        "0" { }
        default {
            Write-Warn "Bitte eine der angezeigten Nummern eingeben."
            Start-Sleep -Seconds 1
        }
    }
} while ($choice -ne "0")

Write-Host ""
Write-Host "Bratonien Manifold Helper beendet." -ForegroundColor DarkGray
