"""Fetch the STA KS2 scaled score conversion tables from GOV.UK and write them into the seed.

Source: the "Key stage 2 tests: <year> scaled scores" publications, read through the GOV.UK
Content API (https://www.gov.uk/api/content/...), which returns the page body as HTML inside JSON.
That is more stable than scraping the rendered page. Standard library only.

Usage:
    python scripts/build_ks2_conversion_seed.py                    # latest year on GOV.UK
    python scripts/build_ks2_conversion_seed.py --year 2025
    python scripts/build_ks2_conversion_seed.py --all              # every year GOV.UK still hosts
    python scripts/build_ks2_conversion_seed.py --check            # compare only; exit 1 on drift
    python scripts/build_ks2_conversion_seed.py --year 2026 --expect maths=56,reading=25,gps=34
    python scripts/build_ks2_conversion_seed.py --year 2026 --from-file ai/sources/ks2_scaled_scores_2026.html \
        --published-date 2026-07-16                                # offline, from a saved page

Rows for the fetched year(s) are replaced in the seed; other years are kept. The page body is saved
to ai/sources/ for provenance. The seed is never hand-edited: re-run this script instead.
"""

import argparse
import csv
import json
import re
import sys
import urllib.error
import urllib.request
from html.parser import HTMLParser
from pathlib import Path

API = "https://www.gov.uk/api"
PUBLICATION_PATH = "/government/publications/key-stage-2-tests-{year}-scaled-scores"
SEARCH_URL = API + "/search.json?q=key+stage+2+tests+scaled+scores&count=50&fields=title,link"
TITLE_RE = re.compile(r"^Key stage 2 tests: (\d{4}) scaled scores$", re.IGNORECASE)
RAW_CELL_RE = re.compile(r"^(\d+)(?:\s*[-–]\s*(\d+))?$")  # "7" or a range like "0 - 2"

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SEED = REPO_ROOT / "seeds" / "seed_ks2_scaled_score_conversion.csv"
SOURCES_DIR = REPO_ROOT / "ai" / "sources"

SEED_COLUMNS = [
    "test_year", "ks2_test", "raw_score", "scaled_score",
    "max_raw_score", "min_raw_for_scaled_score", "published_date",
]
# Paper totals have been fixed since 2016; a change means the test format changed, so fail loudly.
EXPECTED_MAX_RAW = {"gps": 70, "maths": 110, "reading": 50}
MIN_SCALED, MAX_SCALED, EXPECTED_STANDARD = 80, 120, 100


def heading_to_test(heading):
    h = heading.lower()
    if "grammar" in h:
        return "gps"
    if "reading" in h:
        return "reading"
    if "mathematics" in h or "maths" in h:
        return "maths"
    return None


def get_json(url):
    req = urllib.request.Request(url, headers={"Accept": "application/json",
                                               "User-Agent": "atom-ks2-seed-builder"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)


def find_published_years():
    """Years with a 'Key stage 2 tests: <year> scaled scores' publication, newest first."""
    years = set()
    for result in get_json(SEARCH_URL).get("results", []):
        m = TITLE_RE.match(result.get("title", "").strip())
        if m and result.get("link") == PUBLICATION_PATH.format(year=m.group(1)):
            years.add(int(m.group(1)))
    if not years:
        sys.exit("No KS2 scaled score publications found via GOV.UK search; pass --year.")
    return sorted(years, reverse=True)


def fetch_year(year):
    """Return (body_html, published_date, source_url) for one year's conversion tables."""
    try:
        pub = get_json(API + "/content" + PUBLICATION_PATH.format(year=year))
    except urllib.error.HTTPError as e:
        sys.exit(f"{year}: publication not found on GOV.UK (HTTP {e.code}).")
    html_attachments = [a for a in pub["details"].get("attachments", [])
                        if a.get("attachment_type") == "html"]
    if len(html_attachments) != 1:
        sys.exit(f"{year}: expected one HTML attachment, found {len(html_attachments)}.")
    path = html_attachments[0]["url"]
    page = get_json(API + "/content" + path)
    # first_published_at is local UK time with offset, e.g. 2024-07-09T00:00:00+01:00, so the
    # date part is the UK publication date (the UTC date can be a day earlier).
    published_date = pub["first_published_at"][:10]
    return page["details"]["body"], published_date, "https://www.gov.uk" + path


class TableParser(HTMLParser):
    """Collects {heading text: [(raw cell, scaled cell), ...]} from h2 + table pairs."""

    def __init__(self):
        super().__init__()
        self.tables, self._heading, self._in_h2 = {}, None, False
        self._row, self._cell = None, None

    def handle_starttag(self, tag, attrs):
        if tag == "h2":
            self._in_h2, self._heading = True, ""
        elif tag == "tr":
            self._row = []
        elif tag in ("td", "th") and self._row is not None:
            self._cell = ""

    def handle_endtag(self, tag):
        if tag == "h2":
            self._in_h2 = False
        elif tag in ("td", "th") and self._cell is not None:
            self._row.append(" ".join(self._cell.split()))
            self._cell = None
        elif tag == "tr" and self._row is not None:
            if len(self._row) == 2 and RAW_CELL_RE.match(self._row[0]) and self._heading:
                self.tables.setdefault(self._heading.strip(), []).append(tuple(self._row))
            self._row = None

    def handle_data(self, data):
        if self._in_h2:
            self._heading += data
        if self._cell is not None:
            self._cell += data


def parse_tables(body_html, year):
    parser = TableParser()
    parser.feed(body_html)
    tables = {}
    for heading, rows in parser.tables.items():
        test = heading_to_test(heading)
        if test is None:
            print(f"{year}: ignoring unrecognised table '{heading}'", file=sys.stderr)
            continue
        if test in tables:
            sys.exit(f"{year}: two tables map to '{test}'.")
        tables[test] = [(raw, int(scaled) if scaled.isdigit() else None)
                        for raw_cell, scaled in rows for raw in expand_raw(raw_cell)]
    return tables


def expand_raw(cell):
    """'7' -> [7]; '0 - 2' -> [0, 1, 2] (2024 groups the unscored marks into one row)."""
    lo, hi = RAW_CELL_RE.match(cell).groups()
    return list(range(int(lo), int(hi or lo) + 1))


def validate(tables, year, expect):
    errors = []
    if sorted(tables) != sorted(EXPECTED_MAX_RAW):
        errors.append(f"tests found {sorted(tables)}, expected {sorted(EXPECTED_MAX_RAW)}")
    for test, rows in sorted(tables.items()):
        raws = [r for r, _ in rows]
        scores = [s for _, s in rows if s is not None]
        if raws != list(range(len(raws))):
            errors.append(f"{test}: raw scores are not contiguous from 0")
        if raws and raws[-1] != EXPECTED_MAX_RAW.get(test):
            errors.append(f"{test}: max raw {raws[-1]}, expected {EXPECTED_MAX_RAW.get(test)}")
        first_scored = next((i for i, (_, s) in enumerate(rows) if s is not None), None)
        if first_scored is None or any(s is None for _, s in rows[first_scored:]):
            errors.append(f"{test}: unscored rows must all come before the first scored row")
        if scores and (min(scores) < MIN_SCALED or max(scores) > MAX_SCALED):
            errors.append(f"{test}: scaled scores outside {MIN_SCALED}-{MAX_SCALED}")
        if scores and scores[-1] != MAX_SCALED:
            errors.append(f"{test}: full marks score {scores[-1]}, expected {MAX_SCALED}")
        if any(b < a for a, b in zip(scores, scores[1:])):
            errors.append(f"{test}: scaled scores are not monotonic")
        es = next((r for r, s in rows if s is not None and s >= EXPECTED_STANDARD), None)
        print(f"{year} {test}: raw 0-{raws[-1] if raws else '?'}, min raw for a score "
              f"{rows[first_scored][0] if first_scored is not None else '?'}, "
              f"expected standard (100) at raw {es}")
        if test in expect and es != expect[test]:
            errors.append(f"{test}: expected standard at raw {es}, --expect says {expect[test]}")
    if errors:
        sys.exit(f"{year}: validation failed:\n  " + "\n  ".join(errors))


def to_seed_rows(tables, year, published_date):
    rows = []
    for test in sorted(tables):
        table = tables[test]
        max_raw = table[-1][0]
        min_raw = next(r for r, s in table if s is not None)
        for raw, scaled in table:
            rows.append({
                "test_year": str(year), "ks2_test": test, "raw_score": str(raw),
                "scaled_score": "" if scaled is None else str(scaled),
                "max_raw_score": str(max_raw), "min_raw_for_scaled_score": str(min_raw),
                "published_date": published_date,
            })
    return rows


def read_seed(path):
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames != SEED_COLUMNS:
            sys.exit(f"{path}: unexpected header {reader.fieldnames}, expected {SEED_COLUMNS}")
        return list(reader)


def sort_key(row):
    return int(row["test_year"]), row["ks2_test"], int(row["raw_score"])


def save_source(year, body_html, source_url, published_date):
    SOURCES_DIR.mkdir(parents=True, exist_ok=True)
    out = SOURCES_DIR / f"ks2_scaled_scores_{year}.html"
    out.write_text(f"<!-- source: {source_url} | published: {published_date} -->\n{body_html}\n",
                   encoding="utf-8")
    return out


def parse_expect(value):
    expect = {}
    for part in filter(None, (value or "").split(",")):
        test, _, raw = part.partition("=")
        if test.strip() not in EXPECTED_MAX_RAW or not raw.strip().isdigit():
            sys.exit(f"--expect: bad entry '{part}', use e.g. maths=56,reading=25,gps=34")
        expect[test.strip()] = int(raw)
    return expect


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    which = ap.add_mutually_exclusive_group()
    which.add_argument("--year", type=int, help="test year to fetch (default: latest published)")
    which.add_argument("--all", action="store_true", help="fetch every year GOV.UK hosts")
    ap.add_argument("--from-file", type=Path, help="parse a saved page body instead of fetching")
    ap.add_argument("--published-date", help="YYYY-MM-DD; required with --from-file")
    ap.add_argument("--expect", help="expected-standard raw marks, e.g. maths=56,reading=25,gps=34")
    ap.add_argument("--seed", type=Path, default=DEFAULT_SEED, help=f"default: {DEFAULT_SEED}")
    ap.add_argument("--check", action="store_true",
                    help="don't write anything; exit 1 if the seed differs from GOV.UK")
    args = ap.parse_args()
    expect = parse_expect(args.expect)

    if args.from_file:
        if not (args.year and args.published_date):
            ap.error("--from-file needs --year and --published-date")
        sources = {args.year: (args.from_file.read_text(encoding="utf-8"), args.published_date, None)}
    else:
        years = find_published_years() if args.all else [args.year or find_published_years()[0]]
        sources = {y: fetch_year(y) for y in years}

    new_rows = []
    for year, (body, published_date, url) in sorted(sources.items()):
        tables = parse_tables(body, year)
        validate(tables, year, expect)
        new_rows += to_seed_rows(tables, year, published_date)

    existing = read_seed(args.seed)
    kept = [r for r in existing if int(r["test_year"]) not in sources]
    merged = sorted(kept + new_rows, key=sort_key)

    if args.check:
        old = {tuple(r.values()) for r in existing if int(r["test_year"]) in sources}
        new = {tuple(r.values()) for r in new_rows}
        if old == new:
            print(f"OK: seed matches GOV.UK for {sorted(sources)}")
            return
        print(f"DRIFT: {len(new - old)} rows on GOV.UK not in seed, "
              f"{len(old - new)} rows in seed not on GOV.UK", file=sys.stderr)
        for row in sorted(new ^ old, key=lambda t: (t[0], t[1], int(t[2])))[:20]:
            print(("  +gov.uk " if row in new else "  -seed   ") + ",".join(row), file=sys.stderr)
        sys.exit(1)

    for year, (body, published_date, url) in sources.items():
        if url:
            print(f"saved {save_source(year, body, url, published_date).relative_to(REPO_ROOT)}")
    args.seed.parent.mkdir(parents=True, exist_ok=True)
    with args.seed.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=SEED_COLUMNS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(merged)
    print(f"wrote {len(merged)} rows to {args.seed} (years: "
          f"{sorted({int(r['test_year']) for r in merged})})")


if __name__ == "__main__":
    main()
