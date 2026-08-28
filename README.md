# FatCat

Native macOS chat companion. FatCat uses SwiftUI/AppKit and a bundled FatCat
Agent over a private Unix domain socket; no Electron or WKWebView is required.

## Run

```bash
npm install
./scripts/run-peppa-macos.sh
```

Text conversations persist locally and resume their Hermes ACP session after a
relaunch. A working Hermes provider is required for real responses.

## Verify

```bash
swift build --package-path macos/PeppaAnywhere
swift test --package-path macos/PeppaAnywhere
PYTHONPATH=agent python3 -m unittest discover -s agent/tests
```
