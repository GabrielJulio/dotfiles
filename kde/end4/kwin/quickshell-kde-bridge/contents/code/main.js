console.info("Quickshell KDE Bridge script starting...");
function updateWindows() {
    let wins = workspace.stackingOrder;
    let result = [];
    for (let i = 0; i < wins.length; ++i) {
        let w = wins[i];
        if (w.normalWindow) {
            let desktopId = 0;
            if (w.desktops && w.desktops.length > 0) {
                // In KWin 6, desktop might have an x11DesktopNumber or similar
                // We'll just grab the id if it has one, or assume desktop sequence
                desktopId = w.desktops[0].x11DesktopNumber || 1;
            }
            result.push({
                title: w.caption,
                class: w.resourceClass,
                workspace: { id: desktopId },
                at: [w.frameGeometry ? w.frameGeometry.x : 0, w.frameGeometry ? w.frameGeometry.y : 0],
                size: [w.frameGeometry ? w.frameGeometry.width : 0, w.frameGeometry ? w.frameGeometry.height : 0],
                internalId: w.internalId.toString(),
                floating: !w.tile,
                fullscreen: w.fullScreen,
                xwayland: w.xwayland
            });
        }
    }
    callDBus("org.kde.qs", "/bridge", "org.kde.qs.bridge", "updateWindows", JSON.stringify(result));
}

workspace.windowAdded.connect((w) => {
    try { w.frameGeometryChanged.connect(updateWindows); } catch(e) {}
    try { w.desktopsChanged.connect(updateWindows); } catch(e) {}
    try { w.desktopChanged.connect(updateWindows); } catch(e) {}
    updateWindows();
});
workspace.windowRemoved.connect(updateWindows);
workspace.windowActivated.connect(updateWindows);
try { workspace.currentDesktopChanged.connect(updateWindows); } catch(e) {}

// Initial connect to existing windows
let wins = workspace.stackingOrder;
for (let i = 0; i < wins.length; ++i) {
    let w = wins[i];
    try { w.frameGeometryChanged.connect(updateWindows); } catch(e) {}
    try { w.desktopsChanged.connect(updateWindows); } catch(e) {}
    try { w.desktopChanged.connect(updateWindows); } catch(e) {}
}

// Initial update
updateWindows();

// Initial update
updateWindows();

// END4_WINDOW_FILTER
function end4ApplyWindowFilter(w) {
    if (!w) return;
    const cls = String(w.resourceClass || "").toLowerCase();
    const name = String(w.resourceName || "").toLowerCase();
    if (cls === "quickshell" || name === "quickshell" || cls === "xwaylandvideobridge" || name === "xwaylandvideobridge") {
        w.skipSwitcher = true;
    }
}

workspace.stackingOrder.forEach(end4ApplyWindowFilter);
workspace.windowAdded.connect(function(w) {
    end4ApplyWindowFilter(w);
    try {
        w.windowClassChanged.connect(function() { end4ApplyWindowFilter(w); });
    } catch (e) {}
});
// END4_WINDOW_FILTER_END
