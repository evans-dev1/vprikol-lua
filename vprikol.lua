script_name('VPrikol')
script_version('1.0.2')

local imgui = require('mimgui')
local ffi = require('ffi')
local effil = require('effil')
local vkeys = require('vkeys')
local dlstatus = require('moonloader').download_status
local encoding = require('encoding')
local faicons = require('fAwesome6')
encoding.default = 'CP1251'
u8 = encoding.UTF8

function table.assign(target, def, deep)
    for k, v in pairs(def) do
        if target[k] == nil then
            if type(v) == 'table' then
                target[k] = {}
                table.assign(target[k], v)
            else  
                target[k] = v
            end
        elseif deep and type(v) == 'table' and type(target[k]) == 'table' then 
            table.assign(target[k], v, deep)
        end
    end 
    return target
end
 
function json()
    local list = {}

    function list:load(array)
        createDirectory(getWorkingDirectory() .. '/vprikol')
        local path = getWorkingDirectory() .. '/vprikol/settings.json'
        local result = {}
        local file = io.open(path)
        
        if file then
            result = decodeJson(file:read()) or {}
            file:close()
        end

        return table.assign(result, array, true)
    end

    function list:save(array)
        local path = getWorkingDirectory() .. '/vprikol/settings.json'
        if array and type(array) == 'table' and encodeJson(array) then
			local file = io.open(path, 'w')
			file:write(encodeJson(array))
			file:close()
		else
			sms('Ошибка при сохранение файла!')
		end
    end

    return list
end

local window = imgui.new.bool(false)
local fonts = {}

local update = {
    ['check'] = false,
    ['data'] = {}
}

local method = {
    ['searchNick'] = imgui.new.char[256](),
    ['captchaInput'] = imgui.new.char[256](),
    ['page'] = 1
}

local menu = {
    ['information'] = {},
    ['loading'] = {['bool'] = false, ['count'] = 1, ['wait'] = 0},
    ['graph'] = {['name'] = nil, ['surname'] = nil},
    ['captcha'] = nil,
    ['page'] = 1
}

local server = {
    ['selected'] = imgui.new.int(0),
    ['list'] = {},
    ['ip'] = {}
}

local settings = json():load({
    ['hotkey'] = {['informationKey'] = -1, ['checkrp'] = -1}
})

local hotkeyMenu = {
    ['informationKey'] = function(nick)
        imgui.StrCopy(method['searchNick'], nick)
        server['selected'][0] = server['ip'][select(1, sampGetCurrentServerAddress())] - 1
        getPlayerInformation(nick, server['selected'][0] + 1); method['page'] = 1
    end,
    ['checkrp'] = function(nick) getRolePlayNick(nick); method['page'] = 2 end
}

function main()
	if not isSampfuncsLoaded() or not isSampLoaded() then return end
	while not isSampAvailable() do wait(200) end
    log(''); log('Скрипт запущен!')
    getServerList()
    getScriptUpdate()
    while not update['check'] do wait(0) end
    sampRegisterChatCommand('vp', function() window[0] = not window[0] end)
    sampRegisterChatCommand('get', function(id)
        if tonumber(id) and (sampIsPlayerConnected(tonumber(id)) or tonumber(id) == select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) then
            window[0], menu['loading']['bool'] = true, true
            hotkeyMenu['informationKey'](sampGetPlayerNickname(tonumber(id)))
        else
            sms('Введите: /get [id]')
        end
    end)
    sampRegisterChatCommand('checkrp', function(id)
        if tonumber(id) and (sampIsPlayerConnected(tonumber(id)) or tonumber(id) == select(2, sampGetPlayerIdByCharHandle(PLAYER_PED))) then
            window[0], menu['loading']['bool'] = true, true
            hotkeyMenu['checkrp'](sampGetPlayerNickname(tonumber(id)))
        else
            sms('Введите: /checkrp [id]')
        end
    end)
    while true do wait(0)
        local result, ped = getCharPlayerIsTargeting(PLAYER_HANDLE)
		if result and sampIsPlayerConnected(select(2, sampGetPlayerIdByCharHandle(ped))) then
            for k, v in pairs(settings['hotkey']) do
                if isKeyJustPressed(v) then
                    window[0], menu['loading']['bool'] = true, true
                    hotkeyMenu[k](sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(ped))))
                end
            end
		end
    end
end

imgui.OnInitialize(function()
	imgui.GetIO().IniFilename = nil; style()

    local config = imgui.ImFontConfig()
    config.MergeMode, config.PixelSnapH = true, true

    local builder = imgui.ImFontGlyphRangesBuilder()
    for _, b in ipairs({'GEAR', 'XMARK', 'LIST'}) do builder:AddText(faicons(b)) end
    defaultGlyphRanges = imgui.ImVector_ImWchar(); builder:BuildRanges(defaultGlyphRanges)
    iconRanges = imgui.new.ImWchar[3](faicons.min_range, faicons.max_range, 0)

    for k, v in ipairs({20, 30}) do
        fonts[v] = imgui.GetIO().Fonts:AddFontFromFileTTF(getWorkingDirectory() .. '/vprikol/EagleSans-Regular.ttf', v, nil, imgui.GetIO().Fonts:GetGlyphRangesCyrillic())
        fonts[v] = imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(faicons.get_font_data_base85('solid'), v, config, defaultGlyphRanges[0].Data)
    end
end)

local newFrame = imgui.OnFrame(
	function() return window[0] and update['check'] and not isPauseMenuActive() and not sampIsScoreboardOpen() end,
	function(player)
        imgui.SetNextWindowPos(imgui.ImVec2(select(1, getScreenResolution()) / 2, select(2, getScreenResolution()) / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(600, 350), imgui.Cond.FirstUseEver)
        imgui.Begin('Frame', window, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar)
            imgui.PushFont(fonts[30])
                if menu['page'] == 1 then -->> Основная страница
                    if menu['information']['nick'] then
                        imgui.PushFont(fonts[20])
                                if method['page'] == 1 then
                                    imgui.SetCursorPosY(10)
                                    local arr = menu['information']['data']
                                    imgui.FTextCenter(u8( ('{Text}Информация о {ButtonActive}%s{Text} на сервере {ButtonActive}%s{Text} [{ButtonActive}%s{Text}]:'):format(menu['information']['nick'], server['list'][menu['information']['server']], menu['information']['server']) ))
                                    imgui.NewLine()
                                    imgui.BeginGroup()
                                        imgui.FTextCenter(u8('{Text}ID аккаунта: {ButtonActive}' .. arr['accountId']), 300)
                                        imgui.FTextCenter(u8('{Text}Уровень: {ButtonActive}' .. arr['lvl']), 300)
                                        imgui.FTextCenter(u8('{Text}Уровень VIP: {ButtonActive}' .. arr['vipLabel']), 300)
                                        imgui.FTextCenter(u8('{Text}Номер телефона: {ButtonActive}' .. arr['phoneNumber']), 300)
                                        imgui.FTextCenter(u8('{Text}Состояние: {ButtonActive}' .. (arr['isOnline'] and 'Онлайн' or 'Оффлайн')), 300)
                                    imgui.EndGroup()
                                    imgui.SameLine()
                                    imgui.BeginGroup()
                                        imgui.FTextCenter(u8('{Text}Всего денег: {ButtonActive} $' .. money_separator(arr['totalMoney'])), 900)
                                        imgui.FTextCenter(u8('{Text}Наличные: {ButtonActive} $' .. money_separator(arr['cash'])), 900)
                                        imgui.FTextCenter(u8('{Text}Деньги в банке: {ButtonActive} $' .. money_separator(arr['bank'])), 900)
                                        imgui.FTextCenter(u8('{Text}Депозит: {ButtonActive} $' .. money_separator(arr['deposit'])), 900)
                                        imgui.FTextCenter(u8('{Text}Личный счет: {ButtonActive}' .. (arr['individualAccount'] or 'Отсутствует')), 900)
                                    imgui.EndGroup()
                                    imgui.NewLine()
                                    imgui.FTextCenter(u8('{Text}Работа: {ButtonActive}' .. arr['jobLabel']))
                                    imgui.FTextCenter(u8('{Text}Организация: {ButtonActive}' .. arr['orgLabel']))
                                    imgui.FTextCenter(u8('{Text}Должность: {ButtonActive}' .. (arr['rankLabel'] or 'Отсутствует')))
                                elseif method['page'] == 2 then
                                    imgui.PushFont(fonts[20])
                                        if menu['graph']['name'] then
                                            imgui.SetCursorPosY((imgui.GetWindowHeight() - 260) / 2)
                                            imgui.FTextCenter(u8(('{Text}Имя {ButtonActive}%s{Text} %sявляется РП.'):format(menu['information']['name']['value'], menu['information']['name']['rp'] and '' or 'не ')), imgui.GetWindowWidth() * 0.5)
                                            imgui.SetCursorPosX((imgui.GetWindowWidth() / 2 - 266) / 2)
                                            local p = imgui.GetCursorScreenPos(); imgui.GetWindowDrawList():AddImageRounded(menu['graph']['name'], p, imgui.ImVec2(p.x + 266, p.y + 200), imgui.ImVec2(0, 0), imgui.ImVec2(1, 1), 0xFFFFFFFF, 3)
                                        else
                                            imgui.SetCursorPosY((imgui.GetWindowHeight() - 20) / 2)
                                            imgui.FTextCenter(u8(('{Text}Имя {ButtonActive}%s{Text} %sявляется РП.'):format(menu['information']['name']['value'], menu['information']['name']['rp'] and '' or 'не ')), imgui.GetWindowWidth() * 0.5)
                                        end

                                        if menu['graph']['surname'] then
                                            imgui.SetCursorPosY((imgui.GetWindowHeight() - 260) / 2)
                                            imgui.FTextCenter(u8(('{Text}Фамилия {ButtonActive}%s{Text} %sявляется РП.'):format(menu['information']['surname']['value'], menu['information']['surname']['rp'] and '' or 'не ')), imgui.GetWindowWidth() * 1.5)
                                            imgui.SetCursorPosX((imgui.GetWindowWidth() * 1.5 - 266) / 2)
                                            local p = imgui.GetCursorScreenPos(); imgui.GetWindowDrawList():AddImageRounded(menu['graph']['surname'], p, imgui.ImVec2(p.x + 266, p.y + 200), imgui.ImVec2(0, 0), imgui.ImVec2(1, 1), 0xFFFFFFFF, 3)
                                        else
                                            imgui.SetCursorPosY((imgui.GetWindowHeight() - 20) / 2)
                                            imgui.FTextCenter(u8(('{Text}Фамилия {ButtonActive}%s{Text} %sявляется РП.'):format(menu['information']['surname']['value'], menu['information']['surname']['rp'] and '' or 'не ')), imgui.GetWindowWidth() * 1.5)
                                        end
                                    imgui.PopFont()
                                end
                            
                            imgui.SetCursorPos(imgui.ImVec2((imgui.GetWindowWidth() - 300) / 2, imgui.GetWindowHeight() - 60))
                            if imgui.CustomButton(u8('Вернуться назад'), imgui.ImVec2(300)) then menu['information'] = {} end
                        imgui.PopFont()
                    elseif menu['loading']['bool'] or #server['list'] == 0 then
                        if #server['list'] == 0 then
                            imgui.SetCursorPosY((imgui.GetWindowHeight() - 195) / 2)
                            imgui.SetCursorPosX((imgui.GetWindowWidth() - 110) / 2)
                            imgui.loadingAnimation('Loading', 35, imgui.ImVec2(10, 30))

                            imgui.FTextCenter(u8('Загрузка списка серверов...'))

                            imgui.SetCursorPosX((imgui.GetWindowWidth() - 350) / 2)
                            if imgui.CustomButton(u8('Повторить попытку'), imgui.ImVec2(350)) then getServerList() end
                        else
                            imgui.SetCursorPos(imgui.ImVec2((imgui.GetWindowWidth() - 110) / 2, (imgui.GetWindowHeight() - 110) / 2))
                            imgui.loadingAnimation('Loading', 35, imgui.ImVec2(10, 30))
                        end
                    elseif menu['captcha'] then
                        imgui.SetCursorPos(imgui.ImVec2((imgui.GetWindowWidth() - 400) / 2, (imgui.GetWindowHeight() - 290) / 2))
                        imgui.BeginGroup()
                            imgui.BeginChild('image', imgui.ImVec2(400, 200), false)
                                local p = imgui.GetCursorScreenPos()
                                imgui.GetWindowDrawList():AddImageRounded(menu['captcha'], p, imgui.ImVec2(p.x + 400, p.y + 200), imgui.ImVec2(0, 0), imgui.ImVec2(1, 1), 0xFFFFFFFF, 3)
                            imgui.EndChild()

                            imgui.PushItemWidth(197.5); imgui.InputTextWithHint('##captcha', u8('Введите капчу'), method['captchaInput'], ffi.sizeof(method['captchaInput'])); imgui.PopItemWidth()

                            imgui.SameLine()

                            if imgui.CustomButton(u8('Подтвердить'), imgui.ImVec2(197.5)) then
                                getPlayerInformation(u8:decode(ffi.string(method['searchNick'])), server['selected'][0] + 1, u8:decode(ffi.string(method['captchaInput'])))
                                log('Капча введена: ' .. u8:decode(ffi.string(method['captchaInput'])))
                                menu['loading']['bool'], menu['captcha'] = true, nil
                                imgui.StrCopy(method['captchaInput'], '')
                            end

                            if imgui.CustomButton(u8('Назад'), imgui.ImVec2(400)) then
                                log('Ввод капчи отменён!')
                                menu['captcha'] = nil
                            end
                        imgui.EndGroup()
                    else
                        if method['page'] == 1 then
                            imgui.SetCursorPos(imgui.ImVec2((imgui.GetWindowWidth() - 300) / 2, (imgui.GetWindowHeight() - 185) / 2))
                            imgui.BeginGroup()
                                imgui.BetterInput('page1', u8('Поиск игрока'), 0, method['searchNick'], imgui.ImVec4(0.26, 0.59, 0.98, 1.00), imgui.ImVec4(0.00, 0.00, 0.00, 1.00), 300, imgui.ImVec4(0.5, 0.5, 0.5, 1.00))
                                imgui.PushItemWidth(300); imgui.Combo('##combo', server['selected'], imgui.new['const char*'][#server['list']](server['list']), #server['list']); imgui.PopItemWidth()
                                if imgui.CustomButton(u8('Найти'), imgui.ImVec2(300, 40)) and #u8:decode(ffi.string(method['searchNick'])) >= 3 then
                                    menu['loading']['bool'] = true
                                    getPlayerInformation(u8:decode(ffi.string(method['searchNick'])), server['selected'][0] + 1)
                                end
                            imgui.EndGroup()
                        elseif method['page'] == 2 then
                            imgui.SetCursorPos(imgui.ImVec2((imgui.GetWindowWidth() - 300) / 2, (imgui.GetWindowHeight() - 140) / 2))
                            imgui.BeginGroup()
                                imgui.BetterInput('page2', u8('Поиск имени'), 0, method['searchNick'], imgui.ImVec4(0.26, 0.59, 0.98, 1.00), imgui.ImVec4(0.00, 0.00, 0.00, 1.00), 300, imgui.ImVec4(0.5, 0.5, 0.5, 1.00))
                                if imgui.CustomButton(u8('Найти'), imgui.ImVec2(300, 40)) and #u8:decode(ffi.string(method['searchNick'])) >= 1 then
                                    menu['loading']['bool'] = true
                                    getRolePlayNick(u8:decode(ffi.string(method['searchNick'])))
                                end
                            imgui.EndGroup()
                        end

                        imgui.SetCursorPos(imgui.ImVec2(555, 5))
                        if imgui.CustomButton(faicons('XMARK'), imgui.ImVec2(39, 35), true) then window[0] = false end

                        imgui.SetCursorPos(imgui.ImVec2(510, 5))
                        if imgui.CustomButton(faicons('GEAR'), imgui.ImVec2(40, 35), true) then menu['page'] = 2 end

                        imgui.SetCursorPos(imgui.ImVec2(465, 5))
                        if imgui.CustomButton(faicons('LIST'), imgui.ImVec2(40, 35), true) then menu['page'] = 3 end
                    end
                elseif menu['page'] == 2 then -->> Настройки
                    imgui.SetCursorPos(imgui.ImVec2((imgui.GetWindowWidth() - 550) / 2, (imgui.GetWindowHeight() - 130) / 2))
                    imgui.BeginChild('hotkey', imgui.ImVec2(550, 140), false)
                        imgui.Hotkey('##informationKey', 'informationKey', imgui.ImVec2(235))
                        imgui.SameLine((240 + 550 - imgui.CalcTextSize(u8('Информация о игроке')).x) / 2)
                        imgui.Text(u8('Информация о игроке'))

                        imgui.Hotkey('##checkrp', 'checkrp', imgui.ImVec2(235))
                        imgui.SameLine((240 + 550 - imgui.CalcTextSize(u8('Проверка РП ника')).x) / 2)
                        imgui.Text(u8('Проверка РП ника'))

                        if imgui.CustomButton(u8('Вернуться назад'), imgui.ImVec2(-1)) then menu['page'] = 1 end
                    imgui.EndChild()
                elseif menu['page'] == 3 then -->> Выбор методов
                    imgui.SetCursorPos(imgui.ImVec2((imgui.GetWindowWidth() - 350) / 2, (imgui.GetWindowHeight() - 130) / 2))
                    imgui.BeginGroup()
                        if imgui.ButtonSelected(u8('Информация о игроке'), imgui.ImVec2(350, 40), 1) then method['page'] = 1 end
                        if imgui.ButtonSelected(u8('Проверка РП ника'), imgui.ImVec2(350, 40), 2) then method['page'] = 2 end
                        if imgui.Button(u8('Вернуться назад'), imgui.ImVec2(350)) then menu['page'] = 1 end
                    imgui.EndGroup()
                end

                imgui.PushFont(fonts[20])
                    imgui.SetCursorPos(imgui.ImVec2((imgui.GetWindowWidth() - imgui.CalcTextSize(u8('веселый прикол | https://vk.com/vprikolbot')).x) / 2, imgui.GetWindowHeight() - 25))
                    imgui.TextColored(imgui.ImVec4(0, 0, 0, 0.7), u8('веселый прикол | https://vk.com/vprikolbot'))
                imgui.PopFont()
            imgui.PopFont()
        imgui.End()
    end
)

local updateFrame = imgui.OnFrame(
	function() return not update['check'] and not isPauseMenuActive() and not sampIsScoreboardOpen() end,
	function(player)
        imgui.SetNextWindowPos(imgui.ImVec2(select(1, getScreenResolution()) / 2, select(2, getScreenResolution()) / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
        imgui.SetNextWindowSize(imgui.ImVec2(700, 350), imgui.Cond.FirstUseEver)
        imgui.Begin('Update', _, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar)
            imgui.PushFont(fonts[30])
                if update['data']['version'] then
                    imgui.Text(u8('Доступно обновление!'))
                    imgui.PushFont(fonts[20])
                        imgui.FText(u8('{TextDisabled}Текущая версия: #' .. thisScript().version))
                        imgui.FText(u8( ('{TextDisabled}Актуальная версия: #%s %s'):format(update['data']['version']['v'], update['data']['update']['mandatory'] and '{DragDropTarget}[Обязательное]' or '') ))

                    imgui.PopFont()

                    imgui.NewLine()

                    imgui.Text(u8('Список изменений:'))
                    imgui.BeginChild('updateList', imgui.ImVec2(-1, -45), false)
                        for k, v in ipairs(update['data']['update']['text']) do
                            imgui.PushFont(fonts[20]); imgui.FText(('{ButtonActive}%s) {Text}%s'):format(k, u8(v))); imgui.PopFont()
                        end
                    imgui.EndChild()

                    if not update['data']['update']['mandatory'] then
                        if imgui.CustomButton(u8('Установить'), imgui.ImVec2(200)) then downloadUpdate() end
                        imgui.SameLine(495)
                        if imgui.CustomButton(u8('Отмена'), imgui.ImVec2(200)) then update['check'] = true end
                    else
                        imgui.SetCursorPosX((imgui.GetWindowWidth() - 200) / 2)
                        if imgui.CustomButton(u8('Установить'), imgui.ImVec2(200)) then downloadUpdate() end
                    end
                else
                    imgui.SetCursorPosY((imgui.GetWindowHeight() - 195) / 2)
                    imgui.SetCursorPosX((imgui.GetWindowWidth() - 110) / 2)
                    imgui.loadingAnimation('Loading', 35, imgui.ImVec2(10, 30))

                    imgui.FTextCenter(u8('Проверка наличия обновлений...'))

                    imgui.SetCursorPosX((imgui.GetWindowWidth() - 300) / 2)
                    if imgui.CustomButton(u8('Повторить попытку'), imgui.ImVec2(300)) then getScriptUpdate() end
                end
            imgui.PopFont()
        imgui.End()
    end
)

function onScriptTerminate(scr, quitGame) 
    if scr == thisScript() then
        log('Скрипт завершил работу. Причина: ' .. (quitGame and 'Выход из игры' or 'Сценарий завершен'))
    end
end

-->> GUI Functions
function imgui.ButtonSelected(text, size, menu)
    local dl = imgui.GetWindowDrawList()
    local p = imgui.GetCursorScreenPos()
    local result = imgui.CustomButton('##' .. text, size)

    dl:AddCircleFilled(imgui.ImVec2(p.x + 20, p.y + (size.y) / 2), 7.5, imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col[method['page'] == menu and 'ButtonActive' or 'TextDisabled']]), 100)
    dl:AddText(imgui.ImVec2(p.x + (size.x + 15 - imgui.CalcTextSize(text).x) / 2, p.y + (size.y - imgui.CalcTextSize(text).y) / 2), imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.Text]), text)
    return result
end

function imgui.loadingAnimation(label, radius, size)
    imgui.BeginChild(label, imgui.ImVec2(110, 110), false)
        if os.clock() - menu['loading']['wait'] > 0.1 then
            menu['loading']['wait'] = os.clock()
            if menu['loading']['count'] == 12 then
                menu['loading']['count'] = 1
            else
                menu['loading']['count'] = menu['loading']['count'] + 1
            end
        end

        local dl = imgui.GetWindowDrawList()
        local p = imgui.GetCursorScreenPos() 

        for i = 1, 12 do
            local color = (menu['loading']['count'] == i) and imgui.GetColorU32Vec4(imgui.ImVec4(0.2, 0.2, 0.2, 1.0)) or imgui.GetColorU32Vec4(imgui.ImVec4(0.7, 0.7, 0.7, 1))
            local x, y = math.cos(math.rad(i * 30)) * radius, math.sin(math.rad(i * 30)) * radius
            local rx, ry = size.x, size.y
            local point = p + imgui.ImVec2(x + radius + size.y * 0.5 + 5, y + radius + size.x * 1.5 + 5)

            local startRender = point - imgui.ImVec2(rx / 2, ry / 2)
            local endRender = point + imgui.ImVec2(rx / 2, ry / 2)

            ImRotateStart()
            dl:AddRectFilled(startRender, endRender, color, 3)
            ImRotateEnd(math.rad(-i * 30))
        end
    imgui.EndChild()
end

function imgui.BetterInput(name, hint_text, flags, buffer, color, text_color, width, colorInactive)
    imgui.SetCursorPosY(imgui.GetCursorPos().y + (imgui.CalcTextSize(hint_text).y * 0.7))
    if UI_BETTERINPUT == nil then UI_BETTERINPUT = {} end
    if not UI_BETTERINPUT[name] then UI_BETTERINPUT[name] = {buffer = buffer or imgui.new.char[256](''), width = nil, hint = { pos = nil, old_pos = nil, scale = nil }, color = colorInactive or imgui.GetStyle().Colors[imgui.Col.TextDisabled], old_color = colorInactive or imgui.GetStyle().Colors[imgui.Col.TextDisabled], active = {false, nil}, inactive = {true, nil}} end

    local pool = UI_BETTERINPUT[name]
    if color == nil then color = imgui.GetStyle().Colors[imgui.Col.ButtonActive] end
    if width == nil then
        pool["width"] = imgui.CalcTextSize(hint_text).x + 50
        if pool["width"] < 150 then
            pool["width"] = 150
        end
    else
        pool["width"] = width
    end

    if pool["hint"]["scale"] == nil then pool["hint"]["scale"] = 1.0 end
    if pool["hint"]["pos"] == nil then pool["hint"]["pos"] = imgui.ImVec2(imgui.GetCursorPos().x, imgui.GetCursorPos().y) end
    if pool["hint"]["old_pos"] == nil then pool["hint"]["old_pos"] = imgui.GetCursorPos().y end
    imgui.PushStyleColor(imgui.Col.FrameBg, imgui.ImVec4(1, 1, 1, 0))
    imgui.PushStyleColor(imgui.Col.Text, text_color or imgui.ImVec4(1, 1, 1, 0))
    imgui.PushStyleColor(imgui.Col.TextSelectedBg, color)
    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(0, imgui.GetStyle().FramePadding.y))
    imgui.PushItemWidth(pool["width"])
    local draw_list = imgui.GetWindowDrawList()
    draw_list:AddLine(
        imgui.ImVec2(imgui.GetCursorPos().x + imgui.GetWindowPos().x,
        imgui.GetCursorPos().y + imgui.GetWindowPos().y + (2 * imgui.GetStyle().FramePadding.y) + imgui.CalcTextSize(hint_text).y),
        imgui.ImVec2(imgui.GetCursorPos().x + imgui.GetWindowPos().x + pool["width"],
        imgui.GetCursorPos().y + imgui.GetWindowPos().y + (2 * imgui.GetStyle().FramePadding.y) + imgui.CalcTextSize(hint_text).y),
        imgui.GetColorU32Vec4(imgui.ImVec4(pool["color"].x, pool["color"].y, pool["color"].z, 1)), 2.0
    )

    local input = imgui.InputText("##" .. name, pool["buffer"], ffi.sizeof(pool["buffer"]), flags or 0)
    if not imgui.IsItemActive() then
        if pool["inactive"][2] == nil then pool["inactive"][2] = os.clock() end
        pool["inactive"][1] = true
        pool["active"][1] = false
        pool["active"][2] = nil
    elseif imgui.IsItemActive() or imgui.IsItemClicked() then
        pool["inactive"][1] = false
        pool["inactive"][2] = nil
        if pool["active"][2] == nil then pool["active"][2] = os.clock() end
        pool["active"][1] = true
    end
    if pool["inactive"][1] and #ffi.string(pool["buffer"]) == 0 then
        pool["color"] = bringVec4To(pool["color"], pool["old_color"], pool["inactive"][2], 0.75)
        pool["hint"]["scale"] = bringFloatTo(pool["hint"]["scale"], 1.0, pool["inactive"][2], 0.25)
        pool["hint"]["pos"].y = bringFloatTo(pool["hint"]["pos"].y, pool["hint"]["old_pos"], pool["inactive"][2], 0.25)
        
    elseif pool["inactive"][1] and #ffi.string(pool["buffer"]) > 0 then
        pool["color"] = bringVec4To(pool["color"], pool["old_color"], pool["inactive"][2], 0.75)
        pool["hint"]["scale"] = bringFloatTo(pool["hint"]["scale"], 0.7, pool["inactive"][2], 0.25)
        pool["hint"]["pos"].y = bringFloatTo(pool["hint"]["pos"].y, pool["hint"]["old_pos"] - (imgui.GetFontSize() * 0.7) - 2,
        pool["inactive"][2], 0.25)

    elseif pool["active"][1] and #ffi.string(pool["buffer"]) == 0 then
        pool["color"] = bringVec4To(pool["color"], color, pool["active"][2], 0.75)
        pool["hint"]["scale"] = bringFloatTo(pool["hint"]["scale"], 0.7, pool["active"][2], 0.25)
        pool["hint"]["pos"].y = bringFloatTo(pool["hint"]["pos"].y, pool["hint"]["old_pos"] - (imgui.GetFontSize() * 0.7) - 2,
        pool["active"][2], 0.25)

    elseif pool["active"][1] and #ffi.string(pool["buffer"]) > 0 then
        pool["color"] = bringVec4To(pool["color"], color, pool["active"][2], 0.75)
        pool["hint"]["scale"] = bringFloatTo(pool["hint"]["scale"], 0.7, pool["active"][2], 0.25)
        pool["hint"]["pos"].y = bringFloatTo(pool["hint"]["pos"].y, pool["hint"]["old_pos"] - (imgui.GetFontSize() * 0.7) - 2,
        pool["active"][2], 0.25)
    end
    imgui.SetWindowFontScale(pool["hint"]["scale"])
    draw_list:AddText(
        imgui.ImVec2(pool["hint"]["pos"].x + imgui.GetWindowPos().x + imgui.GetStyle().FramePadding.x,pool["hint"]["pos"].y + imgui.GetWindowPos().y + imgui.GetStyle().FramePadding.y),
        imgui.GetColorU32Vec4(imgui.ImVec4(pool["color"].x, pool["color"].y, pool["color"].z, 1)),
        hint_text
    )
    imgui.SetWindowFontScale(1.0)
    imgui.PopItemWidth()
    imgui.PopStyleColor(3)
    imgui.PopStyleVar()
    return input
end

function imgui.FText(text)
	local render_text = function(stext)
		local text, colors, m = {}, {}, 1
		while stext:find('{%u%l-%u-%l-%u-%l-}') do
			local n, k = stext:find('{.-}')
			local color = imgui.GetStyle().Colors[imgui.Col[stext:sub(n + 1, k - 1)]]
			if color then
				text[#text], text[#text + 1] = stext:sub(m, n - 1), stext:sub(k + 1, #stext)
				colors[#colors + 1] = color
				m = n
			end
			stext = stext:sub(1, n - 1) .. stext:sub(k + 1, #stext)
		end
		if text[0] then
			for i = 0, #text do
                imgui.TextColored(colors[i] or colors[1], text[i])
                imgui.SameLine(nil, 0)
			end
			imgui.NewLine()
		else imgui.Text(stext) end
	end
	render_text(text)
end

function imgui.FTextCenter(text, size)
    local textT = text:gsub('{.-}', '')
    imgui.SetCursorPosX(((size or imgui.GetWindowWidth()) - imgui.CalcTextSize(textT).x) / 2)
    imgui.FText(text)
end

function imgui.CustomButton(text, size, icon)
    local colorButton = imgui.GetStyle().Colors[imgui.Col.Button]
    local colorButton = imgui.ImVec4(colorButton.x, colorButton.y, colorButton.z, 0.2)

    imgui.PushStyleVarFloat(imgui.StyleVar.FrameBorderSize, IconButtonBorder == text and 1 or 0)
        imgui.PushStyleColor(imgui.Col.Border, IconButtonBorder == text and imgui.GetStyle().Colors[imgui.Col.ButtonHovered] or imgui.ImVec4(0, 0, 0, 0))
        imgui.PushStyleColor(imgui.Col.Button, icon and imgui.ImVec4(0, 0, 0, 0) or colorButton)
        imgui.PushStyleColor(imgui.Col.ButtonHovered, colorButton)
        imgui.PushStyleColor(imgui.Col.ButtonActive, colorButton)
            local result = imgui.Button(text, size)
        imgui.PopStyleColor(4)
    imgui.PopStyleVar(1)

    if IconButtonBorder ~= text and imgui.IsItemHovered() then
        IconButtonBorder = text
    elseif IconButtonBorder == text and not imgui.IsItemHovered() then
        IconButtonBorder = nil
    end

	return result
end

function imgui.Hotkey(label, keys, size)
    if UI_HOTKEY == nil then UI_HOTKEY = {} end
    if UI_HOTKEY[label] == nil then UI_HOTKEY[label] = false end

    -- local result = {bool = false, keys = {}}
    local result = false
    local name = UI_HOTKEY[label] and (os.time() % 2 == 0 and u8('Нажмите клавишу') or '') or (settings['hotkey'][keys] ~= -1 and vkeys.id_to_name(settings['hotkey'][keys]) or u8('Свободно'))

    if UI_HOTKEY[label] then
        if imgui.IsKeyDown(8) then
            -- result = {bool = true, keys = {old = settings['hotkey'][keys], new = -1}}
            settings['hotkey'][keys] = -1
            sms('Вы сбросили клавишу!')
            UI_HOTKEY[label] = false
            json():save(settings) 
        else
            for k, v in pairs(vkeys.key_names) do
                if imgui.IsKeyDown(k) then
                    -- result = {bool = true, keys = {old = settings['hotkey'][keys], new = k}}
                    settings['hotkey'][keys] = k
                    sms('Вы установили клавишу!')
                    UI_HOTKEY[label] = false
                    json():save(settings) 
                end
            end
        end
    end

    if imgui.CustomButton(name .. '##' .. label, size) then UI_HOTKEY[label] = true end
end

-->> Help Functions
function bringVec4To(from, to, start_time, duration)
    local timer = os.clock() - start_time if timer >= 0.00 and timer <= duration then local count = timer / (duration / 100) return imgui.ImVec4(from.x + (count * (to.x - from.x) / 100),from.y + (count * (to.y - from.y) / 100),from.z + (count * (to.z - from.z) / 100),from.w + (count * (to.w - from.w) / 100)), true end; return (timer > duration) and to or from, false
end

function bringFloatTo(from, to, start_time, duration)
    local timer = os.clock() - start_time; if timer >= 0.00 and timer <= duration then local count = timer / (duration / 100) return from + (count * (to - from) / 100), true end; return (timer > duration) and to or from, false
end

function sms(text)
    local text = tostring(text):gsub('{mc}', '{e89f64}'):gsub('{%-1}', '{FFFFFF}')
    sampAddChatMessage('VPrikol » {FFFFFF}' .. text, 0xe89f64)
end

function money_separator(n)
    local left,num,right = string.match(n,'^([^%d]*%d)(%d*)(.-)$')
    return left..(num:reverse():gsub('(%d%d%d)','%1.'):reverse())..right
end

function log(text)
    local path_download = getWorkingDirectory() .. '/vprikol/Log.txt'
    local file = io.open(path_download, 'a')
    file:write(#text > 0 and ('\n%s %s'):format(os.date('[%d.%m.%Y | %H:%M:%S]'), text) or '\n')
    file:close()
end

-->> HTTP
function asyncHttpRequest(method, url, args, resolve, reject)
   local request_thread = effil.thread(function(method, url, args)
      local requests = require 'requests'
      local cjson = require('cjson')
      local result, response = pcall(requests.request, method, url, cjson.decode(args))
      if result then
         response.json, response.xml = nil, nil
         return true, response
      else
         return false, response
      end
   end)(method, url, encodeJson(args))
   -- Если запрос без функций обработки ответа и ошибок.
   if not resolve then resolve = function() end end
   if not reject then reject = function() end end
   -- Проверка выполнения потока
   lua_thread.create(function()
      local runner = request_thread
      while true do
         local status, err = runner:status()
         if not err then
            if status == 'completed' then
               local result, response = runner:get()
               if result then
                  resolve(response)
               else
                  reject(response)
               end
               return
            elseif status == 'canceled' then
               return reject(status)
            end
         else
            return reject(err)
         end
         wait(0)
      end
   end)
end

function getPlayerInformation(nick, currentServer, captcha)
    log('getPlayerInformation: ' .. ('%s | Сервер: %s [%s] | Капча: %s'):format(nick, server['list'][currentServer], currentServer, tostring(captcha)))

    local params = {
        ['params'] = {
            ['nick'] = nick,
            ['server'] = currentServer,
            ['captcha'] = captcha or '',
            ['preview'] = 'no'
        }
    }

    asyncHttpRequest('GET', 'https://backend.vprikol.ru/api/find', params,
        function(response)
            log('getPlayerInformation: Response')
            if response.status_code == 200 then
                log('getPlayerInformation: status_code 200')
                if decodeJson(response.text)['status'] == 'captcha' then
                    log('getPlayerInformation: Пришла капча')
                    local path_download = getWorkingDirectory() .. '/vprikol/captcha.png'
                    local url = decodeJson(response.text)['image']
                    downloadUrlToFile(url, path_download, function(id, status, p1, p2)
                        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                            log('getPlayerInformation: Скачал капчу')
                            menu['captcha'] = imgui.CreateTextureFromFile(path_download)
                            menu['loading']['bool'] = false
                        end
                    end)
                elseif decodeJson(response.text)['status'] == 'success' then
                    log('getPlayerInformation: Пришла информация')
                    menu['information'] = decodeJson(u8:decode(response.text))
                    menu['loading']['bool'] = false
                end
            elseif response.status_code ~= 200 and decodeJson(response.text)['status'] == 'error' then
                log('getPlayerInformation: status_code ' .. response.status_code)
                sms(u8:decode(decodeJson(response.text)['message']))
                menu['loading']['bool'] = false
            end
        end,
        function(err)
            log('getPlayerInformation: Error' .. tostring(err):match('requests%.lua:%d+: (.+)'))
            sms('Произошла ошибка: {mc}' .. tostring(err):match('requests%.lua:%d+: (.+)'))
            menu['loading']['bool'] = false
        end) 
end

function getRolePlayNick(nick)
    log('getRolePlayNick: Nick: ' .. nick)

    local params = {
        ['params'] = {
            ['nick'] = nick,
            ['preview'] = 'success'
        }
    }

    asyncHttpRequest('GET', 'https://backend.vprikol.ru/api/checkrp', params,
        function(response)
            log('getRolePlayNick: Response')
            if response.status_code == 200 then
                log('getRolePlayNick: status_code 200')
                downloadImage(decodeJson(response.text), function()
                    menu['information'], menu['loading']['bool'] = decodeJson(response.text), false
                end)
            end
        end,
        function(err)
            log('getRolePlayNick: Error' .. tostring(err):match('requests%.lua:%d+: (.+)'))
            sms('Произошла ошибка: {mc}' .. tostring(err):match('requests%.lua:%d+: (.+)'))
            menu['loading']['bool'] = false
        end) 
end

function downloadImage(data, resolve)
    local countDownload = 0
    local image = {
        {'name', data['name']['graph']},
        {'surname', data['surname']['graph']}
    }

    for k, v in ipairs(image) do
        local path = getWorkingDirectory() .. '/vprikol/' .. v[1] .. '.jpg'
        if v[2] then
            downloadUrlToFile(v[2], path, function(id, status, p1, p2)
                if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                    log('downloadImage: ' .. v[1] .. ' Скачал картинку')
                    menu['graph'][v[1]] = imgui.CreateTextureFromFile(path)
                    countDownload = countDownload + 1
                    if countDownload == 2 then resolve() end
                end
            end)
        else
            log('downloadImage: ' .. v[1] .. ' Картинка не нужна')
            menu['graph'][v[1]] = nil
            countDownload = countDownload + 1
            if countDownload == 2 then resolve() end
        end
    end
end

function getServerList()
    local path_download = getWorkingDirectory() .. '/vprikol/servers.json'
    downloadUrlToFile('https://api-samp.arizona-five.com/launcher/servers-data', path_download, function(id, status, p1, p2)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
            local file = io.open(path_download)
            if file then
                for k, v in ipairs(decodeJson(file:read())['arizona']) do
                    server['list'][v.number] = v.name
                    server['ip'][v.ip] = v.number
                end
                log('Список серверов загружен. Количество: ' .. #server['list'])
            end
        end
    end)
end

function getScriptUpdate()
    local path_download = getWorkingDirectory() .. '/vprikol/update.json'
    downloadUrlToFile('https://raw.githubusercontent.com/evans-dev1/vprikol-lua/main/version.json', path_download, function(id, status, p1, p2)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
            local file = io.open(path_download)
            if file then
                local t = decodeJson(u8:decode(file:read('all')))
                if t then
                    update['data'] = t
                    log('Список обновлений загружен!')
                    log('Версия скрипта: ' .. thisScript().version)
                    log('Последняя версия: ' .. update['data']['version']['v'])
                    if update['data']['version']['v'] == thisScript().version then update['check'] = true end
                end
            end
        end
    end)
end

function downloadUpdate()
    downloadUrlToFile(update['data']['version']['url'], thisScript().path, function(id, status, p1, p2)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
            log('Загрузил обновление!')
            lua_thread.create(function() wait(500) thisScript():reload() end)
        end
    end)
end

-->> Change Angle
function ImMin(lhs, rhs)
    return imgui.ImVec2(math.min(lhs.x, rhs.x), math.min(lhs.y, rhs.y))
end

function ImMax(lhs, rhs)
    return imgui.ImVec2(math.max(lhs.x, rhs.x), math.max(lhs.y, rhs.y))
end

function ImRotate(v, cos_a, sin_a)
    return imgui.ImVec2(v.x * cos_a - v.y * sin_a, v.x * sin_a + v.y * cos_a)
end

function ImRotateStart()
    rotation_start_index = imgui.GetWindowDrawList().VtxBuffer.Size;
end

function calcImVec2(l, r)
    return {x = l.x - r.x, y = l.y - r.y}
end

function ImRotationCenter()
    local l, u = imgui.ImVec2(imgui.FLT_MAX, imgui.FLT_MAX), imgui.ImVec2(-imgui.FLT_MAX, -imgui.FLT_MAX)
    local buf = imgui.GetWindowDrawList().VtxBuffer
    for i = rotation_start_index, buf.Size - 1 do
        l, u = ImMin(l, buf.Data[i].pos), ImMax(u, buf.Data[i].pos)
    end
    return imgui.ImVec2((l.x+u.x)/2, (l.y+u.y)/2)
end

function ImRotateEnd(rad, center)
    if center == nil then center = ImRotationCenter() end
    local s, c = math.sin(rad), math.cos(rad)
    center = calcImVec2(ImRotate(center, s, c), center)
    local buf = imgui.GetWindowDrawList().VtxBuffer
    for i = rotation_start_index, buf.Size - 1 do
        buf.Data[i].pos = calcImVec2(ImRotate(buf.Data[i].pos, s, c), center)
    end
end

-->> Style
function style()
    imgui.SwitchContext()
    local style = imgui.GetStyle();
    local color = imgui.Col;
    style.Alpha = 1;
    style.WindowPadding = imgui.ImVec2(5.00, 5.00);
    style.WindowRounding = 3;
    style.WindowBorderSize = 1;
    style.WindowMinSize = imgui.ImVec2(32.00, 32.00);
    style.WindowTitleAlign = imgui.ImVec2(0.50, 0.50);
    style.ChildRounding = 3;
    style.ChildBorderSize = 1;
    style.PopupRounding = 3;
    style.PopupBorderSize = 1;
    style.FramePadding = imgui.ImVec2(5.00, 5.00);
    style.FrameRounding = 3;
    style.FrameBorderSize = 0;
    style.ItemSpacing = imgui.ImVec2(5.00, 5.00);
    style.ItemInnerSpacing = imgui.ImVec2(5.00, 5.00);
    style.IndentSpacing = 21;
    style.ScrollbarSize = 14;
    style.ScrollbarRounding = 2;
    style.GrabMinSize = 30;
    style.GrabRounding = 3;
    style.TabRounding = 3;
    style.ButtonTextAlign = imgui.ImVec2(0.50, 0.50);
    style.SelectableTextAlign = imgui.ImVec2(0.50, 0.50);
    style.Colors[imgui.Col.Text] = imgui.ImVec4(0.00, 0.00, 0.00, 1.00);
    style.Colors[imgui.Col.TextDisabled] = imgui.ImVec4(0.60, 0.60, 0.60, 1.00);
    style.Colors[imgui.Col.WindowBg] = imgui.ImVec4(0.94, 0.94, 0.94, 1.00);
    style.Colors[imgui.Col.ChildBg] = imgui.ImVec4(0.5, 0.5, 0.5, 0.00);
    style.Colors[imgui.Col.PopupBg] = imgui.ImVec4(1.00, 1.00, 1.00, 0.98);
    style.Colors[imgui.Col.Border] = imgui.ImVec4(0.00, 0.00, 0.00, 0.30);
    style.Colors[imgui.Col.BorderShadow] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00);
    style.Colors[imgui.Col.FrameBg] = imgui.ImVec4(1.00, 1.00, 1.00, 1.00);
    style.Colors[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.26, 0.59, 0.98, 0.40);
    style.Colors[imgui.Col.FrameBgActive] = imgui.ImVec4(0.26, 0.59, 0.98, 0.67);
    style.Colors[imgui.Col.TitleBg] = imgui.ImVec4(0.96, 0.96, 0.96, 1.00);
    style.Colors[imgui.Col.TitleBgActive] = imgui.ImVec4(0.82, 0.82, 0.82, 1.00);
    style.Colors[imgui.Col.TitleBgCollapsed] = imgui.ImVec4(1.00, 1.00, 1.00, 0.51);
    style.Colors[imgui.Col.MenuBarBg] = imgui.ImVec4(0.86, 0.86, 0.86, 1.00);
    style.Colors[imgui.Col.ScrollbarBg] = imgui.ImVec4(0.98, 0.98, 0.98, 0.53);
    style.Colors[imgui.Col.ScrollbarGrab] = imgui.ImVec4(0.69, 0.69, 0.69, 0.80);
    style.Colors[imgui.Col.ScrollbarGrabHovered] = imgui.ImVec4(0.49, 0.49, 0.49, 0.80);
    style.Colors[imgui.Col.ScrollbarGrabActive] = imgui.ImVec4(0.49, 0.49, 0.49, 1.00);
    style.Colors[imgui.Col.CheckMark] = imgui.ImVec4(0.26, 0.59, 0.98, 1.00);
    style.Colors[imgui.Col.SliderGrab] = imgui.ImVec4(0.26, 0.59, 0.98, 0.78);
    style.Colors[imgui.Col.SliderGrabActive] = imgui.ImVec4(0.46, 0.54, 0.80, 0.60);
    style.Colors[imgui.Col.Button] = imgui.ImVec4(0.26, 0.59, 0.98, 0.40);
    style.Colors[imgui.Col.ButtonHovered] = imgui.ImVec4(0.26, 0.59, 0.98, 1.00);
    style.Colors[imgui.Col.ButtonActive] = imgui.ImVec4(0.06, 0.53, 0.98, 1.00);
    style.Colors[imgui.Col.Header] = imgui.ImVec4(0.26, 0.59, 0.98, 0.31);
    style.Colors[imgui.Col.HeaderHovered] = imgui.ImVec4(0.26, 0.59, 0.98, 0.80);
    style.Colors[imgui.Col.HeaderActive] = imgui.ImVec4(0.26, 0.59, 0.98, 1.00);
    style.Colors[imgui.Col.Separator] = imgui.ImVec4(0.39, 0.39, 0.39, 0.62);
    style.Colors[imgui.Col.SeparatorHovered] = imgui.ImVec4(0.14, 0.44, 0.80, 0.78);
    style.Colors[imgui.Col.SeparatorActive] = imgui.ImVec4(0.14, 0.44, 0.80, 1.00);
    style.Colors[imgui.Col.ResizeGrip] = imgui.ImVec4(0.80, 0.80, 0.80, 0.56);
    style.Colors[imgui.Col.ResizeGripHovered] = imgui.ImVec4(0.26, 0.59, 0.98, 0.67);
    style.Colors[imgui.Col.ResizeGripActive] = imgui.ImVec4(0.26, 0.59, 0.98, 0.95);
    style.Colors[imgui.Col.Tab] = imgui.ImVec4(0.76, 0.80, 0.84, 0.93);
    style.Colors[imgui.Col.TabHovered] = imgui.ImVec4(0.26, 0.59, 0.98, 0.80);
    style.Colors[imgui.Col.TabActive] = imgui.ImVec4(0.60, 0.73, 0.88, 1.00);
    style.Colors[imgui.Col.TabUnfocused] = imgui.ImVec4(0.92, 0.93, 0.94, 0.99);
    style.Colors[imgui.Col.TabUnfocusedActive] = imgui.ImVec4(0.74, 0.82, 0.91, 1.00);
    style.Colors[imgui.Col.PlotLines] = imgui.ImVec4(0.39, 0.39, 0.39, 1.00);
    style.Colors[imgui.Col.PlotLinesHovered] = imgui.ImVec4(1.00, 0.43, 0.35, 1.00);
    style.Colors[imgui.Col.PlotHistogram] = imgui.ImVec4(0.90, 0.70, 0.00, 1.00);
    style.Colors[imgui.Col.PlotHistogramHovered] = imgui.ImVec4(1.00, 0.45, 0.00, 1.00);
    style.Colors[imgui.Col.TextSelectedBg] = imgui.ImVec4(0.26, 0.59, 0.98, 0.35);
    style.Colors[imgui.Col.DragDropTarget] = imgui.ImVec4(0.92, 0.25, 0.25, 1);
    style.Colors[imgui.Col.NavHighlight] = imgui.ImVec4(0.26, 0.59, 0.98, 0.80);
    style.Colors[imgui.Col.NavWindowingHighlight] = imgui.ImVec4(0.70, 0.70, 0.70, 0.70);
    style.Colors[imgui.Col.NavWindowingDimBg] = imgui.ImVec4(0.20, 0.20, 0.20, 0.20);
    style.Colors[imgui.Col.ModalWindowDimBg] = imgui.ImVec4(0.20, 0.20, 0.20, 0.35);
end