#!/bin/bash
# Build FloatingTimer
cd "$(dirname "$0")"
TIMER_DIR="$(dirname "$PWD")"

swiftc -o FloatingTimer main.swift -framework Cocoa -framework SwiftUI

# Copy to app bundle
cp FloatingTimer "$TIMER_DIR/FloatingTimer.app/Contents/MacOS/"

# Also copy to ~/bin if it exists
if [ -d ~/bin ]; then
    cp FloatingTimer ~/bin/FloatingTimer
fi

# Clean up local build artifact
rm -f FloatingTimer

echo "Built FloatingTimer.app"
