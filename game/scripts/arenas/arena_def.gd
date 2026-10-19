@tool
class_name ArenaDef
extends Resource
## Visual + gameplay identity of one arena. Loaded from game/resources/arenas/*.tres.

@export var id: String = "arena"
@export var display_name: String = "ARENA"
@export var subtitle: String = ""
@export var description: String = ""
@export var hazard: String = "none"    ## none | vent | orbs

## Palette
@export var bg_top: Color = Color("0a0a1e")
@export var bg_bottom: Color = Color("16062a")
@export var floor_color: Color = Color("0d0d1f")
@export var grid_color: Color = Color("ff3cac")
@export var accent: Color = Color("2ee9f7")
@export var glow_color: Color = Color("8a5cff")
@export var silhouette_color: Color = Color("121230")
