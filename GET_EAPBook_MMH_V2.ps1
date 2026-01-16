<#
.SYNOPSIS
    EAP IIIF Book Downloader for Windows PowerShell.

.DESCRIPTION
    Downloads all pages from a British Library EAP IIIF item and compiles them into a PDF.
    Works for items like: https://images.eap.bl.uk/EAP127/EAP127_6_70

.PARAMETER Base
    The base IIIF path WITHOUT the page/size bits.
    Example: "https://images.eap.bl.uk/EAP127/EAP127_6_70"

.PARAMETER Pages
    Optional known page count. If omitted (or 0), the script auto-detects it.

.PARAMETER BookName
    Name for the book (used for naming PDF, images, and folder). Defaults to "EAP_Book".

.PARAMETER OutDir
    Output directory. Defaults to a folder on your Desktop named after the BookName.

.PARAMETER DelayMs
    Delay between requests (milliseconds) to avoid overloading the server. Defaults to 300.

.PARAMETER MakePdf
    Switch to compile a PDF from the downloaded images at the end (requires ImageMagick).

.EXAMPLE
    .\GET_EAPBook_MMH_V2.ps1 -Base "https://images.eap.bl.uk/EAP127/EAP127_6_70" -BookName "Sekh Pharider Puthi"

.NOTES
    Author: Md Mohsin Hossain
    Created: 26th August, 2025
    Intended for educational use only.

    REQUIREMENTS:
    - PDF creation requires ImageMagick (magick.exe) on PATH.
    - If you hit an execution policy error, run:
        Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Base IIIF path, e.g., https://images.eap.bl.uk/EAP127/EAP127_6_70")]
    [string]$Base,

    [Parameter(HelpMessage = "Total page count. If 0, auto-detects.")]
    [int]$Pages = 0,

    [Parameter(HelpMessage = "Name for the book, used for file and folder naming.")]
    [string]$BookName = "EAP_Book",

    [Parameter(HelpMessage = "Output directory for images and PDF.")]
    [string]$OutDir,

    [Parameter(HelpMessage = "Delay between requests in milliseconds.")]
    [int]$DelayMs = 300,

    [Parameter(HelpMessage = "Create a PDF from downloaded images.")]
    [switch]$MakePdf
)

# --- Helper Functions ---

function Get-SanitizedFileName {
    param([string]$Name)
    # Remove or replace characters that are invalid in Windows file/folder names
    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars() -join ''
    $sanitized = $Name -replace "[$([regex]::Escape($invalidChars))]", '_'
    return $sanitized.Trim()
}

function Get-IIIFSizeParam {
    param([hashtable]$Info)
    # If server advertises v3 limits, prefer 'full/max'
    if ($Info.maxWidth -or $Info.maxHeight -or $Info.maxArea) {
        return "full/max"
    }
    # Otherwise pick the largest listed size (if any)
    if ($Info.sizes) {
        $largest = $Info.sizes | Sort-Object { $_.width * $_.height } -Descending | Select-Object -First 1
        return ("full/{0},{1}" -f $largest.width, $largest.height)
    }
    # Fallback
    return "full/max"
}

function Test-ImageMagick {
    try {
        $null = Get-Command magick -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# --- Pre-flight Checks ---

$hasImageMagick = Test-ImageMagick
if ($MakePdf -and -not $hasImageMagick) {
    Write-Warning "ImageMagick (magick.exe) not found on PATH. PDF creation will be skipped."
}

# --- Setup ---

# Sanitize BookName
$BookName = Get-SanitizedFileName -Name $BookName

# Set default OutDir if not provided
if (-not $OutDir) {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $OutDir = Join-Path $desktopPath "EAP_Download\$BookName"
}

# Create the output folder if it doesn't exist
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Write-Host "Output directory: $OutDir" -ForegroundColor Cyan

# --- Auto-detect Page Count ---

if ($Pages -lt 1) {
    Write-Host "Detecting page count..." -ForegroundColor Yellow
    $n = 1
    while ($true) {
        try {
            Invoke-RestMethod "$Base/$n.jp2/info.json" -ErrorAction Stop | Out-Null
            $n++
        } catch {
            break
        }
    }
    $Pages = $n - 1
    if ($Pages -lt 1) {
        throw "No pages discovered under $Base. Please verify the URL."
    }
    Write-Host "Detected $Pages pages." -ForegroundColor Green
}

# --- Determine Best Image Size ---

Write-Host "Fetching IIIF info for optimal image size..." -ForegroundColor Yellow
$sizeParam = "full/max" # Default fallback
try {
    $infoUrl = "$Base/1.jp2/info.json"
    $infoData = Invoke-RestMethod $infoUrl -ErrorAction Stop
    # Convert to hashtable for compatibility
    $infoHash = @{}
    $infoData.PSObject.Properties | ForEach-Object { $infoHash[$_.Name] = $_.Value }
    $sizeParam = Get-IIIFSizeParam -Info $infoHash
    Write-Host "Using image size: $sizeParam" -ForegroundColor Green
} catch {
    Write-Warning "Could not fetch IIIF info. Using default size: $sizeParam"
}

# --- Download Images ---

Write-Host "Starting download of $Pages pages..." -ForegroundColor Cyan
$failedPages = @()

for ($i = 1; $i -le $Pages; $i++) {
    $pad = "{0:D3}" -f $i
    $outfile = Join-Path $OutDir "$BookName-$pad.jpg"

    # Show progress
    $percent = [int](($i / $Pages) * 100)
    Write-Progress -Activity "Downloading pages" -Status "Page $i of $Pages" -PercentComplete $percent

    # Try several canonical IIIF URL patterns; save on first success
    $candidates = @(
        "$Base/$i.jp2/$sizeParam/0/default.jpg",      # Chosen best size
        "$Base/$i.jp2/full/max/0/default.jpg",        # IIIF v3 style
        "$Base/$i.jp2/full/full/0/default.jpg",       # IIIF v2 style
        "$Base/$i.jp2/full/!8000,8000/0/default.jpg"  # Big fallback
    ) | Select-Object -Unique

    $ok = $false
    foreach ($u in $candidates) {
        try {
            Invoke-WebRequest -Uri $u -OutFile $outfile -UseBasicParsing -ErrorAction Stop
            Write-Host ("Saved page {0,3} -> {1}" -f $i, (Split-Path $outfile -Leaf)) -ForegroundColor Gray
            $ok = $true
            break
        } catch {
            # try next candidate
        }
    }

    if (-not $ok) {
        Write-Warning "Failed to download page $i"
        $failedPages += $i
    }

    Start-Sleep -Milliseconds $DelayMs
}

Write-Progress -Activity "Downloading pages" -Completed

# --- Create PDF ---

if ($hasImageMagick) {
    $pdfPath = Join-Path $OutDir "$BookName.pdf"
    Write-Host "Creating PDF from images..." -ForegroundColor Cyan

    try {
        $imagePattern = Join-Path $OutDir "$BookName-*.jpg"
        & magick $imagePattern $pdfPath
        if (Test-Path $pdfPath) {
            Write-Host "PDF created successfully: $pdfPath" -ForegroundColor Green
        } else {
            Write-Warning "PDF file was not created. Check ImageMagick output."
        }
    } catch {
        Write-Warning "Error creating PDF: $_"
    }
} else {
    Write-Host "Skipping PDF creation (ImageMagick not available)." -ForegroundColor Yellow
}

# --- Summary ---

Write-Host "`n--- Download Complete ---" -ForegroundColor Green
Write-Host "Images saved in: $OutDir"
if ($hasImageMagick) {
    Write-Host "PDF saved as: $BookName.pdf"
}
if ($failedPages.Count -gt 0) {
    Write-Warning ("Failed pages: " + ($failedPages -join ", "))
}
