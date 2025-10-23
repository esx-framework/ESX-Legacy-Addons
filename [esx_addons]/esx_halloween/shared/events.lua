---Event name constants for client-server communication
---Centralizes all event names to prevent typos and improve maintainability
---@class Events
Events = {
    -- Client to Server
    REQUEST_GHOST_MODE = 'esx_halloween:requestGhostMode',
    EXIT_GHOST_MODE = 'esx_halloween:exitGhostMode',
    TRIGGER_SCARE = 'esx_halloween:triggerScare',

    -- Server to Client
    SHOW_GHOST_CHOICE = 'esx_halloween:showGhostChoice',
    GHOST_MODE_RESPONSE = 'esx_halloween:ghostModeResponse',
    SYNC_GHOST_STATE = 'esx_halloween:syncGhostState',
    RECEIVE_SCARE = 'esx_halloween:receiveScare'
}
