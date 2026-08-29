param(
    [string]$Owner = "terranom674",
    [string]$VersionPrefix = "bratonien-v-0-",
    [int]$Keep = 3,
    [int]$GroupWindowSeconds = 30,
    [string]$Token = $env:CR_PAT,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    throw "Das Skript muss als .ps1-Datei ausgefuehrt werden."
}

$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

if (-not (Test-Path ".\client\Dockerfile")) {
    throw "client\Dockerfile wurde nicht gefunden."
}

if (-not (Test-Path ".\api\Dockerfile")) {
    throw "api\Dockerfile wurde nicht gefunden."
}

if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "CR_PAT fehlt."
}

docker version | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Docker ist nicht erreichbar."
}

git rev-parse --is-inside-work-tree | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Das Skript wird nicht in einem Git-Repository ausgefuehrt."
}

$CurrentCommit = (git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($CurrentCommit)) {
    throw "Aktueller Git-Commit konnte nicht ermittelt werden."
}

$CurrentBranch = (git branch --show-current).Trim()

$Headers = @{
    Authorization = "Bearer $Token"
    Accept = "application/vnd.github+json"
    "X-GitHub-Api-Version" = "2022-11-28"
}

$Components = @(
    [PSCustomObject]@{
        Name       = "Client"
        Path       = "client"
        Package    = "bratonien-manifold-client"
        LocalImage = "bratonien-manifold-client:build"
    },
    [PSCustomObject]@{
        Name       = "API"
        Path       = "api"
        Package    = "bratonien-manifold-api"
        LocalImage = "bratonien-manifold-api:build"
    }
)

function Get-GhcrPackageVersions {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName
    )

    $All = @()
    $Page = 1

    while ($true) {
        $Url = "https://api.github.com/users/$Owner/packages/container/$PackageName/versions?per_page=100&page=$Page"

        try {
            $Response = Invoke-RestMethod `
                -Method Get `
                -Uri $Url `
                -Headers $Headers
        }
        catch {
            $StatusCode = $null
            if ($_.Exception.Response) {
                $StatusCode = [int]$_.Exception.Response.StatusCode
            }

            if ($StatusCode -eq 404) {
                return @()
            }

            throw
        }

        $Items = @($Response)
        if ($Items.Count -eq 0) {
            break
        }

        $All += $Items

        if ($Items.Count -lt 100) {
            break
        }

        $Page++
    }

    return @($All)
}

function Get-ManagedBuilds {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Versions
    )

    $EscapedPrefix = [regex]::Escape($VersionPrefix)
    $Builds = @()

    foreach ($Version in @($Versions)) {
        $Tags = @($Version.metadata.container.tags)

        foreach ($Tag in $Tags) {
            if ($Tag -match "^$EscapedPrefix(\d+)$") {
                $Builds += [PSCustomObject]@{
                    Id      = $Version.id
                    Tag     = $Tag
                    Version = [int]$Matches[1]
                    Created = [DateTime]$Version.created_at
                }
            }
        }
    }

    return @($Builds | Sort-Object Version -Descending)
}

function Get-LatestImageRevision {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RemoteRepo,

        [Parameter(Mandatory = $true)]
        [string]$Tag
    )

    $FullTag = "${RemoteRepo}:$Tag"

    $Revision = & docker image inspect `
        --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' `
        $FullTag 2>$null

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Lade Metadaten der letzten Version: $FullTag"
        & docker pull $FullTag | Out-Host

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "  Letzte Version konnte nicht geladen werden. Komponente wird sicherheitshalber neu gebaut."
            return $null
        }

        $Revision = & docker image inspect `
            --format '{{ index .Config.Labels "org.opencontainers.image.revision" }}' `
            $FullTag 2>$null
    }

    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    $Revision = "$Revision".Trim()

    if ([string]::IsNullOrWhiteSpace($Revision) -or $Revision -eq "<no value>") {
        return $null
    }

    return $Revision
}

function Test-WorkingTreeChanged {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    & git diff --quiet -- $Path
    if ($LASTEXITCODE -eq 1) {
        return $true
    }
    elseif ($LASTEXITCODE -gt 1) {
        throw "Git konnte lokale Aenderungen fuer '$Path' nicht pruefen."
    }

    & git diff --cached --quiet -- $Path
    if ($LASTEXITCODE -eq 1) {
        return $true
    }
    elseif ($LASTEXITCODE -gt 1) {
        throw "Git konnte vorgemerkte Aenderungen fuer '$Path' nicht pruefen."
    }

    $Untracked = @(git ls-files --others --exclude-standard -- $Path)
    if ($LASTEXITCODE -ne 0) {
        throw "Git konnte ungetrackte Dateien fuer '$Path' nicht pruefen."
    }

    return ($Untracked.Count -gt 0)
}

function Test-ComponentChanged {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [string]$PreviousCommit
    )

    if ($Force) {
        return $true
    }

    if ([string]::IsNullOrWhiteSpace($PreviousCommit)) {
        return $true
    }

    if (Test-WorkingTreeChanged -Path $Path) {
        return $true
    }

    if ($PreviousCommit -eq $CurrentCommit) {
        return $false
    }

    & git cat-file -e "${PreviousCommit}^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "  Referenz-Commit $PreviousCommit ist lokal nicht verfuegbar. Komponente wird sicherheitshalber neu gebaut."
        return $true
    }

    & git diff --quiet "$PreviousCommit..$CurrentCommit" -- $Path

    if ($LASTEXITCODE -eq 0) {
        return $false
    }

    if ($LASTEXITCODE -eq 1) {
        return $true
    }

    throw "Git-Vergleich fuer '$Path' ist fehlgeschlagen."
}

function Remove-OldRemoteBuilds {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName
    )

    $Versions = @(Get-GhcrPackageVersions -PackageName $PackageName)
    $ManagedBuilds = @(Get-ManagedBuilds -Versions $Versions)

    if ($ManagedBuilds.Count -le $Keep) {
        return
    }

    $DeleteBuilds = @($ManagedBuilds | Select-Object -Skip $Keep)
    $DeletedIds = @{}

    foreach ($Build in $DeleteBuilds) {
        Write-Host "  Entferne alte GHCR-Version: $($Build.Tag)"

        $RelatedVersions = @(
            $Versions | Where-Object {
                $Tags = @($_.metadata.container.tags)
                $ItemTime = [DateTime]$_.created_at
                $TimeMatches = [Math]::Abs(($ItemTime - $Build.Created).TotalSeconds) -le $GroupWindowSeconds

                ($_.id -eq $Build.Id) -or ($Tags.Count -eq 0 -and $TimeMatches)
            }
        )

        foreach ($Version in $RelatedVersions) {
            if ($DeletedIds.ContainsKey([string]$Version.id)) {
                continue
            }

            $DeleteUrl = "https://api.github.com/users/$Owner/packages/container/$PackageName/versions/$($Version.id)"

            try {
                Invoke-RestMethod `
                    -Method Delete `
                    -Uri $DeleteUrl `
                    -Headers $Headers

                $DeletedIds[[string]$Version.id] = $true
                $Tags = @($Version.metadata.container.tags) -join ", "

                if ([string]::IsNullOrWhiteSpace($Tags)) {
                    Write-Host "    geloescht: $($Version.id) [ungetaggt]"
                }
                else {
                    Write-Host "    geloescht: $($Version.id) [$Tags]"
                }
            }
            catch {
                Write-Warning "    GHCR-Version $($Version.id) konnte nicht geloescht werden: $($_.Exception.Message)"
            }
        }
    }
}

function Remove-OldLocalTags {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RemoteRepo
    )

    $EscapedPrefix = [regex]::Escape($VersionPrefix)
    $LocalManaged = @()

    $Rows = @(& docker images $RemoteRepo --format '{{.Repository}}|{{.Tag}}|{{.ID}}')

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "  Lokale Docker-Tags konnten nicht gelesen werden."
        return
    }

    foreach ($Row in $Rows) {
        if ([string]::IsNullOrWhiteSpace($Row)) {
            continue
        }

        $Parts = $Row -split '\|', 3

        if ($Parts.Count -ne 3) {
            continue
        }

        $Tag = $Parts[1]

        if ($Tag -match "^$EscapedPrefix(\d+)$") {
            $LocalManaged += [PSCustomObject]@{
                Tag     = $Tag
                Version = [int]$Matches[1]
            }
        }
    }

    $OldLocal = @(
        $LocalManaged |
            Sort-Object Version -Descending |
            Select-Object -Skip $Keep
    )

    foreach ($Image in $OldLocal) {
        $FullTag = "${RemoteRepo}:$($Image.Tag)"

        & docker image rm $FullTag | Out-Host

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "  Lokaler Tag $FullTag konnte nicht entfernt werden."
        }
    }
}

function Build-And-PushComponent {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Component,

        [Parameter(Mandatory = $true)]
        [array]$ExistingVersions
    )

    $RemoteRepo = "ghcr.io/$Owner/$($Component.Package)"
    $ManagedBuilds = @(Get-ManagedBuilds -Versions $ExistingVersions)

    if ($ManagedBuilds.Count -eq 0) {
        $NextVersion = 1
    }
    else {
        $NextVersion = (($ManagedBuilds | Measure-Object -Property Version -Maximum).Maximum) + 1
    }

    $NewTag = "$VersionPrefix$NextVersion"
    $FullRemoteTag = "${RemoteRepo}:$NewTag"

    Write-Host ""
    Write-Host "Baue $($Component.Name) -> $NewTag"

    & docker build `
        --target production `
        --label "org.opencontainers.image.revision=$CurrentCommit" `
        -t $Component.LocalImage `
        ".\$($Component.Path)"

    if ($LASTEXITCODE -ne 0) {
        throw "$($Component.Name)-Build fehlgeschlagen."
    }

    & docker tag $Component.LocalImage $FullRemoteTag

    if ($LASTEXITCODE -ne 0) {
        throw "Tagging von $($Component.Name) fehlgeschlagen."
    }

    & docker push $FullRemoteTag | Out-Host

    if ($LASTEXITCODE -ne 0) {
        throw "Push von $($Component.Name) fehlgeschlagen."
    }

    Write-Host "  gepusht: $FullRemoteTag"

    Remove-OldRemoteBuilds -PackageName $Component.Package
    Remove-OldLocalTags -RemoteRepo $RemoteRepo

    return $NewTag
}

Write-Host ""
Write-Host "Bratonien Manifold Build"
Write-Host "Branch:  $CurrentBranch"
Write-Host "Commit:  $CurrentCommit"
Write-Host "Keep:    $Keep"
Write-Host ""

$Token | docker login ghcr.io -u $Owner --password-stdin | Out-Host

if ($LASTEXITCODE -ne 0) {
    throw "Docker-Login bei GHCR fehlgeschlagen."
}

$Results = @()

foreach ($Component in $Components) {
    Write-Host ""
    Write-Host "Pruefe $($Component.Name)..."

    $Versions = @(Get-GhcrPackageVersions -PackageName $Component.Package)
    $ManagedBuilds = @(Get-ManagedBuilds -Versions $Versions)

    $LatestBuild = $null
    $PreviousCommit = $null

    if ($ManagedBuilds.Count -gt 0) {
        $LatestBuild = $ManagedBuilds | Select-Object -First 1
        $RemoteRepo = "ghcr.io/$Owner/$($Component.Package)"
        $PreviousCommit = Get-LatestImageRevision `
            -RemoteRepo $RemoteRepo `
            -Tag $LatestBuild.Tag

        Write-Host "  letzte Version: $($LatestBuild.Tag)"

        if ([string]::IsNullOrWhiteSpace($PreviousCommit)) {
            Write-Host "  Build-Commit:   nicht vorhanden"
        }
        else {
            Write-Host "  Build-Commit:   $PreviousCommit"
        }
    }
    else {
        Write-Host "  noch keine verwaltete Bratonien-Version vorhanden"
    }

    $Changed = Test-ComponentChanged `
        -Path $Component.Path `
        -PreviousCommit $PreviousCommit

    if (-not $Changed) {
        Write-Host "  keine Aenderung -> kein Build"

        $Results += [PSCustomObject]@{
            Component = $Component.Name
            Action    = "unveraendert"
            Version   = if ($LatestBuild) { $LatestBuild.Tag } else { "-" }
        }

        continue
    }

    Write-Host "  Aenderung erkannt -> Build erforderlich"

    $NewTag = Build-And-PushComponent `
        -Component $Component `
        -ExistingVersions $Versions

    $Results += [PSCustomObject]@{
        Component = $Component.Name
        Action    = "gebaut und gepusht"
        Version   = $NewTag
    }
}

Write-Host ""
Write-Host "Ergebnis:"
$Results | Format-Table Component,Action,Version -AutoSize
