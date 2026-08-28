-- Family - an alt manager for World of Warcraft Classic
-- Copyright (C) 2026 Alberto Pittaluga
--
-- This program is free software: you can redistribute it and/or modify it under the
-- terms of the GNU General Public License as published by the Free Software
-- Foundation, either version 3 of the License, or (at your option) any later version.
-- See the LICENSE file at the root of this repository.

-- Russian. The key is the English sentence; see Locale.lua for why.
--
-- Read on every client, not only a Russian one, so that the harness can check it. Nothing
-- here takes effect unless GetLocale() says ruRU.
--
-- Where a string sits in a fixed space, the room it has is written after it in characters.
-- The harness enforces those: Russian does not run to the same length as English, and a
-- label that overruns is drawn straight through whatever sits beside it.
--
-- Grouped by the panel each string belongs to, so a whole screen can be read at once.

local _, Family = ...

Family.locales.ruRU = {

	-- The window itself, and what it says when a panel goes wrong
	["No"] = "Нет",
	["Yes"] = "Да",
	["now"] = "сейчас",
	["HIGH"] = "Высокий",
	["DIALOG"] = "Диалог",
	["MEDIUM"] = "Средний",
	["in %dd"] = "через %dд",
	["in %dh"] = "через %dч",
	["in %dm"] = "через %dм",
	["%d h ago"] = "%d ч. назад",
	["just now"] = "только что",
	["yesterday"] = "вчера",
	["%d min ago"] = "%d мин. назад",
	["%d days ago"] = "%d дн. назад",
	["Family - %s"] = "",
	["|cff9d9d9dnever|r"] = "|cff9d9d9dникогда|r",
	["|cffc79fefshared by %s|r"] = "|cffc79fefпоказано семьёй %s|r",
	["|cffff5555the %s panel failed to draw|r: %s"] = "|cffff5555панель %s не удалось отрисовать|r: %s",
	["|cffff5555the %s panel failed to build|r: %s"] = "|cffff5555панель %s не удалось построить|r: %s",
	["to remove %s, type |cffffd700/family forget %s|r"] = "чтобы удалить %s, введите |cffffd700/family forget %s|r",
	["|cffffaa00the %s panel built but defined no Refresh|r"] = "|cffffaa00панель %s построена, но не определила Refresh|r",
	["|cffffaa00%s|r - but this client has no way to ask, so nothing was done."] = "|cffffaa00%s|r - но этот клиент не может спросить, поэтому ничего не сделано.",
	["|cffffaa00a row of %d buttons needs %d pixels and has %d - the labels are longer than the room in this language|r"] = "|cffffaa00ряду из %d кнопок нужно %d пикселей, а есть %d - подписи в этом языке длиннее, чем место|r",
	["Remove %s from Family?\n\nEverything recorded about this character goes with it. Logging in on them again starts recording afresh."] = "Удалить %s из Family?\n\nВсё записанное об этом персонаже удалится вместе с ним. Повторный вход за него начнёт запись заново.",

	-- The summary: its column sets, its columns and its totals
	["%dm"] = "%dм",
	["Bags"] = "Сумки",  -- 14
	["Race"] = "Раса",  -- 15
	["soon"] = "скоро",
	["Total"] = "Итого",
	["Buyout"] = "Выкуп",  -- 16
	["Member"] = "Персонаж",  -- 20
	["Played"] = "Сыграно",  -- 13
	["%dd %dh"] = "%dд %dч",
	["%dh %dm"] = "%dч %dм",
	["AH seen"] = "АД замечен",  -- 10
	["Rest XP"] = "Отдых",  -- 13
	["Activity"] = "Активность",  -- 14
	["Crafting"] = "Создание",  -- 14
	["Item lvl"] = "Ур. пред.",  -- 10
	["Overview"] = "Обзор",  -- 14
	["Bag slots"] = "Ячейки сумок",  -- 13
	["Bags seen"] = "Сумки замеч.",  -- 15
	["Bank seen"] = "Банк замечен",  -- 15
	["Bid value"] = "Сумма ставок",  -- 16
	["Free bags"] = "Своб. сумки",  -- 13
	["Free bank"] = "Своб. банк",  -- 13
	["Last seen"] = "Замечен",  -- 14
	["Mail seen"] = "Почта зам.",  -- 11
	["Bank slots"] = "Ячейки банка",  -- 13
	["Currencies"] = "Валюта",  -- 14
	["Expires in"] = "Истекает",  -- 12
	["Hearthstone"] = "Камень возвр.",  -- 26
	["Grand totals"] = "Общий итог",
	["Miscellaneous"] = "Разное",  -- 14
	["Unknown realm"] = "Неизвестный мир",
	["|cffff4444gone|r"] = "|cffff4444пропало|r",
	["|cff40bf40ready|r"] = "|cff40bf40готово|r",
	["|cff40bf40shown|r"] = "|cff40bf40показано|r",
	["|cff9d9d9dhidden|r"] = "|cff9d9d9dскрыто|r",
	["|cff9d9d9dnot seen|r"] = "|cff9d9d9dне видно|r",
	["|cff888888shared|r %s"] = "|cff888888передано|r %s",
	["|cff9d9d9dmax level|r"] = "|cff9d9d9dмакс. уровень|r",
	["%d |cff888888(%d in post)|r"] = "%d |cff888888(%d в пути)|r",
	["|cffffd700%d|r |cff888888in post|r"] = "|cffffd700%d|r |cff888888в пути|r",
	["|cffffaa00the %s columns add up to %d, wider than the %d a row has|r"] = "|cffffaa00столбцы %s в сумме дают %d, что шире %d, доступных строке|r",
	[" |cffffaa00%d more not shown - there is only so much room in a row.|r|cff888888"] = " |cffffaa00ещё %d не показано - в строке столько места.|r|cff888888",
	["|cffffaa00%d column sets leave %d pixels each across the top, and a label needs %d|r"] = "|cffffaa00%d наборов столбцов оставляют по %d пикселей сверху, а подписи нужно %d|r",
	["|cffffaa00Both sides are switched off.|r |cff888888Turn one back on with the buttons at the end of the row above.|r"] = "|cffffaa00Обе стороны выключены.|r |cff888888Включите одну кнопками в конце строки выше.|r",
	["|cff888888%s belongs to a linked family. Untick them as a sibling on the Wide Family panel to take them off this table.|r"] = "|cff888888%s принадлежит связанной семье. Снимите отметку родственника на панели Большой семьи, чтобы убрать его из этой таблицы.|r",
	["|cff9d9d9dNothing recorded yet. Family fills as you play each member - log in on one and its bags and money are written down.|r"] = "|cff9d9d9dПока ничего не записано. Family наполняется, пока вы играете за каждого - зайдите за одного, и его сумки и деньги будут записаны.|r",
	["|cff888888The currencies this family holds most of, most first.%s Character shows one member's in full, with what each is capped at.|r"] = "|cff888888Валюты, которых у этой семьи больше всего, сначала самые многочисленные.%s Персонаж показывает их для одного полностью, с пределом каждой.|r",
	["|cff888888Free and total slots leave out quivers, soul bags and the like: their slots are not room for anything else. Possessions shows them all the same.|r"] = "|cff888888Свободные и общие ячейки не учитывают колчаны, сумки душ и подобное: их ячейки не место для чего-то ещё. Имущество всё равно их показывает.|r",
	["|cffffd700Grand totals:|r  %d member   |cff888888|||r   %s   |cff888888|||r   %d of %d bag slots free   |cff888888|||r   |cff888888right-click a member to remove them|r"] = "|cffffd700Общий итог:|r  %d персонаж   |cff888888|||r   %s   |cff888888|||r   свободно %d из %d ячеек сумок   |cff888888|||r   |cff888888правый клик по персонажу удаляет его|r",
	["|cffffd700Grand totals:|r  %d members   |cff888888|||r   %s   |cff888888|||r   %d of %d bag slots free   |cff888888|||r   |cff888888right-click a member to remove them|r"] = "|cffffd700Общий итог:|r  персонажей: %d   |cff888888|||r   %s   |cff888888|||r   свободно %d из %d ячеек сумок   |cff888888|||r   |cff888888правый клик по персонажу удаляет его|r",
	["|cff888888Primary professions on the first line of each member, everything else on the second. A profession in grey has recipes Family has not seen for a week, or has never seen: ranks are always current, recipe lists are only as new as the last time that window was open.|r"] = "|cff888888Основные профессии в первой строке каждого персонажа, всё остальное во второй. Серая профессия имеет рецепты, которых Family не видел неделю или не видел вовсе: ранги всегда актуальны, а списки рецептов настолько свежи, насколько давно открывалось то окно.|r",
	["|cff888888Crafting cooldowns only - transmutes, mooncloth, salt shakers. A column appears once Family has seen that cooldown running at least once, because the client will not say a recipe has one while it is ready. Blank means never seen it, which is not the same as nought.%s|r"] = "|cff888888Только ремесленные восстановления - трансмутации, лунная ткань, солонки. Столбец появляется, когда Family хотя бы раз видел это восстановление идущим, потому что клиент не сообщает о нём, пока оно готово. Пусто означает «ни разу не видели», а это не то же самое, что ноль.%s|r",

	-- The Options panel
	["Options"] = "Настройки",  -- 20
	["compressed"] = "сжато",
	["not hooked"] = "не подключены",
	["uncompressed"] = "без сжатия",
	["Show the minimap button"] = "Показывать кнопку на миникарте",
	["Add Family to item tooltips"] = "Добавлять Family в подсказки предметов",
	["How far in front the window sits"] = "Насколько окно выступает вперёд",
	["Narrate what the scanners are doing"] = "Рассказывать, что делают сканеры",
	["Share gear and talents with your guild"] = "Делиться снаряжением и талантами с гильдией",
	["Raise this if another addon draws over Family."] = "Увеличьте, если другой аддон рисует поверх Family.",
	["Drag it around the edge of the minimap to move it."] = "Перетащите её по краю миникарты, чтобы переместить.",
	["Say which crafting cooldowns are ready when you log in"] = "При входе сообщать, какие ремесленные восстановления готовы",
	["In front of unit frames and most HUDs. The usual choice."] = "Перед рамками существ и большинством интерфейсов. Обычный выбор.",
	["Who owns one, and where it is - bags, bank, mail, auctions."] = "У кого он есть и где лежит - сумки, банк, почта, аукцион.",
	["Chat messages while Family records things. For working out faults."] = "Сообщения в чат, пока Family записывает. Для поиска неисправностей.",
	["Behind most things. Choose this if Family covers something it should not."] = "Позади большинства элементов. Выберите, если Family закрывает то, что не должно.",
	["|cff888888Family %s on %s   |||   tooltips hooked: %s   |||   storage: %s|r"] = "|cff888888Family %s на %s   |||   подсказки подключены: %s   |||   хранилище: %s|r",
	["In front of nearly everything, alongside the game's own popups. Choose this if a HUD still draws over Family."] = "Перед почти всем, наравне с окнами игры. Выберите, если интерфейс всё ещё рисует поверх Family.",
	["Transmutes, mooncloth, salt shakers. Crafting only - raid and heroic lockouts are a different thing and Family does not record them yet."] = "Трансмутации, лунная ткань, солонки. Только ремесло - привязки к рейдам и героикам это другое, и Family их пока не записывает.",
	["Both ways: what your guild sees of you, and what you see of them. Nothing else is shared - bags, mail and the rest need a Wide Family link."] = "В обе стороны: что гильдия видит о вас и что вы видите о ней. Больше ничего не передаётся - сумки, почта и прочее требуют связи Большой семьи.",

	-- The slash commands, and what /family says
	["go"] = "исчезла",
	["on"] = "вкл.",
	["off"] = "выкл.",
	["appear"] = "появилась",
	["item %s"] = "предмет %s",
	["%d ready"] = "готово: %d",
	["close it"] = "закрыть его",
	["debug %s"] = "отладка %s",
	["commands:"] = "команды:",
	["storage: %s"] = "хранилище: %s",
	["tooltips: %s"] = "подсказки: %s",
	["open the window"] = "открыть окно",
	["scanning %s ..."] = "сканирование %s ...",
	["|cff44dd44yes|r"] = "|cff44dd44да|r",
	["|cff888888no |r"] = "|cff888888нет |r",
	["version %s on %s"] = "версия %s на %s",
	["something unnamed"] = "нечто без имени",
	["%d member recorded"] = "Записан %d персонаж",
	["%d members recorded"] = "Записано персонажей: %d",
	["%s, interface build %s"] = "%s, сборка интерфейса %s",
	["|cffffaa00not hooked|r"] = "|cffffaa00не подключены|r",
	[" |cff888888(unvisited)|r"] = "  |cff888888(не посещена)|r",
	["  %s: %d in the guild bank"] = "    %s: %d в банке гильдии",
	["Wide Family is already %s."] = "Большая семья уже %s.",
	["  |cffffd700/family %s|r - %s"] = "    |cffffd700/family %s|r - %s",
	["  %s: |cffffaa00no payload|r%s"] = "    %s: |cffffaa00нет данных|r%s",
	["|cffff5555bag scan failed|r: %s"] = "|cffff5555не удалось просканировать сумки|r: %s",
	["no crafting cooldowns are ready."] = "готовых ремесленных восстановлений нет.",
	["     spec %d: |cffffaa00missing|r"] = "     спец %d: |cffffaa00отсутствует|r",
	["no command called |cffffd700%s|r."] = "нет команды |cffffd700%s|r.",
	["no strata called %s. Choices: %s."] = "нет слоя с именем %s. Варианты: %s.",
	["Guild share is now |cffffd700%s|r."] = "Общий доступ гильдии теперь |cffffd700%s|r.",
	["|cffff5555talent scan failed|r: %s"] = "|cffff5555не удалось просканировать таланты|r: %s",
	["narrate what the scanners are doing"] = "рассказывать, что делают сканеры",
	["open it if closed, close it if open"] = "открыть, если закрыто, закрыть, если открыто",
	["window strata is now |cffffd700%s|r."] = "слой окна теперь |cffffd700%s|r.",
	["item %d: %d member(s), %d guild bank(s)"] = "предмет %d: персонажей - %d, банков гильдии - %d",
	["which member? /family forget Name-Realm"] = "какого персонажа? /family forget Имя-Мир",
	["Guild share is currently |cffffd700%s|r."] = "Общий доступ гильдии сейчас |cffffd700%s|r.",
	["Wide Family is currently |cffffd700%s|r."] = "Большая семья сейчас |cffffd700%s|r.",
	["crafting cooldowns ready: |cff40bf40%s|r"] = "готовые ремесленные восстановления: |cff40bf40%s|r",
	["done. /family talents to see what landed."] = "готово. /family talents покажет, что записалось.",
	["forget a member: /family forget Name-Realm"] = "забыть персонажа: /family forget Имя-Мир",
	["what Family knows, and how it is storing it"] = "что знает Family и как это хранится",
	["  |cff44dd44%s|r: %s, %d group(s), active %d"] = "    |cff44dd44%s|r: %s, групп - %d, активна %d",
	["window strata is |cffffd700%s|r. Choices: %s."] = "слой окна |cffffd700%s|r. Варианты: %s.",
	["     spec %d: %d tier(s), %d chosen, spec id %s"] = "     спец %d: ярусов - %d, выбрано - %d, id спец. %s",
	["  %s: %d (bags %d, bank %d, mail %d, auction %d)"] = "    %s: %d (сумки %d, банк %d, почта %d, аукцион %d)",
	["Raise it if another addon draws over the window."] = "Увеличьте, если другой аддон рисует поверх окна.",
	["guild share on, off, or test: /family guild test"] = "общий доступ гильдии on, off или test: /family guild test",
	["what talent data is actually stored, and for whom"] = "какие данные о талантах действительно хранятся и для кого",
	["what this client answers when asked about a talent"] = "что отвечает этот клиент, когда его спрашивают о таланте",
	["  %s: payload present, |cffffaa00no talents in it|r"] = "    %s: данные есть, |cffffaa00талантов в них нет|r",
	["Wide Family, which is off by default: /family wide on"] = "Большая семья, по умолчанию выключена: /family wide on",
	["nobody holds one, so no tooltip block would be added."] = "ни у кого нет такого, поэтому блок в подсказке не добавится.",
	["what this client can do, and how Family worked it out"] = "что умеет этот клиент и как Family это определил",
	["which crafting cooldowns have come back, and for whom"] = "какие ремесленные восстановления вернулись и у кого",
	["how far in front the window sits: MEDIUM, HIGH or DIALOG"] = "насколько окно выступает вперёд: MEDIUM, HIGH или DIALOG",
	["scan the current member again, now, and say what it found"] = "просканировать текущего персонажа заново и сказать, что найдено",
	["     spec %d: %d point(s), %d tab(s), %d talent(s) ranked%s"] = "     спец %d: очков - %d, вкладок - %d, талантов с рангом - %d%s",
	["no member called %s. Names are as they appear in the summary."] = "нет персонажа с именем %s. Имена такие же, как в обзоре.",
	["check the possessions block for an item: /family tooltiptest 2589"] = "проверить блок имущества для предмета: /family tooltiptest 2589",
	["forgotten %s. This changes Family's records, nothing in the game."] = "%s забыт. Это меняет записи Family, но ничего в игре.",
	["this client uses talent trees; the probe is for the choices clients."] = "этот клиент использует деревья талантов; проба предназначена для клиентов с выбором.",
	["|cffffaa00uncompressed|r - LibSerialize and LibDeflate are not installed"] = "|cffffaa00без сжатия|r - LibSerialize и LibDeflate не установлены",
	["Wide Family is now |cffffd700%s|r. Type |cffffd700/reload|r for the panel to %s."] = "Большая семья теперь |cffffd700%s|r. Введите |cffffd700/reload|r, чтобы панель %s.",
	["give an item id, or shift-click an item link into chat and use the number from it."] = "укажите id предмета или зажмите Shift и щёлкните ссылку предмета в чате, взяв номер из неё.",
	["Nothing is shared with anybody until you link with them and tick what they may see."] = "Ни с кем ничего не передаётся, пока вы не свяжетесь и не отметите, что им можно видеть.",
	["|cffffaa00No member has talent data.|r Try /family rescan, then look at what it says."] = "|cffffaa00Ни у кого нет данных о талантах.|r Попробуйте /family rescan и посмотрите, что он скажет.",
	["|cffffd700/family wide on|r to switch it on, |cffffd700/family wide off|r to switch it back off."] = "|cffffd700/family wide on|r включает, |cffffd700/family wide off|r выключает обратно.",
	["|cffffd700/family guild off|r to stop, which stops both halves: Family then neither asks nor answers."] = "|cffffd700/family guild off|r останавливает обе половины: Family больше не спрашивает и не отвечает.",
	["|cff888888Crafting cooldowns only - transmutes, mooncloth, salt shakers. Raid and heroic lockouts are a different thing and are not recorded yet.|r"] = "|cff888888Только ремесленные восстановления - трансмутации, лунная ткань, солонки. Привязки к рейдам и героикам это другое и пока не записываются.|r",
	["|cffffd700/family guild test|r says what has actually crossed the wire. Run it on both clients and compare - the fault is wherever the two stop agreeing."] = "|cffffd700/family guild test|r показывает, что действительно прошло по каналу. Запустите на обоих клиентах и сравните - ошибка там, где они перестают совпадать.",
	["It lets two players link their families and share chosen members. Sharing is the one thing here a later version cannot take back, so it is off until you say otherwise rather than on until you notice."] = "Позволяет двум игрокам связать свои семьи и делиться выбранными персонажами. Обмен - единственное здесь, что более поздняя версия не сможет отменить, поэтому он выключен, пока вы не скажете иначе, а не включён, пока вы не заметите.",
	["It shows your guild the gear and talents of your characters in it, and shows you theirs. Nothing else - bags, mail and the rest need a Wide Family link. All of it is what the game already shows anybody who inspects you."] = "Показывает вашей гильдии снаряжение и таланты ваших персонажей в ней, а вам - их. Больше ничего: сумки, почта и прочее требуют связи Большой семьи. Всё это игра и так показывает любому, кто вас осматривает.",

	-- The manual Family carries with it
	["About"] = "О дополнении",  -- 20
	["Family"] = "Family",
	["Character"] = "Персонаж",  -- 20
	["Cooldowns"] = "Восстановления",
	["What it is"] = "Что это",
	["Guild share"] = "Общий доступ гильдии",
	["Wide Family"] = "Большая семья",  -- 20
	["About Family"] = "О Family",
	["Mail you send"] = "Почта, которую вы отправляете",
	["Opening Family"] = "Как открыть Family",
	["unknown client"] = "неизвестный клиент",
	["It starts empty"] = "Он начинается пустым",
	["The other money"] = "Другая валюта",
	["compressed storage"] = "сжатое хранилище",
	["Abilities & Talents"] = "Умения и таланты",  -- 20
	["uncompressed storage"] = "несжатое хранилище",
	["your |cffffd700mailbox|r"] = "ваш |cffffd700почтовый ящик|r",
	["On the game's own tooltips"] = "В подсказках самой игры",
	["What Family will not tell you"] = "Чего Family вам не скажет",
	["Three windows to open once each"] = "Три окна, каждое открыть по одному разу",
	["your |cffffd700bank|r, at any bank"] = "ваш |cffffd700банк|r, в любом банке",
	["%sversion %s   |||   %s   |||   %s|r"] = "%sверсия %s   |||   %s   |||   %s|r",
	["nothing at all is exchanged until they accept"] = "до их согласия не передаётся вообще ничего",
	["unticking a box tells them to forget it, at once"] = "снятие отметки просит их сразу это забыть",
	["right-click a member to remove them from the family"] = "правый клик по персонажу удаляет его из семьи",
	["left-click a profession to open that member's recipes"] = "левый клик по профессии открывает рецепты этого персонажа",
	["each |cffffd700profession|r window, for the recipes in it"] = "окно каждой |cffffd700профессии|r, ради рецептов в нём",
	["|cffffd700/family|r or |cffffd700/fam|r opens this window"] = "|cffffd700/family|r или |cffffd700/fam|r открывает это окно",
	["|cffffd700/family help|r lists everything that can be typed"] = "|cffffd700/family help|r перечисляет всё, что можно ввести",
	["both of you must be online: it is a snapshot, not a subscription"] = "оба должны быть в сети: это снимок, а не подписка",
	["linked members are kept separately and never mixed with your own"] = "связанные персонажи хранятся отдельно и никогда не смешиваются с вашими",
	["any data broker bar shows the same, with the family's money on it"] = "любая панель data broker показывает то же самое, с деньгами семьи",
	["Source, faults and suggestions: |cff66bbffhttps://github.com/uga/Family|r"] = "Исходный код, ошибки и предложения: |cff66bbffhttps://github.com/uga/Family|r",
	["Written from scratch by |cffffd700Alberto Pittaluga|r. Not a fork of anything."] = "Написан с нуля |cffffd700Alberto Pittaluga|r. Не форк чего-либо.",
	["nothing else is shared: bags, mail, money and the rest need a Wide Family link"] = "больше ничего не передаётся: сумки, почта, деньги и прочее требуют связи Большой семьи",
	["only their characters who are in this guild, and there is no way to add the others"] = "только их персонажи из этой гильдии, добавить остальных невозможно",
	["guildmates not running Family are invisible to it, which is the ordinary state of a guild"] = "соратники по гильдии без Family для него невидимы, и это обычное состояние гильдии",
	["the minimap button: left-click opens Family, right-click the options. Drag it around the edge to move it"] = "кнопка на миникарте: левый клик открывает Family, правый - настройки. Перетащите по краю, чтобы переместить",
	["Tick |cffffd700the whole family|r and the search looks through everybody at once, and says who has what it found."] = "Отметьте |cffffd700всю семью|r, и поиск пройдёт по всем сразу и скажет, у кого есть найденное.",
	["|cff9d9d9dAnything Family has not seen is reported as not seen, never as empty. Every screen says how old what it is showing is.|r"] = "|cff9d9d9dВсё, чего Family не видел, отмечается как не увиденное, а не как пустое. Каждый экран сообщает, насколько старо то, что он показывает.|r",
	["a request nobody answers is shown as unanswered, with the reasons it could be - the addon channel confirms nothing, so Family will not guess which"] = "запрос, на который никто не ответил, показывается как без ответа, с возможными причинами - канал аддонов ничего не подтверждает, поэтому Family не гадает",
	["Equipped gear laid out as the character sheet lays it out, with currencies, reputations, the quest log and achievements beside it. Clicking a quest opens it in the log."] = "Надетое снаряжение, разложенное так же, как на листе персонажа, рядом с валютой, репутацией, журналом заданий и достижениями. Щелчок по заданию открывает его в журнале.",
	["One member's bags, bank, mailbox, auctions and guild bank, drawn as the bags themselves. Clicking an item opens the bag it is in, when it is the character you are playing."] = "Сумки, банк, почтовый ящик, аукционы и банк гильдии одного персонажа, нарисованные как сами сумки. Щелчок по предмету открывает сумку, в которой он лежит, если это персонаж, которым вы играете.",
	["The talent trees as the game draws them, both specialisations where the character has two, the glyphs, and the spellbook. Hovering anything shows the game's own description of it."] = "Деревья талантов так, как их рисует игра, обе специализации, если у персонажа их две, символы и книга заклинаний. При наведении показывается описание самой игры.",
	["Professions that make nothing are not listed here; the summary has them and their level. |cffffd700The whole family|r searches every recipe of everybody: who can make this, who could learn it."] = "Профессии, которые ничего не создают, здесь не перечислены; они есть в обзоре вместе с уровнем. |cffffd700Вся семья|r ищет по всем рецептам каждого: кто может это сделать, кто мог бы выучить.",
	["Every member on one table, one line each. The buttons along the top change which columns are shown - money and bags, professions, quests, everything else - and each realm is totalled separately."] = "Все персонажи в одной таблице, по строке на каждого. Кнопки сверху меняют показанные столбцы - деньги и сумки, профессии, задания, всё остальное - и каждый мир суммируется отдельно.",
	["|cff9d9d9dIt needs no consent grid because all of it is what the game already shows anybody who inspects you. A dialogue in front of that would only teach people to click through the dialogues that matter.|r"] = "|cff9d9d9dЗдесь не нужна сетка согласия, потому что всё это игра и так показывает любому, кто вас осматривает. Диалог перед этим лишь научил бы людей прокликивать те диалоги, которые важны.|r",
	["Family remembers what each of your characters owns and knows, and shows it to you while you are logged in on a different one. Who has the mageweave, who can make the belt, which of them has a transmute ready."] = "Family запоминает, чем владеет и что умеет каждый ваш персонаж, и показывает это, пока вы играете за другого. У кого магическая ткань, кто может сделать пояс, у кого готова трансмутация.",
	["Family reports what your characters have and know. It does not advise. It will not tell you which recipes a member is still missing, which piece of gear to improve next, or where in the game an item can be found."] = "Family сообщает, что ваши персонажи имеют и знают. Он не советует. Он не скажет, каких рецептов персонажу ещё не хватает, какую вещь улучшать следующей и где в игре найти предмет.",
	["Hovering any item anywhere - a vendor, the auction house, the floor - adds who in the family has one and where it is. On a recipe it adds who can make it already, who can learn it today, and who is not high enough yet."] = "Наведение на любой предмет где угодно - у торговца, на аукционе, на земле - добавляет, у кого в семье он есть и где лежит. Для рецепта добавляется, кто уже может его сделать, кто может выучить сегодня, а кому пока не хватает уровня.",
	["Bags, money, gear, skills, talents and quests are read without being asked. Three things are only visible to the game while their window is open, so open each of them once per character and Family has them from then on:"] = "Сумки, деньги, снаряжение, навыки, таланты и задания читаются без запроса. Три вещи видны игре только пока открыто их окно, поэтому откройте каждое по разу на персонажа, и дальше Family их знает:",
	["Transmutes, mooncloth, salt shakers and the rest are recorded as the moment they come ready rather than as time remaining, so they stay right however long the client has been shut. Family says what is ready when you log in."] = "Трансмутации, лунная ткань, солонки и прочее записываются как момент готовности, а не как оставшееся время, поэтому остаются верными, сколько бы клиент ни был закрыт. Family сообщает о готовом при входе.",
	["Family imports nothing from anywhere. It records the character you are playing, as you play, and a character appears in it the first time you log in on them. A family of ten takes ten logins to be complete, and then stays complete on its own."] = "Family ниоткуда ничего не импортирует. Он записывает персонажа, которым вы играете, по ходу игры, и персонаж появляется при первом входе за него. Семье из десяти нужно десять входов, чтобы стать полной, а дальше она остаётся полной сама.",
	["On, and one tick box turns it off. Everyone in your guild running Family shows their characters' gear and both talent specialisations to everyone else running it, and you see theirs - including while they are offline, once you have seen them once."] = "Включено, и одна галочка это выключает. Все в вашей гильдии, кто пользуется Family, показывают снаряжение своих персонажей и обе специализации талантов всем остальным, кто им пользуется, а вы видите их - в том числе пока они не в сети, если вы их уже видели однажды.",
	["Honor and arena points, and on Mists everything else the client calls a currency, are recorded alongside gold. The summary totals the ones the family holds most of; Character shows one member's in full, with what each is capped at and how far off it is."] = "Очки чести и арены, а на Mists и всё прочее, что клиент называет валютой, записываются наряду с золотом. Обзор суммирует те, которых у семьи больше всего; Персонаж показывает их для одного полностью, с пределом каждой и тем, сколько до него осталось.",
	["What one member can make, sorted by what will skill them up, by what it is worth, or by what they will be able to make next. Clicking a recipe opens it in the profession window, opening the profession first if it is shut - for the character you are playing."] = "Что может создать один персонаж, отсортированное по тому, что поднимет навык, по стоимости или по тому, что он сможет создать дальше. Щелчок по рецепту открывает его в окне профессии, сначала открыв профессию, если она закрыта, - для персонажа, которым вы играете.",
	["A family need not be one account. Type another player's character name on the Wide Family panel and ask to link; they accept, and then each of you says what the other may see — one member and one category at a time, on a grid that starts with nothing ticked."] = "Семья не обязана быть одной учётной записью. Введите имя персонажа другого игрока на панели Большой семьи и попросите связаться; он соглашается, и затем каждый указывает, что другому можно видеть — по одному персонажу и одной категории за раз, на сетке, которая начинается без отметок.",
	["|cff9d9d9dNone of that is in the game client - where a thing comes from lives on the server - so an addon that answers it is reading a list somebody typed up outside the game, and cannot tell you how old that list is. Everything Family says, it says because the client said it.|r"] = "|cff9d9d9dНичего этого нет в клиенте игры - откуда берётся вещь, живёт на сервере - поэтому аддон, который на это отвечает, читает список, набранный кем-то вне игры, и не может сказать, насколько тот стар. Всё, что говорит Family, он говорит потому, что так сказал клиент.|r",
	["|cffffd700Whole family|r turns that gear the other way round: one row per member, their class and then every slot in the same order, with the item level over each icon. A character sheet says what one character is wearing; this says which of them is behind. Filters on realm and class."] = "|cffffd700Вся семья|r разворачивает это снаряжение: по строке на персонажа, его класс и затем каждый слот в том же порядке, с уровнем предмета над каждой иконкой. Лист персонажа говорит, что надето на одном; это говорит, кто отстаёт. Фильтры по миру и классу.",
	["|cff9d9d9dSwitched off by default, so there is no panel for it until you ask. Sharing is the one thing here a later version cannot take back, so it waits to be asked for rather than arriving switched on. To enable it: |cffffd700/family wide on|r|cff9d9d9d, then reload. Both of you need to.|r"] = "|cff9d9d9dПо умолчанию выключено, поэтому панели для этого нет, пока вы не попросите. Обмен - единственное здесь, что более поздняя версия не сможет отменить, поэтому он ждёт запроса, а не приходит включённым. Чтобы включить: |cffffd700/family wide on|r|cff9d9d9d, затем перезагрузите интерфейс. Это нужно сделать обоим.|r",
	["Among the members another family shares with you, tick the ones worth seeing every day and they become |cffffd700siblings|r: they appear in your summary, under their own family's name, on the realm they are on. Ticking sends nothing and asks nobody - they had already decided you may see them."] = "Среди персонажей, которыми с вами делится другая семья, отметьте тех, кого стоит видеть каждый день, и они станут |cffffd700родственниками|r: они появятся в вашем обзоре, под именем своей семьи, на мире, где находятся. Отметка ничего не отправляет и никого не спрашивает - они уже решили, что вам можно их видеть.",
	["Free software under the |cffffd700GNU General Public License, version 3 or later|r. You may use, study, change and pass it on; a changed version has to carry the same licence and say what was changed. Nobody can take Family closed, including if this project is ever abandoned - which is why that licence."] = "Свободное программное обеспечение под |cffffd700GNU General Public License, версия 3 или новее|r. Вы можете использовать, изучать, изменять и передавать его; изменённая версия должна нести ту же лицензию и указывать, что было изменено. Никто не может сделать Family закрытым, в том числе если этот проект когда-нибудь забросят, - потому и такая лицензия.",
	["Post anything to one of your own characters and it is written down against them at once - the money, the attachments and all - so their row is right before they have logged in. It is marked as being |cffffd700in the post|r until that character opens their own mailbox, and then what is really in it replaces the guess."] = "Отправьте что-нибудь одному из своих персонажей, и это сразу запишется за ним - деньги, вложения и всё остальное - так что его строка верна ещё до его входа. Это помечено как |cffffd700в пути|r, пока персонаж не откроет свой почтовый ящик, и тогда догадку заменит то, что там на самом деле.",
	["|cff9d9d9dExchanges happen when a linked family comes online, when you change what is shared, and whenever you press Update. Nothing is sent as you log out - the client is already leaving by then and it would not arrive. The first two are one tick box and can be switched off; Update always works, and unticking a box is always sent at once.|r"] = "|cff9d9d9dОбмены происходят, когда связанная семья входит в сеть, когда вы меняете то, чем делитесь, и каждый раз при нажатии Обновить. При выходе ничего не отправляется - клиент уже уходит, и это не дойдёт. Первые два - одна галочка, их можно выключить; Обновить работает всегда, а снятие отметки всегда отправляется сразу.|r",

	-- Abilities & Talents
	["Spec"] = "Спец",
	["Glyphs"] = "Символы",
	["Spec %d"] = "Спец %d",
	["Tree %d"] = "Ветвь %d",
	["Spell #%s"] = "Заклинание №%s",
	["Spellbook"] = "Книга закл.",
	[" |cff888888- %s|r"] = " |cff888888- %s|r",
	["|cff40bf40taken|r"] = "|cff40bf40взят|r",
	["Specialisation #%s"] = "Специализация №%s",
	["  spec %d: %s -> %s"] = "  спец %d: %s -> %s",
	["|cff888888tier %d|r"] = "|cff888888ярус %d|r",
	[" |cff40bf40(active)|r"] = " |cff40bf40(активна)|r",
	["|cff9d9d9dpassed over|r"] = "|cff9d9d9dпропущен|r",
	["|cff9d9d9dnone recorded|r"] = "|cff9d9d9dничего не записано|r",
	[" |cff40bf40(%d to spend)|r"] = " |cff40bf40(%d не потрачено)|r",
	["%d abilities in %d schools"] = "%d способностей в %d школах",
	["|cff9d9d9dnothing chosen|r"] = "|cff9d9d9dничего не выбрано|r",
	["|cffffd700%d|r point spent"] = "потрачен |cffffd700%d|r очко",
	["|cffffd700%d|r points spent"] = "потрачено очков: |cffffd700%d|r",
	["talent readers available: %d"] = "доступных читателей талантов: %d",
	["%s%s   |cff888888|||r   seen %s"] = "%s%s   |cff888888|||r   замечено %s",
	["|cffffd700%d|r of %d point spent"] = "потрачено |cffffd700%d|r из %d очка",
	["|cffffd700%d|r of %d points spent"] = "потрачено |cffffd700%d|r из %d очков",
	["  %s [1,%d] -> %s |cff888888=> %s|r"] = "  %s [1,%d] -> %s |cff888888=> %s|r",
	["   |cff888888|||r   specialisation %d of %d%s"] = "   |cff888888|||r   специализация %d из %d%s",
	["|cff9d9d9dNever activated - nothing recorded.|r"] = "|cff9d9d9dНи разу не активировалась - ничего не записано.|r",
	["|cffffaa00Nothing recorded for this specialisation.|r"] = "|cffffaa00Для этой специализации ничего не записано.|r",
	["|cff88bbff%s|r%s   |cff888888|||r   one talent a tier%s   |cff888888|||r   seen %s"] = "|cff88bbff%s|r%s   |cff888888|||r   один талант на ярус%s   |cff888888|||r   замечено %s",
	["|cffffaa00no talent grid could be read on this client.|r Please report what |cffffd700/family talentprobe|r prints."] = "|cffffaa00На этом клиенте не удалось прочитать сетку талантов.|r Пожалуйста, сообщите, что выводит |cffffd700/family talentprobe|r.",
	["|cffffaa00no talent data could be read on this client|r (%s, %d group(s)). Please report this with /family caps, and with /family talentprobe if it says choices."] = "|cffffaa00На этом клиенте не удалось прочитать данные о талантах|r (%s, групп: %d). Пожалуйста, сообщите об этом с /family caps и с /family talentprobe, если он говорит choices.",

	-- Possessions
	["Bank"] = "Банк",
	["Bag %d"] = "Сумка %d",
	["%d bags"] = "%d в сумках",
	["%d bank"] = "%d в банке",
	["%d mail"] = "%d в почте",
	["Keyring"] = "Связка ключей",
	["bags %s"] = "сумки %s",
	["bank %s"] = "банк %s",
	["mail %s"] = "почта %s",
	["Backpack"] = "Рюкзак",
	["%d auction"] = "%d на аукционе",
	["Bank bag %d"] = "Банковская сумка %d",
	["auctions %s"] = "аукционы %s",
	["|cffff8040Mail|r"] = "|cffff8040Почта|r",
	["dim everything but"] = "затемнить всё, кроме",
	["|cff88bbff(bank)|r"] = "|cff88bbff(банк)|r",
	["|cffffd700Auctions|r"] = "|cffffd700Аукционы|r",
	["%s |cff888888tab %d|r"] = "%s |cff888888вкладка %d|r",
	["find across the family"] = "искать по всей семье",
	["|cff40c040Guild bank|r"] = "|cff40c040Банк гильдии|r",
	["|cff888888guild bank|r"] = "|cff888888банк гильдии|r",  -- 33
	["%s |cff888888%d letter|r"] = "%s |cff888888%d письмо|r",
	["%s |cff888888%d letters|r"] = "%s |cff888888писем: %d|r",
	["|cff888888%d of %d free|r"] = "|cff888888%d из %d свободно|r",
	["|cff9d9d9dbags not seen|r"] = "|cff9d9d9dсумки не просмотрены|r",
	["|cff9d9d9dbank not seen|r"] = "|cff9d9d9dбанк не просмотрен|r",
	["|cff9d9d9dmail not seen|r"] = "|cff9d9d9dпочта не просмотрена|r",
	["  |cffffd700%d in the post|r"] = "  |cffffd700%d в пути|r",
	["|cff9d9d9dauctions not seen|r"] = "|cff9d9d9dаукционы не просмотрены|r",
	["   |cff9d9d9d- nothing to show yet|r"] = "   |cff9d9d9d- пока нечего показать|r",
	["|cffffaa00only its own kind of thing fits here|r"] = "|cffffaa00сюда помещается только свой тип вещей|r",
	["|cff9d9d9dNothing named like \"%s\" is held by anybody.|r"] = "|cff9d9d9dНи у кого нет ничего с названием вроде \"%s\".|r",
	["|cff9d9d9dSearching the whole family. Type at least two letters in the box above to see who has what.|r"] = "|cff9d9d9dПоиск по всей семье. Введите хотя бы две буквы в поле выше, чтобы увидеть, у кого что есть.|r",
	["|cffffd700%d|r line for \"%s\" across the family   |cff888888|||r   |cff888888only items the client has named can be matched|r"] = "|cffffd700%d|r строка по \"%s\" во всей семье   |cff888888|||r   |cff888888сопоставить можно только предметы, названные клиентом|r",
	["|cffffd700%d|r lines for \"%s\" across the family   |cff888888|||r   |cff888888only items the client has named can be matched|r"] = "|cffffd700%d|r строк по \"%s\" во всей семье   |cff888888|||r   |cff888888сопоставить можно только предметы, названные клиентом|r",

	-- Professions
	["grey"] = "серый",
	["green"] = "зелёный",
	["orange"] = "оранжевый",
	["yellow"] = "жёлтый",
	["Difficulty"] = "Сложность",
	["Item level"] = "Уровень предмета",
	["Skill needed"] = "Нужный навык",
	["search recipes"] = "искать рецепты",
	["%s make nothing"] = "%s ничего не создают",
	["%s never opened"] = "%s ни разу не открывались",
	["|cffffd700Sort by|r"] = "|cffffd700Сортировать по|r",
	["|cffff8040ready %s|r"] = "|cffff8040готово %s|r",
	["|cff40bf40ready now|r"] = "|cff40bf40готово сейчас|r",  -- 38
	["|cff40bf40can make %s|r"] = "|cff40bf40может создать %s|r",
	["|cff9d9d9dNothing recorded for this member.|r"] = "|cff9d9d9dДля этого персонажа ничего не записано.|r",
	["|cff9d9d9dNo member has any profession recorded yet.|r"] = "|cff9d9d9dНи у кого пока не записана ни одна профессия.|r",
	["Hardest first, then by the item level of what it makes."] = "Сначала самые сложные, затем по уровню создаваемого предмета.",
	["|cffffd700%d|r recipe named like \"%s\", and who can make it"] = "|cffffd700%d|r рецепт с названием вроде \"%s\" и кто может его создать",
	["|cff9d9d9dNothing this member has recorded makes anything.|r"] = "|cff9d9d9dНичто из записанного для этого персонажа ничего не создаёт.|r",
	["|cffffd700%d|r recipes named like \"%s\", and who can make each"] = "|cffffd700%d|r рецептов с названием вроде \"%s\" и кто может создать каждый",
	["|cff9d9d9dNobody in the family knows a recipe named like \"%s\".|r"] = "|cff9d9d9dНикто в семье не знает рецепта с названием вроде \"%s\".|r",
	["By the skill each one needs. Not yet known for every recipe - see below."] = "По навыку, который нужен каждому. Известен пока не для всех рецептов - см. ниже.",
	["Not listed: %s.  Summary / Professions has every profession and its level."] = "Не перечислено: %s.  Обзор / Профессии содержит каждую профессию и её уровень.",
	["Hardest first. Within a colour, the ones that took the most skill to learn."] = "Сначала самые сложные. Внутри цвета - те, что требовали больше навыка при изучении.",
	["|cffffd700%s|r %s   |cff888888|||r   %d recipes  %s   |cff888888|||r   seen %s"] = "|cffffd700%s|r %s   |cff888888|||r   рецептов: %d  %s   |cff888888|||r   замечено %s",
	["%s were recorded in another language - log in on this character to refresh them"] = "%s записаны на другом языке - зайдите за этого персонажа, чтобы обновить их",
	["|cff9d9d9dSearching every profession of every member. Type at least two letters in the box above.|r"] = "|cff9d9d9dПоиск по каждой профессии каждого персонажа. Введите хотя бы две буквы в поле выше.|r",
	["|cffffd700%s|r is waiting. Click |cffffd700%s|r above to open the window and it will be selected there."] = "|cffffd700%s|r ждёт. Нажмите |cffffd700%s|r выше, чтобы открыть окно, и рецепт будет там выбран.",

	-- Character
	["Held"] = "Имеется",
	["Class"] = "Класс",  -- 16
	["Level"] = "Ур.",  -- 7
	["Quest"] = "Задание",
	["Realm"] = "Мир",  -- 21
	["filter"] = "фильтр",
	["Faction"] = "Фракция",  -- 26
	["Category"] = "Категория",  -- 26
	["Currency"] = "Валюта",  -- 26
	["Progress"] = "Прогресс",  -- 21
	["Standing"] = "Отношение",
	["%s points"] = "%s очк.",
	["Achievement"] = "Logro",
	["Category %s"] = "Категория %s",
	["Of a cap of"] = "Из максимума",  -- 21
	["standing %s"] = "отношение %s",
	["Achievements"] = "Достижения",  -- 15
	["Currency #%s"] = "Валюта №%s",
	["Whole family"] = "Вся семья",  -- 16
	["Equipped gear"] = "Экипировка",  -- 15
	["another family"] = "другая семья",
	["Achievement #%s"] = "Достижение №%s",
	["%d of %d factions"] = "%d из %d фракций",
	["|cff888888Other|r"] = "|cff888888Прочее|r",
	["|cff888888of %s|r"] = "|cff888888из %s|r",
	["|cff9d9d9dempty|r"] = "|cff9d9d9dпусто|r",
	["Average item level"] = "Средний уровень предметов",
	["Points or progress"] = "Очки/прогресс",  -- 21
	["|cff40bf40earned|r"] = "|cff40bf40получено|r",
	["|cff9d9d9dno cap|r"] = "|cff9d9d9dбез предела|r",  -- 21
	["|cffffd700%d|r of %d"] = "|cffffd700%d|r из %d",
	["|cff40bf40%d|r points"] = "|cff40bf40%d|r очк.",
	["|cff9d9d9dnot recorded|r"] = "|cff9d9d9dне записано|r",
	["|cff888888level %s|r  %s  %s"] = "|cff888888уровень %s|r  %s  %s",
	["|cff888888level %s|r  %s%s|r"] = "|cff888888уровень %s|r  %s%s|r",
	["%s%s|r  |cff888888(%s to go)|r"] = "%s%s|r  |cff888888(осталось %s)|r",
	["|cffffaa00Nothing matches those filters.|r"] = "|cffffaa00Ничто не подходит под эти фильтры.|r",
	["|cff9d9d9dThis client has no achievements.|r"] = "|cff9d9d9dУ этого клиента нет достижений.|r",
	["|cffffaa00Nothing recorded for this member.|r"] = "|cffffaa00Для этого персонажа ничего не записано.|r",
	["average item level |cffffd700%s|r over %d pieces"] = "средний уровень предметов |cffffd700%s|r по %d вещам",
	["|cffffd700%d|r currency   |cff888888|||r   seen %s"] = "|cffffd700%d|r валюта   |cff888888|||r   замечено %s",
	["|cffffd700%d|r currencies   |cff888888|||r   seen %s"] = "|cffffd700%d|r валют   |cff888888|||r   замечено %s",
	["|cffffaa00Nothing recorded - log in on this member once.|r"] = "|cffffaa00Ничего не записано - зайдите за этого персонажа один раз.|r",
	["|cffffaa00Nothing recorded for this member - log in on them once.|r"] = "|cffffaa00Для этого персонажа ничего не записано - зайдите за него один раз.|r",
	["|cff9d9d9dThis client offers no currencies, or this member has never held one.|r"] = "|cff9d9d9dЭтот клиент не предлагает валют, или у этого персонажа их никогда не было.|r",
	["|cffffd700%d|r points from %d achievements   |cff888888|||r   %d shown   |cff888888|||r   seen %s"] = "|cffffd700%d|r очков из %d достижений   |cff888888|||r   показано %d   |cff888888|||r   замечено %s",
	["|cffffd700%d|r of %d member   |cff888888|||r   %d with gear recorded   |cff888888|||r   |cff888888hover the class picture for who they are, and any slot for what is in it|r"] = "|cffffd700%d|r из %d персонажа   |cff888888|||r   %d со снаряжением   |cff888888|||r   |cff888888наведите на изображение класса, чтобы узнать, кто это, и на слот, чтобы увидеть содержимое|r",
	["|cffffd700%d|r of %d members   |cff888888|||r   %d with gear recorded   |cff888888|||r   |cff888888hover the class picture for who they are, and any slot for what is in it|r"] = "|cffffd700%d|r из %d персонажей   |cff888888|||r   %d со снаряжением   |cff888888|||r   |cff888888наведите на изображение класса, чтобы узнать, кто это, и на слот, чтобы увидеть содержимое|r",

	-- Quests
	["easy"] = "легко",
	["hard"] = "сложно",
	[" of %s"] = " из %s",
	["normal"] = "обычно",
	["trivial"] = "тривиально",
	["Elsewhere"] = "В другом месте",
	["very hard"] = "очень сложно",
	["|cffffd700%d|r quest"] = "|cffffd700%d|r задание",
	["|cffffd700%d|r quests"] = "заданий: |cffffd700%d|r",
	["|cff40bf40ready to hand in|r"] = "|cff40bf40готово к сдаче|r",
	["|cff40bf40%d ready to hand in|r"] = "|cff40bf40готово к сдаче: %d|r",
	["|cff9d9d9dnothing ready to hand in|r"] = "|cff9d9d9dсдавать нечего|r",
	["%s   |cff888888|||r   %s   |cff888888|||r   seen %s"] = "%s   |cff888888|||r   %s   |cff888888|||r   замечено %s",

	-- Wide Family
	["Mail"] = "Почта",  -- 10
	["Money"] = "Деньги",  -- 22
	["never"] = "никогда",
	["Accept"] = "Принять",  -- 10
	["Forget"] = "Забыть",  -- 10
	["Quests"] = "Задания",  -- 15
	["Unlink"] = "Отвязать",  -- 10
	["Decline"] = "Отклонить",  -- 10
	["Talents"] = "Таланты",
	["Auctions"] = "Аукцион",  -- 10
	["Ask again"] = "Ещё раз",  -- 10
	["Equipment"] = "Экипировка",
	["Family %s"] = "Family %s",
	["%d category"] = "%d категория",
	["Ask to link"] = "Связаться",  -- 15
	["Possessions"] = "Имущество",  -- 20
	["Professions"] = "Профессии",  -- 14
	["Reputations"] = "Репутация",  -- 15
	["no such link"] = "такой связи нет",
	["%d categories"] = "категорий: %d",
	["Could not: %s"] = "Не удалось: %s",
	["no such request"] = "такого запроса нет",
	["version unknown"] = "версия неизвестна",
	["|cffffd700Member|r"] = "|cffffd700Персонаж|r",
	["|cff888888level %s|r"] = "|cff888888уровень %s|r",
	["|cff9d9d9das of %s|r"] = "|cff9d9d9dна %s|r",
	["|cffffd700%d|r member"] = "|cffffd700%d|r персонаж",
	["|cffffd700%d|r members"] = "персонажей: |cffffd700%d|r",
	["%s |cff888888asked %s|r"] = "%s |cff888888запрошено %s|r",
	["|cffffd700%d|r category"] = "|cffffd700%d|r категория",
	["   |cffffaa00no answer|r"] = "   |cffffaa00нет ответа|r",
	["not waiting on that name"] = "этого имени никто не ждёт",
	["%s |cff888888asked %s|r%s"] = "%s |cff888888запрошено %s|r%s",
	["|cffffd700%d|r categories"] = "категорий: |cffffd700%d|r",
	["a character name is needed"] = "нужно имя персонажа",
	["|cffffd700Sibling  Member|r"] = "|cffffd700Родств.  Перс.|r",
	["|cffffd700%d|r linked family"] = "|cffffd700%d|r связанная семья",
	["|cffffaa00Could not ask: %s|r"] = "|cffffaa00Не удалось запросить: %s|r",
	["Wide Family is not switched on"] = "Большая семья не включена",
	["|cffffd700%d|r linked families"] = "связанных семей: |cffffd700%d|r",
	["   |||   click the name to open"] = "   |||   нажмите на имя, чтобы открыть",
	["none of %s's %d character is online"] = "у %s ни один из %d персонажа не в сети",
	["|cffffd700What %s shares with you|r"] = "|cffffd700Чем %s делится с вами|r",
	["none of %s's %d characters are online"] = "у %s ни один из %d персонажей не в сети",
	["|cffffd700Waiting for you to answer|r"] = "|cffffd700Ожидает вашего ответа|r",
	["|cffffd700Waiting for them to answer|r"] = "|cffffd700Ожидает их ответа|r",
	["Sent %d member(s) and asked for theirs."] = "Отправлено персонажей: %d, запрошены их.",
	["nobody of theirs has ever been heard from"] = "ни от кого из них ничего не приходило",
	["|cff888888%s is not online - trying %s.|r"] = "|cff888888%s не в сети - пробуем %s.|r",
	["|cffffd700What %s may see of your characters|r"] = "|cffffd700Что %s может видеть о ваших персонажах|r",
	["|cff9d9d9dThey say which categories they share.|r"] = "|cff9d9d9dОни сообщают, какими категориями делятся.|r",
	["%s   |cff888888|||r   you are sharing %s across %s"] = "%s   |cff888888|||r   вы делитесь: %s в %s",
	["Asked |cffffd700%s|r to link. Nothing has been sent."] = "|cffffd700%s|r отправлен запрос на связь. Ничего не передано.",
	["|cffffaa00%s's Family speaks a different version - %s|r"] = "|cffffaa00Family у %s другой версии - %s|r",
	["Exchange automatically when a linked family comes online"] = "Обмениваться автоматически, когда связанная семья входит в сеть",
	["|cff9d9d9d   - they are offline, or not running Family|r"] = "|cff9d9d9d   - они не в сети или без Family|r",
	["|cff9d9d9d   - their Family is too old to know how to answer|r"] = "|cff9d9d9d   - их Family слишком старый, чтобы ответить|r",
	["|cff9d9d9dClick to tick or clear this column for all %d member.|r"] = "|cff9d9d9dНажмите, чтобы отметить или снять этот столбец для %d персонажа.|r",
	["|cffffd700%s|r has ended the link. Their data has been forgotten."] = "|cffffd700%s|r разорвал связь. Их данные забыты.",
	["|cff9d9d9dClick to tick or clear this column for all %d members.|r"] = "|cff9d9d9dНажмите, чтобы отметить или снять этот столбец для всех %d персонажей.|r",
	["Linked with |cffffd700%s|r. Nothing is shared until you say what may be."] = "Связь с |cffffd700%s|r установлена. Ничего не передаётся, пока вы не укажете, что можно.",
	["|cff9d9d9dWhether they share this. Their decision, taken on their own panel.|r"] = "|cff9d9d9dДелятся ли они этим. Их решение, принятое на их панели.|r",
	["|cff888888you share %s in %s   |||   they share %d with you   |||   last exchange %s%s|r"] = "|cff888888вы делитесь: %s в %s   |||   они делятся с вами: %d   |||   последний обмен %s%s|r",
	["|cffffd700%s|r would like to link families. Open Family, Wide Family, to accept or decline."] = "|cffffd700%s|r хочет связать семьи. Откройте Family, Большая семья, чтобы принять или отклонить.",
	["|cffffaa00Their Family is too old to say what it grants, so the marks are what has arrived.|r"] = "|cffffaa00Их Family слишком старый, чтобы сообщить, что он даёт, поэтому отметки - это то, что пришло.|r",
	["|cffffaa00None of %s's %d character is online.|r Nothing was sent. Try again when one of them is."] = "|cffffaa00У %s ни один из %d персонажа не в сети.|r Ничего не отправлено. Попробуйте, когда кто-то будет в сети.",
	["|cffffaa00None of %s's %d characters are online.|r Nothing was sent. Try again when one of them is."] = "|cffffaa00У %s ни один из %d персонажей не в сети.|r Ничего не отправлено. Попробуйте, когда кто-то будет в сети.",
	["|cff9d9d9dA request that does not arrive says nothing at all. No answer means one of three things:|r"] = "|cff9d9d9dЗапрос, который не дошёл, не говорит ни о чём. Отсутствие ответа означает одно из трёх:|r",
	["|cff9d9d9d   - the two of you cannot exchange addon messages at all, which no addon can work around|r"] = "|cff9d9d9d   - вы вдвоём вообще не можете обмениваться сообщениями аддонов, и ни один аддон это не обойдёт|r",
	["|cff9d9d9dNo families are linked yet. %d request sent and not answered - a link exists only once they accept.|r"] = "|cff9d9d9dСвязанных семей пока нет. Отправлен %d запрос без ответа - связь появляется только после согласия.|r",
	["|cff9d9d9dNo families are linked yet. %d requests sent and not answered - a link exists only once they accept.|r"] = "|cff9d9d9dСвязанных семей пока нет. Отправлено запросов без ответа: %d - связь появляется только после согласия.|r",
	["|cff9d9d9dNothing yet. They choose this from their own Wide Family panel, and it arrives at the next exchange.|r"] = "|cff9d9d9dПока ничего. Они выбирают это на своей панели Большой семьи, и это придёт при следующем обмене.|r",
	["|cffffaa00the wide family grid needs %d pixels for %d categories and a row is %d, so its last column is drawn off the end|r"] = "|cffffaa00сетке Большой семьи нужно %d пикселей на %d категорий, а в строке %d, поэтому последний столбец рисуется за краем|r",
	["They must be online, and running Family. Nothing is sent until they accept, and nothing is shared until you say what may be."] = "Они должны быть в сети и с Family. Ничего не отправляется, пока они не согласятся, и ничего не передаётся, пока вы не укажете, что можно.",
	["End the link with %s?\n\nWhat they have shared with you is forgotten here, and they are asked to forget what you shared with them."] = "Разорвать связь с %s?\n\nТо, чем они делились с вами, будет забыто здесь, и их попросят забыть то, чем делились вы.",
	["|cff9d9d9dNo families are linked. Type a character name above and ask - they will be asked to accept, and nothing is sent before they do.|r"] = "|cff9d9d9dСвязанных семей нет. Введите имя персонажа выше и запросите - их спросят о согласии, и до этого ничего не отправляется.|r",
	["|cff888888Nothing is ticked to begin with, and unticking tells them to forget it. Click a category's name to tick or clear that column for everybody at once.|r"] = "|cff888888Изначально ничего не отмечено, а снятие отметки просит их забыть это. Нажмите на название категории, чтобы отметить или снять весь столбец сразу.|r",
	["|cffffaa00Wide Family needs the serialisation libraries (LibSerialize and LibDeflate) and this client has neither loaded, so nothing can be sent or received.|r"] = "|cffffaa00Большой семье нужны библиотеки сериализации (LibSerialize и LibDeflate), а на этом клиенте не загружена ни одна, поэтому ничего нельзя отправить или получить.|r",
	["That is the only time it happens on its own. What you each see of the other is as it was at the last exchange - click |cffffd700Update now|r on a family's line to bring it up to date."] = "Только в этот момент это происходит само. То, что вы видите друг о друге, - это состояние на момент последнего обмена: нажмите |cffffd700Обновить|r в строке семьи, чтобы обновить.",
	["|cff888888Family sends only what is ticked, and asks the other side to forget anything you untick. That last part is a request to another copy of Family on somebody else's computer - it is a promise kept honestly here, not a lock.|r"] = "|cff888888Family отправляет только отмеченное и просит другую сторону забыть то, что вы сняли. Последнее - это просьба к другой копии Family на чужом компьютере: обещание, честно исполняемое здесь, а не замок.|r",
	["|cff888888The marks are what they share about each one - theirs to change, not yours. Tick |cffffd700Sibling|r to put one in your own summary, under their family, on the realm they are on. That sends nothing: they have already shared them.|r"] = "|cff888888Отметки - это то, чем они делятся о каждом: менять их им, не вам. Отметьте |cffffd700Родственник|r, чтобы поместить персонажа в свой обзор, под их семьёй, на мире, где он находится. Это ничего не отправляет: они уже поделились.|r",

	-- Guild
	["Guild"] = "Гильдия",  -- 20
	["unknown"] = "неизвестно",
	["Everyone"] = "Все",
	["Update now"] = "Обновить",  -- 10
	["  guild: %s"] = "  гильдия: %s",
	["Online only"] = "Только в сети",
	["not in a guild"] = "не состоит в гильдии",
	["  switched on: %s"] = "  включено: %s",
	["specialisation #%s"] = "специализация №%s",
	["  can serialise: %s"] = "  может сериализовать: %s",
	["  |cff888888(you)|r"] = "  |cff888888(вы)|r",
	["  |cff777777offline|r"] = "  |cff777777не в сети|r",
	["|cffffaa00Could not: %s|r"] = "|cffffaa00Не удалось: %s|r",
	["Guild share is switched off"] = "Общий доступ гильдии выключен",
	["|cff9d9d9dno gear recorded|r"] = "|cff9d9d9dснаряжение не записано|r",
	["  addon prefix registered: %s"] = "  префикс аддона зарегистрирован: %s",
	["  messages sent from here: %d"] = "  сообщений отправлено отсюда: %d",
	["|cffffd700Guild share|r on %s"] = "|cffffd700Общий доступ гильдии|r на %s",
	["  characters of ours in it: %d"] = "  наших персонажей в ней: %d",
	["|cff555555not running Family|r"] = "|cff555555без Family|r",  -- 30
	["|cff9d9d9dno talents recorded|r"] = "|cff9d9d9dталанты не записаны|r",
	["nothing of ours is in this guild"] = "ничего нашего нет в этой гильдии",
	["this character is not in a guild"] = "этот персонаж не состоит в гильдии",
	["|cffffd700%.1f|r |cff888888ilvl|r"] = "|cffffd700%.1f|r |cff888888ур. пред.|r",
	["  characters held for this guild: %d"] = "  персонажей хранится для этой гильдии: %d",
	["  announcements from somebody else: %s"] = "  объявления от кого-то ещё: %s",
	["|cff888888heard from, nothing sent yet|r"] = "|cff888888слышно, ничего не отпр.|r",  -- 30
	["click one of them to see their characters"] = "нажмите на кого-нибудь, чтобы увидеть его персонажей",
	["Share gear and talents with the guild, and read theirs"] = "Делиться снаряжением и талантами с гильдией и читать их",
	["Asked the guild. Whoever is online and running Family answers."] = "Гильдия опрошена. Отвечает тот, кто в сети и с Family.",
	["|cffffd700%s|r |cff888888ilvl   |||   %d character   |||   %s|r"] = "|cffffd700%s|r |cff888888ур. пред.   |||   %d персонаж   |||   %s|r",
	["|cffffd700%s|r |cff888888ilvl   |||   %d characters   |||   %s|r"] = "|cffffd700%s|r |cff888888ур. пред.   |||   персонажей: %d   |||   %s|r",
	["this client has no serialisation libraries, so nothing can be sent"] = "на этом клиенте нет библиотек сериализации, поэтому ничего нельзя отправить",
	["  |cffffaa00last one was for %s, and this client calls the guild %s|r"] = "  |cffffaa00последнее было для %s, а этот клиент называет гильдию %s|r",
	["  announcements arrived: %d  (%d ours coming back, %d for another guild, %d unreadable)"] = "  получено объявлений: %d  (%d наших вернулось, %d для другой гильдии, %d нечитаемых)",
	["nobody else has answered yet - they must be online and running it, and Update now asks again"] = "больше никто не ответил - они должны быть в сети и с ним, а Обновить спросит снова",
	["|cff9d9d9dNobody to show. The guild roster arrives a moment after the panel does - try Update now.|r"] = "|cff9d9d9dНекого показать. Список гильдии приходит чуть позже панели - попробуйте Обновить.|r",
	["|cffffd700%s|r   |cff888888|||r   %d shown of %d   |cff888888|||r   |cffffd700%d|r running Family   |cff888888|||r   |cff888888%s|r"] = "|cffffd700%s|r   |cff888888|||r   показано %d из %d   |cff888888|||r   |cffffd700%d|r с Family   |cff888888|||r   |cff888888%s|r",
	["|cff9d9d9dThis character is not in a guild. Guild share is about one guild on one realm, so there is nothing for it to be about from here.|r"] = "|cff9d9d9dЭтот персонаж не состоит в гильдии. Общий доступ гильдии касается одной гильдии на одном мире, поэтому отсюда ему нечего касаться.|r",
	["|cffffaa00Guild share is switched off.|r |cff888888Nothing is sent to %s and nothing that arrives is read. What was collected before is kept.|r"] = "|cffffaa00Общий доступ гильдии выключен.|r |cff888888Ничего не отправляется в %s и ничего входящего не читается. Собранное ранее сохраняется.|r",
	["|cffffaa00Guild share needs the serialisation libraries (LibSerialize and LibDeflate) and this client has neither loaded, so nothing can be sent or received.|r"] = "|cffffaa00Общему доступу гильдии нужны библиотеки сериализации (LibSerialize и LibDeflate), а на этом клиенте не загружена ни одна, поэтому ничего нельзя отправить или получить.|r",
	["|cffffaa00This client has sent and heard nothing at all, not even its own announcement coming back off the guild channel. That points at the channel rather than at either end.|r"] = "|cffffaa00Этот клиент вообще ничего не отправил и не услышал, даже собственного объявления, возвращающегося по каналу гильдии. Это указывает на канал, а не на одну из сторон.|r",

	-- The minimap button and its tooltip
	["%d member"] = "%d персонаж",
	["%d members"] = "Персонажей: %d",
	["|cff888888money|r"] = "|cff888888деньги|r",
	["  %s |cff888888(%d)|r"] = "",
	["|cffffd700All realms|r"] = "|cffffd700Все миры|r",
	["|cffff4444Mail expiring soon|r"] = "|cffff4444Почта скоро истечёт|r",
	["|cff9d9d9dNothing recorded yet.|r"] = "|cff9d9d9dПока ничего не записано.|r",
	["|cff888888name, level, item level|r"] = "|cff888888имя, уровень, уровень предметов|r",
	["|cff40bf40Crafting cooldowns ready|r"] = "|cff40bf40Ремесленные восстановления готовы|r",
	["|cff888888Left-click for the family. Right-click for the options.|r"] = "|cff888888Левый клик - семья. Правый клик - настройки.|r",

	-- What Family adds to an item tooltip
	["%d guild bank"] = "%d банк гильдии",
	["%s |cff9d9d9dof %s|r"] = "%s |cff9d9d9dиз %s|r",
	["|cff40bf40knows it|r"] = "|cff40bf40знает|r",
	["|cffff8040level %d|r"] = "|cffff8040уровень %d|r",
	["|cff9d9d9dmay know it|r"] = "|cff9d9d9dвозможно, знает|r",
	["|cffffd700can learn it|r"] = "|cffffd700может выучить|r",
	["|cff66bbffFamily crafters|r"] = "|cff66bbffРемесленники семьи|r",
	["|cff66bbffFamily possessions|r"] = "|cff66bbffИмущество семьи|r",

	-- The member picker
	["|cff9d9d9d(nobody)|r"] = "|cff9d9d9d(никто)|r",
	["|cff9d9d9dnobody matches|r"] = "|cff9d9d9dсовпадений нет|r",

	-- The data addon, when something goes wrong
	["|cffff5555error starting %s|r: %s"] = "|cffff5555ошибка при запуске %s|r: %s",
	["|cffff5555error in deferred %s|r: %s"] = "|cffff5555ошибка в отложенном %s|r: %s",
	["|cffff5555error in %s handler for %s|r: %s"] = "|cffff5555ошибка в обработчике %s для %s|r: %s",

	-- The addon channel
	["|cffffaa00%s is not online.|r %d message(s) not sent."] = "|cffffaa00%s не в сети.|r Сообщений не отправлено: %d.",

	-- Storage and migrations
	["|cffff5555Migration from schema %d failed|r: %s"] = "|cffff5555не удалось выполнить миграцию со схемы %d|r: %s",
	["|cffff5555error telling %s the database changed|r: %s"] = "|cffff5555ошибка при уведомлении %s об изменении базы данных|r: %s",
	["|cffff5555Your saved data was written by Family schema %d, and this is schema %d.|r Nothing has been changed. Update Family, or move FamilyDB aside if you meant to start over."] = "|cffff5555Ваши сохранённые данные записаны схемой Family %d, а это схема %d.|r Ничего не изменено. Обновите Family или отложите FamilyDB, если хотели начать заново.",

	-- Locale.lua
	["Summary"] = "Обзор",  -- 20
}
