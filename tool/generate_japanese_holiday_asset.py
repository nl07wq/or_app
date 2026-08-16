#!/usr/bin/env python3
"""Fetch and validate the Cabinet Office holiday CSV for web deployment."""

from __future__ import annotations

import argparse
import csv
import io
import json
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen


SOURCE_URL = "https://www8.cao.go.jp/chosei/shukujitsu/syukujitsu.csv"
EXPECTED_HEADER = ["国民の祝日・休日月日", "国民の祝日・休日名称"]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    request = Request(SOURCE_URL, headers={"User-Agent": "or-app-deploy"})
    with urlopen(request, timeout=30) as response:
        if response.status != 200:
            raise RuntimeError(f"Holiday CSV returned HTTP {response.status}")
        raw = response.read()
        source_last_modified = response.headers.get("Last-Modified")

    if not raw:
        raise RuntimeError("Holiday CSV is empty")
    text = raw.decode("cp932")
    rows = list(csv.reader(io.StringIO(text)))
    if not rows or rows[0] != EXPECTED_HEADER:
        raise RuntimeError("Holiday CSV header does not match the formal contract")

    holidays: list[str] = []
    names: dict[str, str] = {}
    for line_number, row in enumerate(rows[1:], start=2):
        if len(row) != 2 or not row[1].strip():
            raise RuntimeError(f"Invalid holiday row at line {line_number}")
        try:
            value = datetime.strptime(row[0], "%Y/%m/%d").date().isoformat()
        except ValueError as error:
            raise RuntimeError(
                f"Invalid holiday date at line {line_number}: {row[0]}"
            ) from error
        if value in names:
            raise RuntimeError(f"Duplicate holiday date: {value}")
        holidays.append(value)
        names[value] = row[1].strip()

    if not holidays:
        raise RuntimeError("Holiday CSV contains no holiday rows")
    if holidays != sorted(holidays):
        raise RuntimeError("Holiday CSV dates are not sorted")

    generated_at = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    payload = {
        "schemaVersion": 1,
        "source": "cabinet_office_japan",
        "sourceUrl": SOURCE_URL,
        "dataUpdatedAt": generated_at,
        "sourceLastModified": source_last_modified,
        "coverageFrom": holidays[0],
        "coverageTo": holidays[-1],
        "holidays": holidays,
    }
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(payload, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )
    print(
        f"Generated {output} with {len(holidays)} holidays "
        f"({holidays[0]} to {holidays[-1]})"
    )


if __name__ == "__main__":
    main()
