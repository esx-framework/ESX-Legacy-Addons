# Custom Handcuff Prop

## Files
- `handcuffs.ydr` - 3D model file
- `types1.ytyp` - Type definition file

## Installation

The prop is automatically loaded when you start `esx_policejob`. The required configuration is already included in `fxmanifest.lua`.

## Usage Example

Spawn the handcuff prop in your script:

```lua
local handcuffModel = 'handcuffs'
RequestModel(handcuffModel)
while not HasModelLoaded(handcuffModel) do
    Wait(0)
end

local handcuffProp = CreateObject(GetHashKey(handcuffModel), x, y, z, true, true, true)
-- Attach to player or place in world
AttachEntityToEntity(handcuffProp, playerPed, GetPedBoneIndex(playerPed, 60309), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
```

## Model Name
`handcuffs`
