"""Ingest the raw assignment data from Azure Blob Storage into the bronze layer.

Bronze contract: files land exactly as received, plus a manifest recording
when and from where they were ingested. No parsing, no cleaning here.
"""
import io
import json
import os
import zipfile
from datetime import datetime, timezone
from pathlib import Path

from azure.storage.blob import BlobClient
from dotenv import load_dotenv

BRONZE_DIR = Path("data/bronze")


def main() -> None:
    load_dotenv() # load sas url from .env file
    sas_url = os.environ["SAS_URL"]  # fail loudly if not configured

    ingested_at = datetime.now(timezone.utc) # record the ingestion time in UTC

    blob = BlobClient.from_blob_url(sas_url)
    raw = blob.download_blob().readall()

    BRONZE_DIR.mkdir(parents=True, exist_ok=True)

    # 1. keep the zip exactly as received: this is the immutable raw artifact
    archive_dir = BRONZE_DIR / "archives"
    archive_dir.mkdir(parents=True, exist_ok=True)
    (BRONZE_DIR / "archives" / "data_assignment.zip").write_bytes(raw)

    # 2. extract the real data files; skip macOS zip artifacts (__MACOSX/, ._*)
    extracted_dir = BRONZE_DIR / "extracted"
    extracted_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(raw)) as zf:
        all_entries = zf.namelist()
        members = [
            m for m in all_entries
            if not m.startswith("__MACOSX/") and not m.endswith("/")
        ]
        zf.extractall(BRONZE_DIR / "extracted", members=members)

    # 3. manifest: ingestion metadata the transform layer can pick up
    manifest_dir = BRONZE_DIR / "manifest"
    manifest_dir.mkdir(parents=True, exist_ok=True)
    manifest = {
        "ingested_at_utc": ingested_at.isoformat(),
        "source_blob": sas_url.split("?")[0],  # URL only, never the token
        "zip_entries": all_entries,        # everything the delivery contained
        "files_extracted": members,        # what we consider actual data
    }
    (BRONZE_DIR / "manifest" / "data_assignment_manifest.json").write_text(json.dumps(manifest, indent=2))

    print(f"Ingested {len(members)} data files at {ingested_at.isoformat()}")
    for name in members:
        print(f"  - {name}")


if __name__ == "__main__":
    main()