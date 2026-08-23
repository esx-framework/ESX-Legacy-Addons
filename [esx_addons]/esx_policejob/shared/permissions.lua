-- Here you can set permissions for each rank of the "police" profession
-- The available permissions are: canCuff, canSearch, canFine, canJail, canOpenBossMenu
-- true means the rank has permission, false means it doesn't

return {
  jobs = {
    police = {
      grades = {
        [0] = { label = 'Cadet',      canCuff = true, canSearch = true, canFine = false, canJail = false, canOpenBossMenu = false },
        [1] = { label = 'Officer',    canCuff = true, canSearch = true, canFine = true,  canJail = false, canOpenBossMenu = false },
        [2] = { label = 'Sergeant',   canCuff = true, canSearch = true, canFine = true,  canJail = true,  canOpenBossMenu = false },
        [3] = { label = 'Lieutenant', canCuff = true, canSearch = true, canFine = true,  canJail = true,  canOpenBossMenu = false },
        [4] = { label = 'Chief',      canCuff = true, canSearch = true, canFine = true,  canJail = true,  canOpenBossMenu = true  },
      }
    }
  }
}
