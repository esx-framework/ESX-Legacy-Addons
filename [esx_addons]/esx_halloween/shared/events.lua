---Event name constants for client-server communication
---Centralizes all event names to prevent typos and improve maintainability
---@class Events
Events = {
    -- Ghost Mode Events
    REQUEST_GHOST_MODE = 'esx_halloween:requestGhostMode',
    EXIT_GHOST_MODE = 'esx_halloween:exitGhostMode',
    TRIGGER_SCARE = 'esx_halloween:triggerScare',
    SHOW_GHOST_CHOICE = 'esx_halloween:showGhostChoice',
    GHOST_MODE_RESPONSE = 'esx_halloween:ghostModeResponse',
    SYNC_GHOST_STATE = 'esx_halloween:syncGhostState',
    RECEIVE_SCARE = 'esx_halloween:receiveScare',

    -- Trick-or-Treat Events
    ROUND_START = 'esx_halloween:trickOrTreatRoundStart',
    ROUND_END = 'esx_halloween:trickOrTreatRoundEnd',
    HOUSE_COLLECT_REQUEST = 'esx_halloween:houseCollectRequest',
    HOUSE_COLLECT_RESPONSE = 'esx_halloween:houseCollectResponse',
    HOUSE_STATE_SYNC = 'esx_halloween:houseStateSync',
    TRIGGER_TRICK = 'esx_halloween:triggerTrick'
}
