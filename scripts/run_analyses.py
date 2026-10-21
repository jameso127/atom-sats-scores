"""Dry-run or run the profiling queries in analyses/ and save each result as a CSV.

Usage:
    uv run python scripts/run_analyses.py               # dry run all: GB each query would scan
    uv run python scripts/run_analyses.py --run         # run all, save analyses/results/<name>.csv
    uv run python scripts/run_analyses.py --run 05 17   # only files starting with these prefixes

Uses your gcloud application-default credentials, in europe-west2.
"""

import csv
import sys
from pathlib import Path

from google.auth.exceptions import DefaultCredentialsError, RefreshError
from google.cloud import bigquery

ROOT = Path(__file__).resolve().parent.parent
RESULTS = ROOT / "analyses" / "results"


def main():
    run = "--run" in sys.argv
    prefixes = tuple(a for a in sys.argv[1:] if a != "--run")
    files = sorted(p for p in (ROOT / "analyses").glob("*.sql")
                   if not prefixes or p.name.startswith(prefixes))
    client = bigquery.Client(project="atom-analytics-candidates", location="europe-west2")

    total_gb = 0.0
    for path in files:
        sql = path.read_text(encoding="utf-8")
        dry = client.query(sql, job_config=bigquery.QueryJobConfig(dry_run=True, use_query_cache=False))
        gb = dry.total_bytes_processed / 1e9
        total_gb += gb
        print(f"{path.name}: {gb:.3f} GB", end="", flush=True)
        if not run:
            print()
            continue
        rows = client.query(sql).result()
        RESULTS.mkdir(exist_ok=True)
        out = RESULTS / f"{path.stem}.csv"
        with out.open("w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f, lineterminator="\n")
            writer.writerow([field.name for field in rows.schema])
            writer.writerows(row.values() for row in rows)
        print(f" -> {out.relative_to(ROOT)} ({rows.total_rows} rows)")
    print(f"total: {total_gb:.3f} GB {'scanned' if run else 'would be scanned'}")


if __name__ == "__main__":
    try:
        main()
    except (RefreshError, DefaultCredentialsError):
        sys.exit("BigQuery credentials missing or expired. Run: gcloud auth application-default login")
