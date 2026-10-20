# Planning log

Decisions made with AI assistance (Claude Code), newest last. Detailed rationale lives in
`CLAUDE.md` / `PLAN.md`; this file records when and why things changed.

## 2026-10-20: repo setup
- **Conversion seed script now fetches from GOV.UK.** Previously it parsed a saved page. It reads
  the GOV.UK Content API (JSON wrapping the page HTML) for "Key stage 2 tests: <year> scaled
  scores", validates each table, and merges by year. Re-fetching 2024–2026 matched the
  hand-transcribed seed row-for-row. The 2024 page groups raw marks "0 - 2" into one row, so the
  parser expands ranges. GOV.UK returns 404 for 2023.
- **Seed files were swapped.** `seed_ks2_scaled_score_conversion.csv` held the subject mapping and
  `_seeds.yml` held the conversion table. Moved the mapping to `seeds/seed_subject_to_ks2_test.csv`,
  regenerated the conversion seed with the script, and made `_seeds.yml` a real properties file.
- **uv for Python.** `pyproject.toml` + `uv.lock` pin dbt-core 1.12.6 / dbt-bigquery 1.12.1 on
  Python 3.12. dbt v2 exists, but the brief and CLAUDE.md specify dbt Core.
- **Seed tests as singular tests** in `tests/`: weights sum to 1 per subject, all three tests per
  conversion year, monotonic conversion tables.
- **No source tests on `responses`**: they would full-scan a table expected to exceed 100m rows.
