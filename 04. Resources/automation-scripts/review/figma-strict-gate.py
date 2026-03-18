#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json


CANONICAL_SOURCES = {"api", "cache", "playwright"}
NON_CANONICAL_PATH_MARKERS = ("/manual/", "/proxy-", "/proxy_", "proxy-screenshots")
CANONICAL_PATH_MARKERS = ("/artifacts/figma-reference/cache/", "/artifacts/figma-reference/baseline/")


def normalize_bool(value: str) -> bool:
    return value.strip().lower() in {"1", "true", "yes", "y"}


def is_canonical_reference(source: str, figma_path: str) -> bool:
    if source in CANONICAL_SOURCES:
        return True
    lowered = figma_path.lower()
    if any(marker in lowered for marker in NON_CANONICAL_PATH_MARKERS):
        return False
    return any(marker in lowered for marker in CANONICAL_PATH_MARKERS)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app-source", default="unknown")
    parser.add_argument("--app-fresh", default="no")
    parser.add_argument("--app-route-accurate", default="no")
    parser.add_argument("--figma-source", default="unresolved")
    parser.add_argument("--figma-path", default="")
    args = parser.parse_args()

    reasons: list[str] = []
    reference_canonical = is_canonical_reference(args.figma_source, args.figma_path)

    if not reference_canonical:
        reasons.append("figma-reference-not-canonical")
    if not normalize_bool(args.app_fresh):
        reasons.append("app-screenshot-not-fresh")
    if not normalize_bool(args.app_route_accurate):
        reasons.append("app-screenshot-not-route-accurate")

    payload = {
        "status": "verified" if not reasons else "blocked",
        "reference_kind": "canonical" if reference_canonical else "non-canonical",
        "reasons": reasons,
        "reason": ",".join(reasons) if reasons else "none",
        "app_source": args.app_source,
        "app_fresh": normalize_bool(args.app_fresh),
        "app_route_accurate": normalize_bool(args.app_route_accurate),
        "figma_source": args.figma_source,
        "figma_path": args.figma_path,
    }
    print(json.dumps(payload, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
