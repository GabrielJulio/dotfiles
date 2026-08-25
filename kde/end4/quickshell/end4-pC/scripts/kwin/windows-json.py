#!/usr/bin/env python3

import json
import subprocess


def run(*args):
    result = subprocess.run(
        args,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    return result.stdout.strip()


def parse_bool(value):
    return value.strip().lower() == "true"


def parse_int(value, default=0):
    try:
        return int(value.strip())
    except (TypeError, ValueError):
        return default


def window_info(window_id):
    output = run(
        "qdbus6",
        "org.kde.KWin",
        "/KWin",
        "org.kde.KWin.getWindowInfo",
        window_id,
    )

    info = {}

    for line in output.splitlines():
        if ":" not in line:
            continue

        key, value = line.split(":", 1)
        info[key.strip()] = value.strip()

    return info


desktop_payload = run(
    "busctl",
    "--user",
    "--json=short",
    "get-property",
    "org.kde.KWin",
    "/VirtualDesktopManager",
    "org.kde.KWin.VirtualDesktopManager",
    "desktops",
)

desktop_index = {}

try:
    rows = json.loads(desktop_payload).get("data", [])

    for row in rows:
        position = int(row[0])
        uuid = str(row[1])
        desktop_index[uuid] = position + 1
except Exception:
    pass


active_id = run(
    "kdotool",
    "getactivewindow",
    "getwindowid",
)


ids_output = run(
    "kdotool",
    "search",
    ".*",
    "getwindowid",
    "%@",
)

window_ids = [
    line.strip()
    for line in ids_output.splitlines()
    if line.strip()
]


windows = []

for window_id in window_ids:
    info = window_info(window_id)

    if not info:
        continue

    # Don't expose Plasma panels, desktop surfaces, etc.
    if parse_bool(info.get("skipTaskbar", "false")):
        continue

    desktop_file = info.get("desktopFile", "")
    resource_class = info.get("resourceClass", "")
    resource_name = info.get("resourceName", "")

    app_id = (
        desktop_file
        or resource_class
        or resource_name
    )

    if not app_id:
        continue

    raw_desktops = info.get("desktops", "")

    desktop_uuids = [
        value.strip()
        for value in raw_desktops.split(",")
        if value.strip()
    ]

    workspace_uuid = (
        desktop_uuids[0]
        if desktop_uuids
        else ""
    )

    workspace_id = desktop_index.get(
        workspace_uuid,
        0,
    )

    windows.append({
        "id": window_id,

        "title": info.get("caption", ""),

        "appId": app_id,
        "appName": app_id,
        "address": window_id,
        "class": app_id,

        "desktopFile": desktop_file,
        "resourceClass": resource_class,
        "resourceName": resource_name,

        "pid": parse_int(info.get("pid")),

        "workspaceId": workspace_uuid,
        "workspaceNumber": workspace_id,
        "workspaceUuid": workspace_uuid,
        "workspaceIds": desktop_uuids,

        "focused": window_id == active_id,
        "isFocused": window_id == active_id,

        "fullscreen": parse_bool(
            info.get("fullscreen", "false")
        ),

        "minimized": parse_bool(
            info.get("minimized", "false")
        ),

        "skipTaskbar": parse_bool(
            info.get("skipTaskbar", "false")
        ),

        "x": parse_int(info.get("x")),
        "y": parse_int(info.get("y")),
        "width": parse_int(info.get("width")),
        "height": parse_int(info.get("height")),
    })


print(json.dumps(windows, separators=(",", ":")))

