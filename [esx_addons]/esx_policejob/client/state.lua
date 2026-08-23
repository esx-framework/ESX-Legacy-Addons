POLICE = POLICE or {}

POLICE.CurrentActionData = {}
POLICE.handcuffTimer     = { active = false, task = nil }
POLICE.dragStatus        = { isDragged = false, CopId = nil }
POLICE.blipsCops         = {}
POLICE.currentTask       = {}

POLICE.HasAlreadyEnteredMarker = false
POLICE.isDead           = false
POLICE.isHandcuffed     = false
POLICE.hasAlreadyJoined = false
POLICE.playerInService  = false

POLICE.LastStation, POLICE.LastPart, POLICE.LastPartNum = nil, nil, nil
POLICE.LastEntity       = nil
POLICE.CurrentAction    = nil
POLICE.CurrentActionMsg = nil

POLICE.ARREST_DICT, POLICE.ARREST_ANIM = 'mp_arresting', 'idle'
POLICE.isInShopMenu = false
