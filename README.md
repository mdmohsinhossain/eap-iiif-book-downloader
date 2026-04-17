# EAP IIIF Book Downloader

Download a British Library Endangered Archives Programme (EAP) archive item as a clean, locally saved PDF.

This is a Python-only project. It works on Windows, macOS, and Linux, and it does not need any bundled software.

Created by [Md Mohsin Hossain](https://mdmohsinhossain.github.io/).

## What This Tool Does

Given an EAP archive URL such as:

```text
https://eap.bl.uk/archive-file/EAP127-6-70
```

the downloader:

1. Converts the archive URL to the matching IIIF image URL.
2. Detects the number of pages.
3. Downloads the page images in order.
4. Creates one PDF named after the book.
5. Deletes the temporary page images after the PDF is successfully created.

Default output:

```text
output/<BookName>/<BookName>.pdf
```

Example output:

```text
output/Sekh Pharider Puthi/Sekh Pharider Puthi.pdf
```

## Why This Project Exists

The EAP website is excellent for browsing digitised archive material online, but researchers, students, and readers sometimes need a local PDF for offline study, annotation, citation checking, or easier reading.

This project is especially useful for EAP127, **Archiving 'popular market' Bengali books**, which contains many digitised Bengali popular-market books and related printed material.

Start browsing EAP127 here:

```text
https://eap.bl.uk/project/EAP127
```

On that page, open **View archives from this project** to see the individual archive records. Open a book/item, copy its `archive-file` URL, and pass that URL to this tool.

## Quick Start

First install Python 3 if it is not already installed.

Then clone or download this repository and open a terminal in the project folder.

### Linux Or macOS

Run:

```bash
./run_eap_book.sh "https://eap.bl.uk/archive-file/EAP127-6-70" --book-name "Sekh Pharider Puthi"
```

If macOS/Linux says the launcher is not executable:

```bash
chmod +x run_eap_book.sh
```

Then run the command again.

### Windows

Open a terminal in this project folder and run:

```bat
run_eap_book.bat "https://eap.bl.uk/archive-file/EAP127-6-70" --book-name "Sekh Pharider Puthi"
```

## First Run Behavior

The launcher scripts are designed to be plug and play:

- They create a local `.venv` folder.
- They install the required Python package from `requirements.txt`.
- They run `get_eap_book.py` with your URL and options.

Do **not** upload `.venv` to GitHub. It is machine-specific and already ignored by `.gitignore`.

## Common Examples

Download a book as a PDF:

```bash
./run_eap_book.sh "https://eap.bl.uk/archive-file/EAP127-6-70" --book-name "Sekh Pharider Puthi"
```

Download using the IIIF image base URL directly:

```bash
./run_eap_book.sh "https://images.eap.bl.uk/EAP127/EAP127_6_70" --book-name "Sekh Pharider Puthi"
```

Keep page images after creating the PDF:

```bash
./run_eap_book.sh "https://eap.bl.uk/archive-file/EAP127-6-70" --book-name "Sekh Pharider Puthi" --keep-images
```

Download images only, without creating a PDF:

```bash
./run_eap_book.sh "https://eap.bl.uk/archive-file/EAP127-6-70" --book-name "Sekh Pharider Puthi" --no-pdf
```

Download only a few pages for testing:

```bash
./run_eap_book.sh "https://eap.bl.uk/archive-file/EAP127-6-70" --book-name "Test Book" --pages 5
```

Use a different parent output folder:

```bash
./run_eap_book.sh "https://eap.bl.uk/archive-file/EAP127-6-70" --book-name "Sekh Pharider Puthi" --out-dir ".tmp/manual-test"
```

On Windows, use `run_eap_book.bat` instead of `./run_eap_book.sh`.

## How To Find The Right URL

Use an archive item URL from the EAP site:

```text
https://eap.bl.uk/archive-file/EAP127-6-70
```

The script automatically converts it to:

```text
https://images.eap.bl.uk/EAP127/EAP127_6_70
```

You can pass either URL format.

## Manual Python Setup

You can also run the Python script directly.

Linux/macOS:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python get_eap_book.py "https://eap.bl.uk/archive-file/EAP127-6-70" --book-name "Sekh Pharider Puthi"
```

Windows:

```bat
py -3 -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
.venv\Scripts\python.exe get_eap_book.py "https://eap.bl.uk/archive-file/EAP127-6-70" --book-name "Sekh Pharider Puthi"
```

## Options

| Option | Description |
| --- | --- |
| `url` | Required. EAP archive URL or `images.eap.bl.uk` IIIF base URL. |
| `--pages` | Known page count. If omitted, the script auto-detects pages. |
| `--book-name` | Name used for the output folder, page images, and PDF. |
| `--out-dir` | Parent output folder. Defaults to `output/` inside this project. |
| `--delay-ms` | Delay between page requests in milliseconds. Default: `300`. |
| `--pdf` | Create a PDF after downloading images. This is the default. |
| `--no-pdf` | Download page images only. |
| `--keep-images` | Keep page images after successful PDF creation. |
| `--overwrite` | Redownload existing page images. |
| `--delete-images-on-failure` | Delete expected page images if PDF creation fails. |

Show all options:

```bash
./run_eap_book.sh --help
```

## Output And Cleanup

By default, downloads stay inside this repository:

```text
output/<BookName>/
```

For a successful PDF run, the final folder contains only the PDF:

```text
output/<BookName>/<BookName>.pdf
```

Temporary page images are removed only after the PDF is created successfully. If PDF creation fails, images are kept so you can retry without downloading them again.

The script only deletes files it expects to have created. It does not delete unrelated files in your output folder.

## Repo Files

| File | Purpose |
| --- | --- |
| `get_eap_book.py` | Main Python downloader. |
| `run_eap_book.sh` | Linux/macOS launcher. |
| `run_eap_book.bat` | Windows launcher. |
| `requirements.txt` | Python dependency list. |
| `output/` | Local generated downloads. Ignored by Git. |
| `.venv/` | Local Python environment. Ignored by Git. |

## Responsible Use

Use this tool for educational, research, and non-commercial purposes. Keep the default delay between requests unless you have a good reason to change it. Respect the British Library EAP site's terms and any access notes shown for the material.

## License

Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0). See `LICENSE`.

## Author

Md Mohsin Hossain  
Website: https://mdmohsinhossain.github.io/
