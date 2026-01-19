#!/bin/bash

# WindowDock Cleanup Script
# Removes broken WindowDock helper icons from dock

echo "Cleaning up WindowDock helper icons from dock..."

# Delete helper app files
rm -rf ~/Library/Application\ Support/WindowDock/Helpers/*.app
echo "✓ Deleted helper app files"

# Restart Dock - broken icons will show with question mark
# You can then right-click and remove them
killall Dock
echo "✓ Dock restarted"

echo ""
echo "Done! If you see icons with question marks, right-click them and select 'Remove from Dock'"
