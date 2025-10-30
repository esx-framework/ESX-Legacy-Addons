---Main ghost mode configuration
---@class GhostConfig
---@field enabled boolean Enable/disable ghost mode feature
---@field spawnChance number Percentage chance (0-100) to show ghost choice on death
---@field pedModel string Ped model hash for ghost appearance (e.g., 'u_m_y_zombie_01')
---@field maxDuration number Maximum ghost mode duration in milliseconds
---@field exitKeybind string Keybind to exit ghost mode manually
---@field visibility GhostVisibilityConfig Ghost visibility settings
---@field movement GhostMovementConfig Ghost movement settings
---@field abilities GhostAbilitiesConfig Ghost abilities configuration
---@field security GhostSecurityConfig Anti-abuse and security settings

---Ghost visibility configuration
---@class GhostVisibilityConfig
---@field range number Distance in meters where ghosts are visible to other players
---@field alpha number Transparency level (0-255, where 255 is fully opaque)

---Ghost movement configuration
---@class GhostMovementConfig
---@field speedMultiplier number Speed multiplier for ghost movement (1.0 = normal speed)

---@class GhostAbilitiesConfig
---@field scare GhostScareConfig Scare ability configuration

---@class GhostScareConfig
---@field enabled boolean Whether scare ability is enabled
---@field cooldown number Cooldown duration in milliseconds between scare uses
---@field range number Maximum distance in meters to scare targets
---@field keybind string Keybind to trigger scare ability
---@field effects GhostScareEffects Visual and audio effects configuration

---@class GhostScareEffects
---@field screenShake boolean Enable screen shake effect on scare
---@field sound boolean Enable sound effect on scare
---@field soundVolume number Sound volume (0.0 - 1.0)
---@field duration number Effect duration in milliseconds

---Security and anti-abuse configuration
---@class GhostSecurityConfig
---@field ghostRequestCooldown number Milliseconds cooldown between ghost mode requests per player
---@field maxConcurrentGhosts number Maximum number of concurrent ghosts allowed on server
---@field deathCooldown number Milliseconds delay after death before showing ghost choice
---@field requestTimeout number Milliseconds to wait for server response before timeout

---Client-side ghost state tracking
---@class GhostState
---@field isGhost boolean Whether player is currently in ghost mode
---@field lastScareTime number Last time scare ability was used (GetGameTimer)
---@field activatedByDeath boolean Whether ghost mode was activated from death or admin command
---@field startTime number Ghost mode start time (GetGameTimer)
---@field pendingRequest boolean Whether a ghost mode request is awaiting server response

---ESX player object structure
---@class ESXPlayer
---@field source number Player server ID
---@field identifier string Player unique identifier
---@field name string Player display name
---@field group string Player permission group (user, admin, superadmin, etc.)

---ESX UI theme colors from server convars
---@class ThemeColors
---@field primary string Primary theme color (hex format)
---@field secondary string Secondary theme color (hex format)
---@field background string Background color (hex format)
---@field accent string Accent color (hex format)
---@field logoUrl string Server logo URL

---Notification display configuration
---@class NotificationData
---@field size "small"|"large" Notification card size (large only supports bottom-center)
---@field position "top-left"|"top-right"|"top-center"|"bottom-center" Screen position for notification
---@field header string Notification title text (will be sanitized)
---@field description string Notification body text (will be sanitized)
---@field duration number|nil Duration in milliseconds (default: 5000, min: 1000, max: 30000)

---Trick-or-Treat configuration
---@class TrickOrTreatConfig
---@field enabled boolean Enable/disable trick-or-treat feature
---@field roundFrequencyMinutes number Minutes between round starts
---@field doorsPerRound number Number of random houses per round
---@field candyPerDoor number Candy amount per door collection
---@field notifications table Notification duration settings
---@field blips table Blip color and sprite settings
---@field rewards table Reward probability and items
---@field interaction table Interaction distance and keybind
---@field houses table Array of house location data

---Trick-or-Treat house location data
---@class HouseLocation
---@field coords vector3 House position coordinates
---@field heading number NPC heading/direction
---@field pedModel string Ped model for NPC at house

---Trick-or-Treat state tracking (client)
---@class TrickOrTreatState
---@field hudVisible boolean Whether HUD is currently showing
---@field currentHouses number Houses collected in current round
---@field totalHouses number Total houses available in round
---@field timeRemaining number Time left in round (ms)
---@field rewardVisible boolean Whether reward popup is showing
---@field rewardType "treat"|"trick" Type of reward (treat or trick)
---@field rewardItem string Item name for reward
---@field rewardAmount number Item amount for reward
