import AppKit

// Asset-generation mode: render app icon + screenshots to disk and exit.
// Used by build-tooling to produce App Store materials without launching
// the full menu bar UI.
if CommandLine.arguments.contains("--generate-assets") {
    let outputRoot: String
    if let i = CommandLine.arguments.firstIndex(of: "--out"),
       i + 1 < CommandLine.arguments.count {
        outputRoot = CommandLine.arguments[i + 1]
    } else {
        outputRoot = FileManager.default.currentDirectoryPath
    }
    AssetGenerator.run(outputRoot: outputRoot)
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
