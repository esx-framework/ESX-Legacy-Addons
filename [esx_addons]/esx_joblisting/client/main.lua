local menuIsShowed, isNear, TextUIdrawing = false, false, false

function ShowJobListingMenu()
  menuIsShowed = true
  ESX.TriggerServerCallback('esx_joblisting:getJobsList', function(jobs)
    local elements = {{unselectable = "true", title = TranslateCap('job_center'), icon = "fas fa-briefcase"}}

    for i = 1, #(jobs) do
      elements[#elements + 1] = {title = jobs[i].label, name = jobs[i].name}
    end

    ESX.OpenContext("right", elements, function(menu, SelectJob)
      TriggerServerEvent('esx_joblisting:setJob', SelectJob.name)
      ESX.CloseContext()
      ESX.ShowNotification(TranslateCap('new_job', SelectJob.title), "success")
      menuIsShowed = false
      TextUIdrawing = false
    end, function()
      menuIsShowed = false
      TextUIdrawing = false
    end)
  end)
end

-- Activate menu when player is inside marker, and draw markers
CreateThread(function()
  while true do
    local Sleep = 1000

    local coords = GetEntityCoords(ESX.PlayerData.ped)
    local isInMarker = false

    for i = 1, #Config.Zones, 1 do
      local distance = #(coords - Config.Zones[i])

      if distance < Config.DrawDistance then
        Sleep = 0
        DrawMarker(Config.MarkerType, Config.Zones[i].x, Config.Zones[i].y, Config.Zones[i].z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, Config.ZoneSize.x, Config.ZoneSize.y, Config.ZoneSize.z,
        Config.MarkerColor.r, Config.MarkerColor.g, Config.MarkerColor.b, 100, false, true, 2, false, false, false, false)

        isNear = distance < (Config.ZoneSize.x / 2)
        isInMarker = true

        if isNear and not TextUIdrawing then
          ESX.TextUI(TranslateCap('access_job_center', ESX.GetInteractKey()))
          TextUIdrawing = true
        else
          if not isNear and TextUIdrawing then
            ESX.HideUI()
            TextUIdrawing = false
          end
        end
      end
    end

    if not isInMarker and TextUIdrawing then
      ESX.HideUI()
      TextUIdrawing = false
    end

    Wait(Sleep)
  end
end)

-- Create blips
if Config.Blip.Enabled then
  CreateThread(function()
    for i = 1, #Config.Zones, 1 do
      local blip = AddBlipForCoord(Config.Zones[i])

      SetBlipSprite(blip, Config.Blip.Sprite)
      SetBlipDisplay(blip, Config.Blip.Display)
      SetBlipScale(blip, Config.Blip.Scale)
      SetBlipColour(blip, Config.Blip.Colour)
      SetBlipAsShortRange(blip, Config.Blip.ShortRange)

      BeginTextCommandSetBlipName("STRING")
      AddTextComponentSubstringPlayerName(TranslateCap('blip_text'))
      EndTextCommandSetBlipName(blip)
    end
  end)
end

ESX.RegisterInteraction("open_joblisting", function()
  ShowJobListingMenu()
end, function()
  return isNear and not menuIsShowed
end)