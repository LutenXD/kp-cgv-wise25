import matplotlib.pyplot as plt
import networkx as nx

# Define the rooms
rooms = {
    "main_living_areas": [
        {"name": "Grand Foyer", "description": "The imposing entrance with a sweeping staircase, chandelier, and possibly a ghostly butler."},
        {"name": "Grand Hall/Ballroom", "description": "A vast, echoing space with a decaying dance floor, broken mirrors, and remnants of past celebrations."},
        {"name": "Library", "description": "Floor-to-ceiling bookshelves, hidden passages, and cursed tomes. A perfect place for puzzles or lore."},
        {"name": "Dining Room", "description": "A long table set for a meal that was never finished, with rotting food and spectral guests."}
    ],
    "private_quarters": [
        {"name": "Master Bedroom", "description": "Lavish but eerie, with a four-poster bed, a vanity mirror that shows reflections of the past, and a locked wardrobe."},
        {"name": "Children's Nursery", "description": "Creepy toys, a rocking chair that moves on its own, and drawings that hint at dark secrets."},
        {"name": "Servants Quarters", "description": "Cramped, dusty rooms with personal belongings left behind, and whispers of past injustices."}
    ],
    "utility_and_service_rooms": [
        {"name": "Kitchen/Pantry", "description": "Rusty knives, spoiled food, and the sound of pots clanging when no one is there."},
        {"name": "Laundry Room", "description": "Damp, moldy, and filled with the sound of a washing machine that never stops."},
        {"name": "Wine Cellar", "description": "Dark, cobwebbed, and filled with bottles of wine that may or may not be blood."}
    ],
    "mysterious_and_forbidden_areas": [
        {"name": "Secret Study", "description": "Hidden behind a bookshelf or painting, containing forbidden knowledge or a portal to another realm."},
        {"name": "Attic", "description": "Dusty, cluttered, and home to forgotten relics, old dolls, and perhaps a trapped spirit."},
        {"name": "Basement/Dungeon", "description": "A place of torment, with chains on the walls, strange symbols, and something lurking in the dark."},
        {"name": "Chapel/Crypt", "description": "A place of worship or burial, with stained glass windows, coffins, and restless spirits."}
    ],
    "outdoor_and_connecting_spaces": [
        {"name": "Conservatory/Greenhouse", "description": "Overgrown with deadly plants, or home to a ghostly gardener."},
        {"name": "Courtyard/Garden", "description": "Statues that seem to watch you, a dried-up fountain, and graves hidden among the roses."},
        {"name": "Hallways and Staircases", "description": "Long, winding corridors with doors that lead nowhere, or staircases that change direction."}
    ],
    "unique_and_thematic_rooms": [
        {"name": "Music Room", "description": "A piano that plays by itself, sheet music with ominous notes, and the sound of phantom singing."},
        {"name": "Art Gallery", "description": "Portraits with eyes that follow you, or paintings that change when you're not looking."},
        {"name": "Bathroom", "description": "A clawfoot tub filled with rusty water, a mirror that shows a distorted reflection, and the sound of dripping."}
    ]
}

# Flatten the rooms into a single list
all_rooms = [room for rooms_list in rooms.values() for room in rooms_list]

# Create a graph
G = nx.Graph()

# Add nodes (rooms) to the graph
for i, room in enumerate(all_rooms):
    G.add_node(i, name=room["name"], description=room["description"])

# Add edges between nodes (assuming a simple grid structure)
for i in range(len(all_rooms)):
    if i > 0:
        G.add_edge(i, i-1)
    if i < len(all_rooms) - 1:
        G.add_edge(i, i+1)

# Position the nodes
pos = nx.spring_layout(G)

# Draw the nodes
nx.draw_networkx_nodes(G, pos, node_size=500, node_color='lightblue')

# Draw the edges
nx.draw_networkx_edges(G, pos, width=2, edge_color='gray')

# Draw the labels
labels = {i: all_rooms[i]["name"] for i in range(len(all_rooms))}
nx.draw_networkx_labels(G, pos, labels=labels, font_size=10)

# Show the plot
plt.axis('off')
plt.show()