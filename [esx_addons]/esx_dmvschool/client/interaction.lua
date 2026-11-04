-- SPDX-License-Identifier: GPL-3.0-only
-- Copyright (C) 2022-2026 ESX Framework
-- Persistent proximity prompt. The shared ESX TextUI has no owner/token API;
-- this adapter only hides prompts it has shown and never refreshes per frame.
ESXDMVInteraction = {}

local generation, shown, pendingHide, pendingShow, disposed = 0, false, false, false, false
local currentText, shownAt, hiddenAt
local FADE_SAFETY = 350 -- esx_textui assigns its current element after 300 ms.

local function isCallable(value)
  if type(value) == 'function' then
    return true
  end
  if type(value) ~= 'table' then
    return false
  end
  local meta = getmetatable(value)
  return type(meta) == 'table' and type(meta.__call) == 'function'
end

local function available()
  return GetResourceState('esx_textui') == 'started'
    and type(ESX) == 'table'
    and isCallable(ESX.TextUI)
    and isCallable(ESX.HideUI)
end

local function clear()
  shown, pendingHide, pendingShow, currentText, shownAt = false, false, false, nil, nil
end

local function hideNow(version)
  if version ~= generation or not shown or not pendingHide then
    return false
  end
  clear()
  if not available() then
    return false
  end
  hiddenAt = GetGameTimer()
  return pcall(ESX.HideUI)
end

local function showNow(text)
  pendingShow = false
  if not available() then
    clear()
    return false
  end
  local ok = pcall(ESX.TextUI, text, 'info')
  if not ok then
    clear()
    return false
  end
  shown, currentText, shownAt = true, text, GetGameTimer()
  return true
end

---@param title string Localized school title without the interaction key.
---@return boolean shown
function ESXDMVInteraction.Show(title)
  if disposed then
    return false
  end
  if not available() then
    generation = generation + 1
    clear()
    return false
  end
  if type(title) ~= 'string' or title == '' then
    return false
  end
  local text = '[E] ' .. title
  if pendingShow and currentText == text then
    return true
  end
  -- Cancel a pending departure hide even if the same prompt is requested.
  -- No new NUI show is needed while the existing message remains visible.
  if shown and currentText == text then
    if pendingHide then
      generation, pendingHide = generation + 1, false
    end
    return true
  end
  generation, pendingHide, pendingShow = generation + 1, false, false
  local version = generation
  local remaining = hiddenAt and math.max(0, FADE_SAFETY - (GetGameTimer() - hiddenAt)) or 0
  if remaining == 0 then
    return showNow(text)
  end
  -- A preceding hide has its own 300 ms web animation. Let it finish before
  -- showing again so its stale completion cannot hide this new message.
  pendingShow, currentText = true, text
  SetTimeout(remaining, function()
    if disposed or generation ~= version or not pendingShow then
      return
    end
    showNow(text)
  end)
  return true
end

---@param force? boolean Final resource teardown only; permanently disposes this adapter.
---@return boolean handled
function ESXDMVInteraction.Hide(force)
  if disposed then
    return false
  end
  if force then
    disposed = true
  end
  if pendingShow then
    generation = generation + 1
    clear()
    return true
  end
  if not shown then
    return false
  end
  if pendingHide and not force then
    return true
  end
  generation, pendingHide = generation + 1, true
  local version = generation
  local remaining = math.max(0, FADE_SAFETY - (GetGameTimer() - (shownAt or 0)))
  if remaining == 0 or not available() then
    return hideNow(version)
  end

  if force then
    -- A core-owned timer can finish after this resource stops. TextUI does not
    -- provide ownership tokens for prompts shown by different resources.
    local coreTimeout, coreHide = ESX.SetTimeout, ESX.HideUI
    clear()
    if isCallable(coreTimeout) then
      local ok = pcall(coreTimeout, remaining, coreHide)
      if ok then
        return true
      end
    end
    -- Hide directly when a persistent core timer is unavailable.
    return pcall(coreHide)
  end

  SetTimeout(remaining, function()
    -- A re-entry/new text invalidates this callback before it can hide.
    if disposed or generation ~= version then
      return
    end
    hideNow(version)
  end)
  return true
end
