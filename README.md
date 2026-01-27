# kp-cgv-wise25

## Build rooms

1. Create room
    - You can use the files in assets/rooms/*.tscn as sample
    - maintain the file structure, wall naming and room tile size

2. Write room data into data/room_assets.json
    
    example:
    ```
     {
      "name": "art_gallery",    // name of the room
      "width": 2,              // tile size tile 10x10m
      "length": 1,
      "doors": {
        "north": [],
        "east": [0],            // walls that should have a door if a side has multiple doors you can select the wall by the index
        "south": [0],           // of the side e.g.: wall 0 and 2 on the west side => "west": [0,2]
        "west": [0]
      }
    }
    ```
3. run scripts/room_layout_mamager.gd
    - the game will use the generated rooms for the game