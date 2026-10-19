@tool
class_name FighterStats
extends Resource
## Tunable definition of one fighter. Loaded from game/resources/fighters/*.tres.
## Every fighter has a distinct gameplay identity, not just a color.

@export var id: String = "fighter"
@export var display_name: String = "FIGHTER"
@export var tagline: String = ""
@export var bio: String = ""
@export var ability_name: String = ""
@export var ability_desc: String = ""
@export var stance: String = "balanced"

## Palette
@export var primary: Color = Color.WHITE
@export var secondary: Color = Color.GRAY
@export var accent: Color = Color.WHITE

## Pros/cons shown on the select screen.
@export var pros: PackedStringArray = []
@export var cons: PackedStringArray = []

## Survival / movement
@export var max_hp: int = 100
@export var move_speed: float = 300.0
@export var accel: float = 2600.0
@export var air_control: float = 0.65
@export var jump_velocity: float = -760.0
@export var gravity_scale: float = 1.0

## Light attack (J)
@export var light_damage: int = 7
@export var light_startup: float = 0.09
@export var light_active: float = 0.07
@export var light_recovery: float = 0.17
@export var light_range: float = 68.0
@export var light_knockback: float = 340.0
@export var light_launch: float = 90.0

## Heavy attack (K)
@export var heavy_damage: int = 12
@export var heavy_startup: float = 0.21
@export var heavy_active: float = 0.09
@export var heavy_recovery: float = 0.30
@export var heavy_range: float = 80.0
@export var heavy_knockback: float = 560.0
@export var heavy_launch: float = 280.0

## YEET special (L)
@export var yeet_damage: int = 28
@export var yeet_cooldown: float = 8.0
@export var yeet_windup: float = 0.42
@export var yeet_active: float = 0.14
@export var yeet_recovery: float = 0.45
@export var yeet_range: float = 106.0
@export var yeet_knockback: float = 980.0
@export var yeet_launch: float = 430.0

## Dash (Shift)
@export var dash_speed: float = 780.0
@export var dash_time: float = 0.16
@export var dash_cooldown: float = 1.4
@export var dash_invuln: float = 0.10

## Defense traits
@export var damage_taken_mult: float = 1.0
@export var knockback_taken_mult: float = 1.0
@export var super_armor: bool = false        ## light/heavy attacks are not interrupted
@export var crit_chance: float = 0.0         ## CHAOS
@export var crit_mult: float = 1.8
@export var parry: bool = false              ## GLITCH guard parry window
@export var parry_window: float = 0.16
@export var guard_reduction: float = 0.75    ## fraction of incoming damage negated while guarding

## Body proportions for the procedural artist (0 slim, 1 heavy, 2 floaty, 3 wild, 4 bulky, 5 tech).
@export var body_type: int = 0

func stat_speed() -> float:
	return clampf(move_speed / 400.0, 0.0, 1.0)

func stat_power() -> float:
	return clampf((light_damage + heavy_damage + yeet_damage) / 60.0, 0.0, 1.0)

func stat_toughness() -> float:
	return clampf(max_hp / 150.0, 0.0, 1.0)

func stat_mobility() -> float:
	return clampf((move_speed / 400.0) * 0.5 + ((1.8 - dash_cooldown) / 1.2) * 0.5, 0.0, 1.0)

func stat_technique() -> float:
	var t := 0.5
	if parry: t += 0.35
	if super_armor: t += 0.15
	if crit_chance > 0.0: t += 0.2
	return clampf(t, 0.0, 1.0)
