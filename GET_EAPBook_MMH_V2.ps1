<#
EAP IIIF BOOK DOWNLOADER (Windows PowerShell)



Md Mohsin Hossain
Created on 26th August, 2025
Use for the education purpose only.



Open with windows PowerShell ISE for the customization and change the book name and url of the book and output folders. 



--------------------------------------------
Downloads all pages from a British Library EAP IIIF item into a folder.
Works for items like: https://images.eap.bl.uk/EAP127/EAP127_6_70 from the URL of https://eap.bl.uk/archive-file/EAP127-6-70



USAGE (open PowerShell in the folder with this file, e.g., Get-EAPBook.ps1):



1) If you hit an execution policy error, run ONE of these and try again:

   # Temporary for THIS shell only (recommended)
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

   # Or run with a one-time override:
   powershell -ExecutionPolicy Bypass -File .\GET_EAPBook_MMH_V2.ps1 -Base "..." -OutDir "..."

2) Examples:
     -Base  "https://images.eap.bl.uk/EAP127/EAP127_6_70" `
     -BookName "Sekh Pharider Puthi" `
     -OutDir "C:\Users\Mohsin Hossain\Desktop\EAP_Download"

NOTES:
- The script requests the largest allowed image size advertised by the IIIF server.
- Be polite to the server; a small delay is included (tune with -DelayMs).
- PDF creation requires ImageMagick (magick.exe) on PATH.
#>

[CmdletBinding()]
param(
    # Base IIIF path WITHOUT the page/size bits (Example: "https://images.eap.bl.uk/EAP127/EAP127_6_70")
    [Parameter(Mandatory=$true)]
    [string]$Base,

    # Optional known page count. If omitted (or 0), the script auto-detects it.
    [int]$Pages = 0,

    # Name for the book (used for naming PDF, images, and folder)
    [string]$BookName = "jaiguner puthi",  # Insert the book name here that you want to download

    # Delay between requests (milliseconds) to avoid overloading the server
    [int]$DelayMs = 300,

    # Build a PDF at the end (requires ImageMagick)
    [switch]$MakePdf
)

# Custom folder for the book based on the book name
$OutDir = "C:\Users\Mohsin Hossain\Desktop\EAP_Download\$BookName"  # Folder name based on book name

# Create the output folder if it doesn't exist
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Function to get the best image size based on IIIF server metadata
function Get-IIIFSizeParam {
    param([hashtable]$Info)
    # If server advertises v3 limits, prefer 'full/max'
    if ($Info.maxWidth -or $Info.maxHeight -or $Info.maxArea) { return "full/max" }
    # Otherwise pick the largest listed size (if any)
    if ($Info.sizes) {
        $largest = $Info.sizes | Sort-Object { $_.width * $_.height } -Descending | Select-Object -First 1
        return ("full/{0},{1}" -f $largest.width, $largest.height)
    }
    # Fallback
    return "full/max"
}

# Auto-detect the number of pages if not provided
if ($Pages -lt 1) {
    $n = 1
    while ($true) {
        try   { Invoke-RestMethod "$Base/$n.jp2/info.json" -ErrorAction Stop | Out-Null; $n++ }
        catch { break }
    }
    $Pages = $n - 1
    if ($Pages -lt 1) { throw "No pages discovered under $Base" }
    Write-Host "Detected $Pages pages."
}

# Download images (JPG) for each page and name them based on the book name
for ($i = 1; $i -le $Pages; $i++) {
    $pad = "{0:D3}" -f $i
    $outfile = Join-Path $OutDir "$BookName-$pad.jpg"  # Name images based on the book name

    # Try several canonical IIIF URL patterns; save on the first success
    $candidates = @(
        "$Base/$i.jp2/$sizeParam/0/default.jpg",   # chosen best size
        "$Base/$i.jp2/full/max/0/default.jpg",     # IIIF v3 style
        "$Base/$i.jp2/full/full/0/default.jpg",    # IIIF v2 style
        "$Base/$i.jp2/full/!8000,8000/0/default.jpg"  # big fallback
    ) | Select-Object -Unique

    $ok = $false
    foreach ($u in $candidates) {
        try {
            Invoke-WebRequest -Uri $u -OutFile $outfile -UseBasicParsing -ErrorAction Stop
            Write-Host ("Saved page {0,3} -> {1}" -f $i, $outfile)
            $ok = $true
            break
        } catch { }  # try next candidate
    }
    if (-not $ok) { Write-Warning "Failed to download page $i" }

    Start-Sleep -Milliseconds $DelayMs
}

# compile to PDF if ImageMagick is installed
# Define the output PDF path
$pdfPath = Join-Path $OutDir "$BookName.pdf"  # Name the PDF based on the book name

# Attempt to create the PDF from the images in the output folder
Write-Host "Attempting to create PDF from images in $OutDir..."

# Use the ImageMagick command to create the PDF
try {
    # Run the ImageMagick command to create a PDF from all images
    & magick "$OutDir\$BookName*.jpg" "$pdfPath"
    Write-Host "PDF created successfully at $pdfPath"
} catch {
    Write-Host "Error creating PDF: $_"
}

Write-Host "Done. Images and Pdf saved in: $OutDir"
