"""Copies src/*.lua into the embedded scripts of a .rbxlx place file.

The place file is opened directly in Roblox Studio, so it carries its own copy
of every script. src/ stays the source of truth; this pushes those sources into
the place so Studio runs what is in the repository.

Two dialects of the same file
-----------------------------
A place written by this script stores a script's body as `<string name="Source">`.
A place that has been *opened and saved in Studio* comes back in Studio's own
dialect: the body is a `<ProtectedString>`, and the properties are re-ordered so
that `Source` can appear *before* `Name` in the same Item.

That second point is what matters. An earlier version of this script found a
script's name by taking the last `<Name>` seen before a `<Source>`, which silently
picks up the *parent folder's* name once Studio has re-ordered the properties. The
script then believed those scripts were absent and inserted duplicates of them -
two `Client` LocalScripts in one place both run.

So this file now reads each `<Item>` as a unit and takes the Name and Source from
that Item's own `<Properties>` block, never from whatever happens to sit nearby.
It also removes duplicate scripts, to repair a place that a previous version
damaged.

Usage:
    python scripts/sync_place.py                      # CuteFamilyTown-Wildwood.rbxlx
    python scripts/sync_place.py --place other.rbxlx
    python scripts/sync_place.py --check              # fail if the place is stale
    python scripts/sync_place.py --prune              # also remove scripts deleted from src/
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PLACE = "CuteFamilyTown-Wildwood.rbxlx"

SOURCE_BLOCK = re.compile(
    r'(<(?P<tag>ProtectedString|string) name="Source"><!\[CDATA\[)(?P<body>.*?)(\]\]></(?P=tag)>)',
    re.S,
)
NAME_TAG = re.compile(r'<string name="Name">([^<]+)</string>')
ITEM_OPEN = re.compile(r'<Item class="(?P<class>\w+)"')
SCRIPT_CLASSES = {"Script", "LocalScript", "ModuleScript"}


@dataclass
class Item:
    """One <Item> in the place, with the spans needed to rewrite it in place."""

    start: int  # index of "<Item"
    end: int  # index just past "</Item>"
    cls: str
    name: str
    body_start: int | None  # span of the Source CDATA, if this Item has one
    body_end: int | None
    body: str | None

    @property
    def is_script(self) -> bool:
        return self.cls in SCRIPT_CLASSES


def script_sources() -> dict[str, str]:
    sources = {}
    for path in (ROOT / "src").rglob("*.lua"):
        # Client.client.lua and Server.server.lua map to Client and Server.
        sources[path.name.split(".")[0]] = path.read_text(encoding="utf-8")
    return sources


def class_of(path: Path) -> str:
    if path.name.endswith(".client.lua"):
        return "LocalScript"
    if path.name.endswith(".server.lua"):
        return "Script"
    return "ModuleScript"


def close_of(xml: str, start: int) -> int:
    """Index of the </Item> that closes the Item opening at `start`."""
    depth = 0
    cursor = start
    while cursor < len(xml):
        opening = xml.find("<Item ", cursor)
        closing = xml.find("</Item>", cursor)
        if closing == -1:
            raise SystemExit("Malformed place file: unbalanced <Item>")
        if opening != -1 and opening < closing:
            depth += 1
            cursor = opening + 6
        else:
            depth -= 1
            if depth == 0:
                return closing
            cursor = closing + 7
    raise SystemExit("Malformed place file: unbalanced <Item>")


def parse_items(xml: str) -> list[Item]:
    """Every <Item>, with the Name and Source taken from its *own* Properties block.

    An Item's own properties are the ones before its first nested <Item>; anything
    after that belongs to a child. Reading them this way is what keeps a script's
    Source tied to its own Name no matter how Studio ordered the properties.
    """
    items: list[Item] = []
    for open_match in ITEM_OPEN.finditer(xml):
        start = open_match.start()
        end = close_of(xml, start)

        props_open = xml.find("<Properties>", start, end)
        if props_open == -1:
            continue
        props_close = xml.find("</Properties>", props_open, end)
        child = xml.find("<Item ", start + 1, end)
        if child != -1 and child < props_open:
            continue  # malformed; properties must precede children
        own = xml[props_open:props_close]

        names = NAME_TAG.findall(own)
        if not names:
            continue

        body_start = body_end = None
        body = None
        source = SOURCE_BLOCK.search(own)
        if source:
            body_start = props_open + source.start("body")
            body_end = props_open + source.end("body")
            body = source.group("body")

        items.append(
            Item(
                start=start,
                end=end + len("</Item>"),
                cls=open_match.group("class"),
                name=names[0],
                body_start=body_start,
                body_end=body_end,
                body=body,
            )
        )
    return items


def remove_duplicate_scripts(xml: str) -> tuple[str, list[str]]:
    """Drop repeat script Items, keeping the first of each name.

    Script names are unique across src/, so a second Item with the same name is
    always damage - two LocalScripts of the same name would both run.
    """
    items = [item for item in parse_items(xml) if item.is_script]
    seen: set[str] = set()
    duplicates: list[Item] = []
    for item in items:
        if item.name in seen:
            duplicates.append(item)
        else:
            seen.add(item.name)

    # Cut from the back so earlier spans stay valid.
    removed = []
    for item in sorted(duplicates, key=lambda i: i.start, reverse=True):
        line_start = xml.rfind("\n", 0, item.start) + 1
        cut_end = item.end
        if xml[cut_end : cut_end + 1] == "\n":
            cut_end += 1
        xml = xml[:line_start] + xml[cut_end:]
        removed.append(item.name)
    return xml, sorted(removed)


def remove_scripts_named(xml: str, names: set[str]) -> tuple[str, list[str]]:
    """Remove script Items whose source files were intentionally retired.

    This is only called by the explicit --prune mode so a normal sync never
    deletes an unexpected Studio-authored script.
    """
    targets = [item for item in parse_items(xml) if item.is_script and item.name in names]
    removed: list[str] = []
    for item in sorted(targets, key=lambda i: i.start, reverse=True):
        line_start = xml.rfind("\n", 0, item.start) + 1
        cut_end = item.end
        if xml[cut_end : cut_end + 1] == "\n":
            cut_end += 1
        xml = xml[:line_start] + xml[cut_end:]
        removed.append(item.name)
    return xml, sorted(removed)


def container_named(xml: str, name: str) -> int | None:
    """Start index of the <Item> named `name` that can hold scripts."""
    for item in parse_items(xml):
        if item.name == name and not item.is_script:
            return item.start
    return None


def add_missing_scripts(xml: str, present: set[str]) -> tuple[str, list[str]]:
    """Insert scripts that exist in src/ but not yet in the place file."""
    added: list[str] = []
    referent = max((int(v) for v in re.findall(r'referent="(\d+)"', xml)), default=100)
    # Write new scripts in whichever dialect the place already speaks.
    tag = "ProtectedString" if '<ProtectedString name="Source">' in xml else "string"

    for path in sorted((ROOT / "src").rglob("*.lua")):
        name = path.name.split(".")[0]
        if name in present:
            continue

        parent_name = path.parent.name
        item_start = container_named(xml, parent_name)
        if item_start is None:
            print(f"Warning: no '{parent_name}' container in the place for {path.name}; skipping")
            continue

        referent += 1
        source = path.read_text(encoding="utf-8")
        if "]]>" in source:
            raise SystemExit(f"{name}: source contains ']]>' and cannot be stored in CDATA")
        block = (
            f'        <Item class="{class_of(path)}" referent="{referent}">\n'
            f"          <Properties>\n"
            f'            <string name="Name">{name}</string>\n'
            f'            <{tag} name="Source"><![CDATA[{source}]]></{tag}>\n'
            f"          </Properties>\n"
            f"        </Item>\n"
        )
        end = close_of(xml, item_start)
        xml = xml[:end] + block + xml[end:]
        present.add(name)
        added.append(name)

    return xml, added


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--place", default=DEFAULT_PLACE)
    parser.add_argument("--check", action="store_true", help="report staleness instead of writing")
    parser.add_argument("--prune", action="store_true", help="remove place scripts that no longer exist in src/")
    args = parser.parse_args()

    place = ROOT / args.place
    if not place.is_file():
        print(f"Place file not found: {place}")
        return 2

    xml = place.read_text(encoding="utf-8")
    sources = script_sources()

    scripts = [i for i in parse_items(xml) if i.is_script and i.body is not None]
    present = {i.name for i in scripts}

    seen: set[str] = set()
    duplicates = sorted({i.name for i in scripts if i.name in seen or seen.add(i.name)})

    stale = sorted(
        i.name
        for i in scripts
        if i.name in sources and sources[i.name].strip() != i.body.strip()
    )
    absent = sorted(set(sources) - present)
    unknown = sorted(present - set(sources))

    if unknown:
        print(f"Warning: place has scripts with no file in src/: {', '.join(unknown)}")

    if args.check:
        problems = (
            stale
            + [f"{n} (not in the place at all)" for n in absent]
            + [f"{n} (duplicated in the place)" for n in duplicates]
            + [f"{n} (no longer exists in src/)" for n in unknown]
        )
        if problems:
            print(f"{args.place} is stale. Out of date: {', '.join(problems)}")
            print("Run: python scripts/sync_place.py")
            return 1
        print(f"{args.place} matches src/.")
        return 0

    xml, removed = remove_duplicate_scripts(xml)
    pruned: list[str] = []
    if args.prune and unknown:
        xml, pruned = remove_scripts_named(xml, set(unknown))

    # Re-parse: spans moved when the duplicates were cut.
    updated = []
    for item in sorted(
        (i for i in parse_items(xml) if i.is_script and i.body is not None),
        key=lambda i: i.start,
        reverse=True,
    ):
        source = sources.get(item.name)
        if source is None or source.strip() == item.body.strip():
            continue
        if "]]>" in source:
            raise SystemExit(f"{item.name}: source contains ']]>' and cannot be stored in CDATA")
        xml = xml[: item.body_start] + source + xml[item.body_end :]
        updated.append(item.name)

    present = {i.name for i in parse_items(xml) if i.is_script and i.body is not None}
    xml, added = add_missing_scripts(xml, present)

    if not updated and not added and not removed and not pruned:
        print(f"{args.place} already matches src/. Nothing to do.")
        return 0

    place.write_text(xml, encoding="utf-8")
    if removed:
        print(f"Removed {len(removed)} duplicate script(s): {', '.join(removed)}")
    if pruned:
        print(f"Pruned {len(pruned)} retired script(s): {', '.join(pruned)}")
    if updated:
        print(f"Updated {len(updated)} scripts in {args.place}: {', '.join(sorted(updated))}")
    if added:
        print(f"Added {len(added)} new scripts to {args.place}: {', '.join(added)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
