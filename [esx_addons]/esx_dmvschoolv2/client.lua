local currentSession = nil

RegisterCommand('spawndui', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)

    local propModel = `prop_laptop_lester`
    RequestModel(propModel)
    while not HasModelLoaded(propModel) do
        Wait(0)
    end

    local prop = CreateObject(propModel, coords.x + 1, coords.y + 1, coords.z, false, false, false)
    SetEntityHeading(prop, heading)
    FreezeEntityPosition(prop, true)

    local resourceName = GetCurrentResourceName()
    local page = 'progress'
    local duiUrl = 'https://cfx-nui-' .. resourceName .. '/web/dist/index.html?page=' .. page .. '&dui=yes'
    local duiWidth, duiHeight = 1920, 1080
    local dui = CreateDui(duiUrl, duiWidth, duiHeight)
    local duiHandle = GetDuiHandle(dui)

    local txd = CreateRuntimeTxd('duiTxd_' .. prop)
    local tx = CreateRuntimeTextureFromDuiHandle(txd, 'duiTex', duiHandle)
    AddReplaceTexture('prop_laptop_lester', 'prop_lester_screen', 'duiTxd_' .. prop, 'duiTex')

    local propCoords = GetEntityCoords(prop)
    local propHeading = GetEntityHeading(prop)
    local radians = math.rad(propHeading)
    local camX = propCoords.x + math.sin(radians) * 0.3
    local camY = propCoords.y - math.cos(radians) * 0.3
    local camZ = propCoords.z + 0.2

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(cam, camX, camY, camZ)
    PointCamAtCoord(cam, propCoords.x, propCoords.y, propCoords.z + 0.2)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    currentSession = {
        prop = prop,
        dui = dui,
        cam = cam,
        width = duiWidth,
        height = duiHeight,
        isActive = true,
        lastCursorX = 0,
        lastCursorY = 0
    }

    SetNuiFocus(true, false)

    CreateThread(function()
        while currentSession and currentSession.isActive do
            DisableAllControlActions(0)

            local screenWidth, screenHeight = GetActiveScreenResolution()
            local cursorX, cursorY = GetNuiCursorPosition()

            local duiX = math.floor((cursorX / screenWidth) * currentSession.width)
            local duiY = math.floor((cursorY / screenHeight) * currentSession.height)
            duiX = math.max(0, math.min(currentSession.width, duiX))
            duiY = math.max(0, math.min(currentSession.height, duiY))

            if duiX ~= currentSession.lastCursorX or duiY ~= currentSession.lastCursorY then
                SendDuiMouseMove(currentSession.dui, duiX, duiY)
                currentSession.lastCursorX = duiX
                currentSession.lastCursorY = duiY
            end

            if IsDisabledControlJustPressed(0, 24) then
                SendDuiMouseDown(currentSession.dui, "left")
            end
            if IsDisabledControlJustReleased(0, 24) then
                SendDuiMouseUp(currentSession.dui, "left")
            end

            if IsDisabledControlJustPressed(0, 25) then
                SendDuiMouseDown(currentSession.dui, "right")
            end
            if IsDisabledControlJustReleased(0, 25) then
                SendDuiMouseUp(currentSession.dui, "right")
            end

            if IsDisabledControlJustPressed(0, 241) then
                SendDuiMouseWheel(currentSession.dui, 100, 0)
            end
            if IsDisabledControlJustPressed(0, 242) then
                SendDuiMouseWheel(currentSession.dui, -100, 0)
            end

            Wait(0)
        end

        SetNuiFocus(false, false)
    end)
end, false)

RegisterCommand('dmvsdtui', function()
    SendNUIMessage({
        action = 'openPage',
        data = {
            page = 'studentdrivingtest'
        }
    })
    print('Opening Student Driving Test UI')
end, false)

RegisterNUICallback("ready", function(_, cb)
    cb({
        config = {
            licenses = {
                ['motorcycle'] = {
                    label = 'Motorcycle License',
                    price = 500,
                    category = 'A',
                    imageSrc = 'assets/motorcycle.png'
                },
                ['car'] = {
                    label = 'Car License',
                    price = 1500,
                    category = 'B',
                    imageSrc = 'assets/car.png'
                },
                ['truck'] = {
                    label = 'Truck License',
                    price = 2500,
                    category = 'C',
                    imageSrc = 'assets/truck.png'
                }
            },
            questions = {
                {
                    question = "Question 1?",
                    options = {"Option 1", "Option 2", "Option 3", "Option 4"},
                    selected = 0,
                    imageSrc = nil
                }
            },
            progressdata = {
                lessons = {
                    { label = "Lesson 1", completed = true },
                    { label = "Lesson 2", completed = true },
                },
                tests = {
                    { label = "Test 1", completed = false },
                    { label = "Test 2", completed = false }
                },
                progress = 50
            },
            licenseresult = {
                licensed = true,
                fullname = "John Doe",
                age = 25,
                category = "B",
                progress = 100
            },
            resourceName = GetCurrentResourceName(),
            studentDrivingTest = {
                maxMistakes = 5,
                currentObjective = "Wait for instructor",
                progress = 0,
                checkpointsLeft = 10,
                mistakes = 0
            }
        }
    })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName and currentSession then
        SetNuiFocus(false, false)
        currentSession.isActive = false

        if DoesEntityExist(currentSession.prop) then
            DeleteEntity(currentSession.prop)
        end
        DestroyDui(currentSession.dui)
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(currentSession.cam, false)

        currentSession = nil
    end
end)

RegisterCommand('killdmvdui', function()
    if currentSession then
        SetNuiFocus(false, false)
        currentSession.isActive = false

        if DoesEntityExist(currentSession.prop) then
            DeleteEntity(currentSession.prop)
        end
        DestroyDui(currentSession.dui)
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(currentSession.cam, false)

        currentSession = nil
    end
end, false)

RegisterCommand('dmvsdtstoptimer', function(source, args)
    SendNUIMessage({
        action = 'startTimer',
    })
    print('Timer started')
end, false)

RegisterCommand('dmvsdtstarttimer', function()
    SendNUIMessage({
        action = 'stopTimer'
    })
    print('Timer stopped')
end, false)
