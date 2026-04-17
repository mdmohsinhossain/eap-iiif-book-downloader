#!/usr/bin/env python3
"""Cross-platform EAP IIIF book downloader."""

from __future__ import annotations

import argparse
import importlib.util
import json
import re
import shutil
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from textwrap import dedent
from typing import Iterable, Sequence


PROJECT_ROOT = Path(__file__).resolve().parent
DEFAULT_BOOK_NAME = "EAP_Book"
DEFAULT_DELAY_MS = 300
DEFAULT_TIMEOUT = 30
DEFAULT_RETRIES = 2
MANIFEST_NAME = ".eap-downloader-files.txt"
USER_AGENT = "eap-iiif-book-downloader/1.0"


class DownloadError(RuntimeError):
    """Raised when a page cannot be downloaded from any IIIF candidate URL."""


class DependencyError(RuntimeError):
    """Raised when an optional dependency is required for the requested mode."""


def require_pdf_dependency() -> None:
    if importlib.util.find_spec("img2pdf") is None:
        raise DependencyError(
            "PDF creation requires img2pdf. Install it in the same Python environment with: "
            "python3 -m pip install -r requirements.txt "
            "or run with --no-pdf to download images only."
        )


def sanitize_filename(name: str) -> str:
    """Return a name that is safe on Windows, macOS, and Linux."""
    cleaned = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", name).strip()
    cleaned = re.sub(r"\s+", " ", cleaned)
    cleaned = cleaned.strip(" ._")
    return cleaned or DEFAULT_BOOK_NAME


def normalize_eap_url(url: str) -> str:
    """Accept an EAP archive URL or an IIIF image base URL and return the base."""
    value = url.strip().rstrip("/")
    parsed = urllib.parse.urlparse(value)

    if not parsed.scheme or not parsed.netloc:
        raise ValueError("URL must include a scheme and host, for example https://...")

    host = parsed.netloc.lower()
    path_parts = [part for part in parsed.path.split("/") if part]

    if host == "eap.bl.uk" and len(path_parts) >= 2 and path_parts[0] == "archive-file":
        archive_id = path_parts[1]
        tokens = archive_id.split("-")
        if len(tokens) < 2 or not tokens[0].startswith("EAP"):
            raise ValueError(f"Unsupported EAP archive id: {archive_id}")
        collection = tokens[0]
        item = "_".join(tokens)
        return f"https://images.eap.bl.uk/{collection}/{item}"

    if host == "images.eap.bl.uk":
        base_parts = []
        for part in path_parts:
            if re.fullmatch(r"\d+\.jp2", part):
                break
            base_parts.append(part)
        if len(base_parts) < 2:
            raise ValueError("IIIF image URL must include collection and item paths")
        return urllib.parse.urlunparse((parsed.scheme, parsed.netloc, "/" + "/".join(base_parts), "", "", ""))

    raise ValueError("URL must be an images.eap.bl.uk IIIF URL or an eap.bl.uk archive-file URL")


def choose_iiif_size(info: dict) -> str:
    """Choose the largest advertised IIIF size supported by the server."""
    if info.get("maxWidth") or info.get("maxHeight") or info.get("maxArea"):
        return "full/max"

    sizes = info.get("sizes") or []
    valid_sizes = [
        size
        for size in sizes
        if isinstance(size, dict) and isinstance(size.get("width"), int) and isinstance(size.get("height"), int)
    ]
    if valid_sizes:
        largest = max(valid_sizes, key=lambda size: size["width"] * size["height"])
        return f"full/{largest['width']},{largest['height']}"

    return "full/max"


def output_paths(book_name: str, out_dir: str | None) -> tuple[str, Path, Path, Path]:
    """Return clean book name, book output folder, image folder, and PDF path."""
    clean_book_name = sanitize_filename(book_name)
    parent = Path(out_dir).expanduser() if out_dir else PROJECT_ROOT / "output"
    if not parent.is_absolute():
        parent = Path.cwd() / parent
    book_dir = parent if parent.name == clean_book_name else parent / clean_book_name
    image_dir = book_dir / f"{clean_book_name}_images"
    pdf_path = book_dir / f"{clean_book_name}.pdf"
    return clean_book_name, book_dir, image_dir, pdf_path


def page_filename(book_name: str, page: int, total_pages: int) -> str:
    width = max(3, len(str(total_pages)))
    return f"{book_name}-{page:0{width}d}.jpg"


def expected_image_paths(image_dir: Path, book_name: str, total_pages: int) -> list[Path]:
    return [image_dir / page_filename(book_name, page, total_pages) for page in range(1, total_pages + 1)]


def cleanup_expected_files(paths: Iterable[Path], image_dir: Path) -> None:
    """Remove downloader-created files and remove the staging directory only if empty."""
    for path in paths:
        try:
            path.unlink()
        except FileNotFoundError:
            pass

    manifest = image_dir / MANIFEST_NAME
    try:
        manifest.unlink()
    except FileNotFoundError:
        pass

    try:
        image_dir.rmdir()
    except OSError:
        pass


def request_url(url: str, timeout: int = DEFAULT_TIMEOUT) -> urllib.request.Request:
    return urllib.request.Request(url, headers={"User-Agent": USER_AGENT})


def fetch_json(url: str, timeout: int = DEFAULT_TIMEOUT, retries: int = DEFAULT_RETRIES) -> dict:
    last_error: Exception | None = None
    for attempt in range(retries + 1):
        try:
            with urllib.request.urlopen(request_url(url), timeout=timeout) as response:
                return json.loads(response.read().decode("utf-8"))
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            last_error = exc
            if isinstance(exc, urllib.error.HTTPError) and exc.code == 404:
                break
            if attempt < retries:
                time.sleep(0.5 * (attempt + 1))
    raise DownloadError(f"Could not fetch JSON from {url}: {last_error}") from last_error


def detect_page_count(base_url: str, timeout: int = DEFAULT_TIMEOUT, retries: int = DEFAULT_RETRIES) -> int:
    page = 1
    while True:
        try:
            fetch_json(f"{base_url}/{page}.jp2/info.json", timeout=timeout, retries=retries)
        except DownloadError:
            break
        page += 1

    total = page - 1
    if total < 1:
        raise DownloadError(f"No pages discovered under {base_url}. Please verify the URL.")
    return total


def unique_values(values: Sequence[str]) -> list[str]:
    seen = set()
    result = []
    for value in values:
        if value not in seen:
            seen.add(value)
            result.append(value)
    return result


def image_candidates(base_url: str, page: int, size_param: str) -> list[str]:
    return unique_values(
        [
            f"{base_url}/{page}.jp2/{size_param}/0/default.jpg",
            f"{base_url}/{page}.jp2/full/max/0/default.jpg",
            f"{base_url}/{page}.jp2/full/full/0/default.jpg",
            f"{base_url}/{page}.jp2/full/!8000,8000/0/default.jpg",
        ]
    )


def download_file(url: str, destination: Path, timeout: int = DEFAULT_TIMEOUT, retries: int = DEFAULT_RETRIES) -> None:
    last_error: Exception | None = None
    for attempt in range(retries + 1):
        try:
            with urllib.request.urlopen(request_url(url), timeout=timeout) as response:
                with destination.open("wb") as outfile:
                    shutil.copyfileobj(response, outfile)
            if destination.stat().st_size > 0:
                return
            destination.unlink(missing_ok=True)
            last_error = DownloadError("downloaded file was empty")
        except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError, OSError) as exc:
            destination.unlink(missing_ok=True)
            last_error = exc
            if isinstance(exc, urllib.error.HTTPError) and exc.code == 404:
                break
            if attempt < retries:
                time.sleep(0.5 * (attempt + 1))
    raise DownloadError(f"Could not download {url}: {last_error}") from last_error


def download_page(
    base_url: str,
    page: int,
    destination: Path,
    size_param: str,
    overwrite: bool,
    timeout: int = DEFAULT_TIMEOUT,
    retries: int = DEFAULT_RETRIES,
) -> bool:
    """Download one page. Return True if a new file was downloaded."""
    if destination.exists() and destination.stat().st_size > 0 and not overwrite:
        return False

    destination.parent.mkdir(parents=True, exist_ok=True)
    for candidate in image_candidates(base_url, page, size_param):
        try:
            download_file(candidate, destination, timeout=timeout, retries=retries)
            return True
        except DownloadError:
            continue
    raise DownloadError(f"Failed to download page {page}")


def write_manifest(image_dir: Path, image_paths: Sequence[Path]) -> None:
    manifest = image_dir / MANIFEST_NAME
    manifest.write_text("\n".join(path.name for path in image_paths) + "\n", encoding="utf-8")


def create_pdf(image_paths: Sequence[Path], pdf_path: Path) -> None:
    import img2pdf

    pdf_path.parent.mkdir(parents=True, exist_ok=True)
    with pdf_path.open("wb") as pdf_file:
        pdf_file.write(img2pdf.convert([str(path) for path in image_paths]))

    if not pdf_path.exists() or pdf_path.stat().st_size == 0:
        raise RuntimeError(f"PDF was not created: {pdf_path}")


def positive_int(value: str) -> int:
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be 1 or greater")
    return number


def non_negative_int(value: str) -> int:
    number = int(value)
    if number < 0:
        raise argparse.ArgumentTypeError("must be 0 or greater")
    return number


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Download British Library EAP IIIF page images and bind them into a clean PDF.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=dedent(
            """\
            examples:
              python3 get_eap_book.py "https://eap.bl.uk/archive-file/EAP127-6-70" --book-name "Sekh Pharider Puthi"
              python3 get_eap_book.py "https://images.eap.bl.uk/EAP127/EAP127_6_70" --book-name "Sekh Pharider Puthi" --no-pdf
              python3 get_eap_book.py "https://eap.bl.uk/archive-file/EAP127-6-70" --book-name "Sekh Pharider Puthi" --keep-images
            """
        ),
    )
    parser.add_argument("url", help="EAP archive URL or images.eap.bl.uk IIIF base URL")
    parser.add_argument("--pages", type=positive_int, help="known page count; skips auto-detection")
    parser.add_argument("--book-name", default=DEFAULT_BOOK_NAME, help=f"book name for output files (default: {DEFAULT_BOOK_NAME})")
    parser.add_argument("--out-dir", help="parent output folder; defaults to ./output inside this project")
    parser.add_argument("--delay-ms", type=non_negative_int, default=DEFAULT_DELAY_MS, help=f"delay between page requests (default: {DEFAULT_DELAY_MS})")
    parser.add_argument("--pdf", dest="make_pdf", action="store_true", default=True, help="create a PDF after downloading images (default)")
    parser.add_argument("--no-pdf", dest="make_pdf", action="store_false", help="download images only")
    parser.add_argument("--keep-images", action="store_true", help="keep downloaded page images after successful PDF creation")
    parser.add_argument("--overwrite", action="store_true", help="redownload existing page images")
    parser.add_argument("--delete-images-on-failure", action="store_true", help="delete expected page images if PDF creation fails")
    return parser


def run(args: argparse.Namespace) -> int:
    base_url = normalize_eap_url(args.url)
    clean_book_name, book_dir, image_dir, pdf_path = output_paths(args.book_name, args.out_dir)

    if args.make_pdf:
        require_pdf_dependency()

    print(f"Base URL: {base_url}")
    print(f"Output folder: {book_dir}")

    total_pages = args.pages
    if total_pages is None:
        print("Detecting page count...")
        total_pages = detect_page_count(base_url)
        print(f"Detected {total_pages} pages.")

    print("Fetching IIIF info for optimal image size...")
    try:
        size_param = choose_iiif_size(fetch_json(f"{base_url}/1.jp2/info.json"))
    except DownloadError:
        size_param = "full/max"
        print(f"Warning: could not fetch IIIF info; using {size_param}", file=sys.stderr)
    print(f"Using image size: {size_param}")

    book_dir.mkdir(parents=True, exist_ok=True)
    image_dir.mkdir(parents=True, exist_ok=True)
    image_paths = expected_image_paths(image_dir, clean_book_name, total_pages)
    write_manifest(image_dir, image_paths)

    failed_pages: list[int] = []
    downloaded_count = 0
    for page, image_path in enumerate(image_paths, start=1):
        try:
            downloaded = download_page(base_url, page, image_path, size_param, args.overwrite)
            downloaded_count += int(downloaded)
            action = "saved" if downloaded else "kept"
            print(f"[{page}/{total_pages}] {action}: {image_path.name}")
        except DownloadError as exc:
            failed_pages.append(page)
            print(f"[{page}/{total_pages}] failed: {exc}", file=sys.stderr)
        if args.delay_ms:
            time.sleep(args.delay_ms / 1000)

    if failed_pages:
        print("Download finished with failed pages: " + ", ".join(str(page) for page in failed_pages), file=sys.stderr)
        print(f"Images saved in: {image_dir}")
        return 1

    if not args.make_pdf:
        print(f"Downloaded {total_pages} images ({downloaded_count} new).")
        print(f"Images saved in: {image_dir}")
        return 0

    try:
        print("Creating PDF...")
        create_pdf(image_paths, pdf_path)
        print(f"PDF saved as: {pdf_path}")
    except Exception as exc:
        print(f"PDF creation failed: {exc}", file=sys.stderr)
        if args.delete_images_on_failure:
            cleanup_expected_files(image_paths, image_dir)
            print("Deleted expected page images after PDF failure.")
        else:
            print(f"Images kept for retry: {image_dir}")
        return 1

    if args.keep_images:
        print(f"Images kept in: {image_dir}")
    else:
        cleanup_expected_files(image_paths, image_dir)
        print("Cleaned downloaded page images.")

    print("--- Download Complete ---")
    print(f"Final file: {pdf_path}")
    return 0


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    if argv is None:
        argv = sys.argv[1:]
    if not argv:
        parser.print_help(sys.stderr)
        print("\nerror: URL is required. Use an EAP archive URL or images.eap.bl.uk IIIF URL.", file=sys.stderr)
        return 2
    args = parser.parse_args(argv)
    try:
        return run(args)
    except (ValueError, DownloadError, DependencyError, KeyboardInterrupt) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
