![Steam Subscriptions](https://img.shields.io/steam/subscriptions/3443791959?link=https%3A%2F%2Fsteamcommunity.com%2Fsharedfiles%2Ffiledetails%2F%3Fid%3D3443791959)


# GMod Web Browser Panel

An interactive web browser for Garry's Mod that allows players to view and interact with websites directly in-game.
This addon enables players to spawn interactive web panels inside of Gmod. Players can browse websites, click links, scroll through pages, and interact with web content while staying immersed in the game environment.

## Usage

### Spawning a Panel

1. Open the Spawn Menu (Q by default)
2. Navigate to Entties -> Fun & Games
3. Click on "Web Browser Panel"

### Configuration Options

<img width="320" height="400" alt="wbui settings" src="https://github.com/user-attachments/assets/a15b704d-816e-4a19-8957-095ce819737d" />

Hold c and right-click the panel and access the context menu to configure:

- **URL**: Change the website being displayed
- **HTML Size**: Adjust the resolution (higher = more detail but may impact performance)
- **Screen Model**: Select a different model for the panel
- **Angle**: Rotate the display (0-360 degrees)
- **Max Distance**: Set the maximum distance from which the panel is visible/interactive

### How It Works

The entity creates a DHTML panel on the client and renders it onto a 3D surface in the game world. User inputs are captured and translated into JavaScript events that are injected into the webpage, simulating normal browser interactions.

## TODO

- [ ] Synchronize panel state between players (shared browsing)
- [ ] Maybe a mouse lock for 3D games? Or a way to show the fullscreen, both seems bleh
- [ ] Add better support for drag and hover operations, still needs some tweaks
- [x] Improve input support for text fields and form elements
- [x] A lock setting to prevent any input onto the screen
- [x] Spatial audio, no idea on how that will work

## Credits 👏

- IMGUI library by wyozi
- Help from [Andreweathan](https://steamcommunity.com/id/andreweathan/)

## License 

MIT License
