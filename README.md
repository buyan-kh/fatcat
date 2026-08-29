# FatCat

FatCat is a visual, screen-aware native macOS interface for Hermes. It gives
Hermes a face, eyes on the screen, and presence. Chat is a polished Hermes ACP
session; the avatar follows Hermes’s real state. FatCat is not a second
intelligence, IDE, or browser agent.

Voice is part of the product definition and is not in this build yet.

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
