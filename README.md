# EAP IIIF Book Downloader

## Description
This PowerShell script downloads pages from British Library EAP IIIF items and converts them into a PDF. It is **intended for educational use only**.

## Requirements
1. **Windows PowerShell** (tested on 5.1)
2. **ImageMagick** (optional, for PDF creation) - [Download here](https://imagemagick.org/). The `magick.exe` must be on your system PATH.

## Quick Start

1. **Open PowerShell** in the folder containing `GET_EAPBook_MMH_V2.ps1`.

2. **If you get an execution policy error**, run this first:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
   ```

3. **Run the script**:
   ```powershell
   .\GET_EAPBook_MMH_V2.ps1 -Base "https://images.eap.bl.uk/EAP127/EAP127_6_70" -BookName "Sekh Pharider Puthi"
   ```
   This will auto-detect pages and save images/PDF to your Desktop under `EAP_Download\Sekh Pharider Puthi`.

## Parameters

| Parameter   | Required | Description                                                                 |
|-------------|----------|-----------------------------------------------------------------------------|
| `-Base`     | Yes      | Base IIIF URL (e.g., `https://images.eap.bl.uk/EAP127/EAP127_6_70`)         |
| `-BookName` | No       | Name for the book (default: `EAP_Book`)                                     |
| `-OutDir`   | No       | Output folder. Defaults to `Desktop\EAP_Download\<BookName>`                |
| `-Pages`    | No       | Total page count. If omitted, auto-detects                                  |
| `-DelayMs`  | No       | Delay between requests in ms (default: `300`)                               |
| `-MakePdf`  | No       | Switch to explicitly request PDF creation (requires ImageMagick)            |

## Examples

**Auto-detect pages, custom output folder:**
```powershell
.\GET_EAPBook_MMH_V2.ps1 `
  -Base "https://images.eap.bl.uk/EAP127/EAP127_6_65" `
  -BookName "Jaiguner Puthi" `
  -OutDir "D:\MyBooks"
```

**Specify page count, skip auto-detection:**
```powershell
.\GET_EAPBook_MMH_V2.ps1 `
  -Base "https://images.eap.bl.uk/EAP127/EAP127_6_70" `
  -BookName "Sekh Pharider Puthi" `
  -Pages 50
```

## How to Find the Base URL

1. Go to an EAP archive page, e.g., `https://eap.bl.uk/archive-file/EAP127-6-70`
2. The Base URL for the script is: `https://images.eap.bl.uk/EAP127/EAP127_6_70`  
   (Replace `-` with `_` and use `images.eap.bl.uk`)

## Notes
- The script fetches the largest allowed image size from the IIIF server.
- A delay between requests is included by default to be polite to the server.
- If ImageMagick is not installed, images will still be downloaded but no PDF will be created.

## Contributing

1. Fork the repository.
2. Make changes in a new branch.
3. Submit a pull request.

---
© 2025 Md Mohsin Hossain. All rights reserved.