# GMod Web Browser Panel 🌐

An interactive web browser entity for Garry's Mod that allows players to view and interact with websites directly in-game. ✨

## Overview

This addon enables players to spawn interactive web panels in the Garry's Mod world. Players can browse websites, click links, scroll through pages, and interact with web content while staying immersed in the game environment.

## Usage 📋

### Spawning a Panel

1. Open the Spawn Menu (Q by default)
2. Navigate to Entties -> Fun & Games
3. Click on "Web Browser Panel"
4. Place the panel in the world

### Configuration Options

Hold c and right-click the panel and access the context menu to configure:

- **URL**: Change the website being displayed
- **HTML Size**: Adjust the resolution (higher = more detail but may impact performance)
- **Screen Model**: Select a different model for the panel
- **Angle**: Rotate the display (0-360 degrees)
- **Max Distance**: Set the maximum distance from which the panel is visible/interactive

### How It Works

The entity creates a DHTML panel on the client side and renders it onto a 3D surface in the game world. User inputs are captured and translated into JavaScript events that are injected into the webpage, simulating normal browser interactions.

## TODO 📝

- [ ] Synchronize panel state between players (shared browsing)
- [ ] Maybe a mouse lock for 3D games? Or a way to show the fullscreen, both seems bleh
- [-] Add better support for drag and hover operations, still needs some tweaks
- [x] Improve input support for text fields and form elements
- [x] A lock setting to prevent any input onto the screen
- [x] Spatial audio, no idea on how that will work

## Credits 👏

- IMGUI library by wyozi
- Developed by Meowlan

## License 📄

MIT License
