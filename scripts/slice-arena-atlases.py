#!/usr/bin/env python3
"""Deterministically split 6x3 transparent arena art atlases into card PNGs."""
import argparse
import hashlib
import json
import math
from pathlib import Path

from PIL import Image


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def split_deck(root: Path, out_root: Path, deck_id: str, deck: dict, grid: dict) -> list:
    atlas_path = root / deck["atlas"]
    if not atlas_path.is_file():
        raise FileNotFoundError(f"Missing atlas for {deck_id}: {atlas_path}")
    columns, rows = grid["columns"], grid["rows"]
    if columns != 6 or rows != 3 or len(deck["cards"]) != columns * rows:
        raise ValueError(f"{deck_id} must have exactly 18 cards in a 6x3 atlas")

    with Image.open(atlas_path) as opened:
        atlas = opened.convert("RGBA")
    width, height = atlas.size
    if width < columns or height < rows:
        raise ValueError(f"Atlas too small for {deck_id}: {atlas.size}")

    atlas_hash = sha256(atlas_path)
    row_cuts = deck.get("rowCuts")
    if row_cuts is not None and (
        len(row_cuts) != rows + 1
        or row_cuts[0] != 0
        or row_cuts[-1] != height
        or any(not isinstance(cut, int) for cut in row_cuts)
        or any(a >= b for a, b in zip(row_cuts, row_cuts[1:]))
    ):
        raise ValueError(f"Invalid custom row cuts for {deck_id}")
    output_dir = out_root / deck_id
    output_dir.mkdir(parents=True, exist_ok=True)
    rows_out = []
    deck_hashes = set()
    for index, card in enumerate(deck["cards"]):
        row, column = divmod(index, columns)
        left = round(column * width / columns)
        right = round((column + 1) * width / columns)
        top = row_cuts[row] if row_cuts else round(row * height / rows)
        bottom = row_cuts[row + 1] if row_cuts else round((row + 1) * height / rows)
        cell = atlas.crop((left, top, right, bottom))
        alpha = cell.getchannel("A")
        visible_mask = alpha.point(lambda value: 255 if value > 24 else 0)
        visible_box = visible_mask.getbbox()
        if visible_box is None:
            raise ValueError(f"No visible art in {deck_id} cell {index}")
        vx0, vy0, vx1, vy1 = visible_box
        if min(vx0, vy0, cell.width - vx1, cell.height - vy1) < 3:
            raise ValueError(f"{deck_id} cell {index} art touches a grid boundary")

        # Trim against the >24 alpha silhouette and retain a two-pixel fringe
        # around it for antialiased edges without importing atlas background.
        fringe = 2
        x0, y0 = max(0, vx0 - fringe), max(0, vy0 - fringe)
        x1, y1 = min(cell.width, vx1 + fringe), min(cell.height, vy1 + fringe)
        subject = cell.crop((x0, y0, x1, y1))
        scale = min(448 / subject.width, 448 / subject.height)
        target_size = (
            max(1, round(subject.width * scale)),
            max(1, round(subject.height * scale)),
        )
        subject = subject.resize(target_size, Image.Resampling.LANCZOS)
        card_image = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
        offset = ((512 - target_size[0]) // 2, (512 - target_size[1]) // 2)
        card_image.alpha_composite(subject, offset)

        slug = card["id"]
        output_path = output_dir / f"original-{slug}.png"
        card_image.save(output_path, format="PNG", optimize=True)
        card_hash = sha256(output_path)
        if card_hash in deck_hashes:
            raise ValueError(f"Repeated artwork in {deck_id}: {slug}")
        deck_hashes.add(card_hash)
        row_record = {
            "theme": deck_id,
            "value": index,
            "name": slug,
            "label": card["label"],
            "asset": output_path.relative_to(root / "app").as_posix(),
            "source": "OpenAI ImageGen built-in",
            "atlas": deck["atlas"],
            "atlasSha256": atlas_hash,
            "prompt": deck["prompt"],
            "grid": {"columns": columns, "rows": rows, "row": row, "column": column},
            "crop": {
                "x": left,
                "y": top,
                "width": right - left,
                "height": bottom - top,
                "visibleBoundsAlphaGreaterThan24": [vx0, vy0, vx1 - vx0, vy1 - vy0],
                "trimBounds": [x0, y0, x1 - x0, y1 - y0],
                "resize": list(target_size),
                "padOffset": list(offset),
            },
            "tool": "scripts/slice-arena-atlases.py",
            "width": 512,
            "height": 512,
            "bytes": output_path.stat().st_size,
            "sha256": card_hash,
        }
        if deck.get("editingPrompt"):
            row_record["editingPrompt"] = deck["editingPrompt"]
        rows_out.append(row_record)
    return rows_out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--manifest", type=Path, default=Path("scripts/arena-original-art.json"))
    parser.add_argument("--deck", action="append", help="Process selected decks for atlas QA")
    args = parser.parse_args()
    root = args.root.resolve()
    manifest_path = args.manifest if args.manifest.is_absolute() else root / args.manifest
    source = json.loads(manifest_path.read_text(encoding="utf-8"))
    if source.get("schemaVersion") != 1:
        raise ValueError("Unsupported original art manifest schema")
    decks = source["decks"]
    if args.deck:
        unknown = set(args.deck) - set(decks)
        if unknown:
            raise KeyError(f"Unknown atlas deck: {', '.join(sorted(unknown))}")
        selected = {deck_id: decks[deck_id] for deck_id in args.deck}
    else:
        selected = decks
    all_rows = []
    for deck_id, deck in selected.items():
        rows = split_deck(root, root / "app/assets/decks", deck_id, deck, source["grid"])
        all_rows.extend(rows)
        print(f"{deck_id}: sliced {len(rows)} transparent card images")
    report_path = root / "artifacts/arenas/generated-crops.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    if args.deck and report_path.exists():
        previous = json.loads(report_path.read_text(encoding="utf-8"))
        selected_ids = set(args.deck)
        all_rows = [row for row in previous if row["theme"] not in selected_ids] + all_rows
        all_rows.sort(key=lambda row: (row["theme"], row["value"]))
    report_path.write_text(json.dumps(all_rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
