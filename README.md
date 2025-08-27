# EAP IIIF Book Downloader

## Description
This PowerShell script allows users to download pages from British Library EAP IIIF items and convert them into a PDF. It is **intended for educational use only** and is not intended for business or commercial purposes. By using this script, you agree to give proper attribution to the original author.

## Tested on:
- **Operating System**: Windows 10
- **PowerShell**: Windows PowerShell 5.1 (other versions might work but are untested)

## Requirements
1. **Windows PowerShell** (the script is tested on PowerShell 5.1, but should work on newer versions).
2. **ImageMagick** (magick.exe) installed and added to your system PATH. You can download it from [here](https://imagemagick.org/) or [here](ImageMagick-7.1.2-2-Q16-HDRI-x64-dll.exe).
   
   ImageMagick is required to generate a PDF from the images once they are downloaded. Ensure that the `magick.exe` executable is available on your PATH so that the script can invoke it.

## Usage

### Customizing the Script
   - Set the **Book Name**.
   - Specify the **Book URL**.
   - Define the **output folder**.

1. **Open PowerShell ISE**:
   - Press `Win + R`, type `powershell_ise`, and press Enter.
   - Alternatively, search for "Windows PowerShell ISE" in the Start menu and open it.

2. **Open the Script**:
   - In PowerShell ISE, click on `File` > `Open` and select the `Get-EAPBook.ps1` script.

3. **Customize Parameters**:
   - Modify the following variables in the script:
     - `$Base`: Set this to the base URL of the IIIF item (e.g., `"https://images.eap.bl.uk/EAP127/EAP127_6_70"`).
     - `$Pages`: Set the total number of pages to download. If set to `0`, the script will attempt to auto-detect the page count.
     - `$BookName`: Set the desired name for the book (used for naming PDF, images, and folder).
     - `$OutDir`: Set the output directory where images and the PDF will be saved.
     - `$DelayMs`: Set the delay between requests to avoid overloading the server (default is 200 milliseconds).
     - `$MakePdf`: Add the `-MakePdf` switch if you want to generate a PDF from the downloaded images.

4. **Run the Script**:
   - Press `F5` or click on the `Run Script` button in the toolbar to execute the script.
   - The script will download the pages, save them as images, and optionally generate a PDF if ImageMagick is available.

### Alternative Way of Running the Script
1. Open PowerShell in the folder where the script is located (`GET_EAPBook_MMH_V2.ps1`).

2. **If you encounter an execution policy error**, run one of these commands before running the script again:
   - For temporary changes (recommended):
     ```powershell
     Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
     ```
   - Or run with a one-time override:
     ```powershell
     powershell -ExecutionPolicy Bypass -File .\GET_EAPBook_MMH_V2.ps1 -Base "..." -OutDir "..."
     ```

3. **Example Commands**:

   - Known page count (e.g., 28 pages) and generate a PDF at the end with a custom book name:
     ```powershell
     .\GET_EAPBook_MMH_V2.ps1 `
       -Base "https://images.eap.bl.uk/EAP127/EAP127_6_70" `
       -Pages 28 `
       -BookName "Sekh Pharider Puthi" `
       -OutDir "C:\Users\YourUsername\Desktop\EAP_Download" `
       -MakePdf
     ```

   - Auto-detect page count (no `-Pages` option) and create a PDF:
     ```powershell
     .\GET_EAPBook_MMH_V2.ps1 `
       -Base "https://images.eap.bl.uk/EAP127/EAP127_6_70" `
       -BookName "Sekh Pharider Puthi" `
       -OutDir "C:\Users\YourUsername\Desktop\EAP_Download"
     ```

## Notes:
- The script fetches the largest allowed image size available from the IIIF server.
- A small delay between requests is included by default (`-DelayMs`), to avoid overloading the server. You can adjust the delay as needed.
- **PDF creation** requires ImageMagick installed and added to your PATH. If ImageMagick is not available, the script will download the images but will not generate a PDF.

# Contributing

Thank you for considering contributing to this project!

## How to Contribute
1. Fork the repository.
2. Make your changes in a new branch.
3. Submit a pull request describing the changes you’ve made.

Please ensure that your contributions comply with the following guidelines:
- Follow the repository's coding style.
- Ensure your changes are for educational, non-commercial use.

© 2025 Md Mohsin Hossain. All rights reserved.