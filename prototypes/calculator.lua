local ACTR = require("prototypes.shared")
local Calculator = {}

--- Round a number.
function round(val, decimal)
    local exp = decimal and 10 ^ decimal or 1
    return math.ceil(val * exp - 0.5) / exp
end

local function getValidSprite(player, spritePath)
    if player.gui.is_valid_sprite_path(spritePath) then
        return spritePath
    else
        return "utility/questionmark"
    end
end

-- Creates an item that is several controls grouped together
local function addListItem(gui_element, text, value, spritePath)
    if (gui_element and gui_element.valid) then
        local cont = gui_element.add {type = "flow", direction = "horizontal"}
        cont.add {type = "sprite", sprite = spritePath, style = "ACTR_small_sprite"}

        cont.add {type = "label", caption = text}
        cont.add {type = "label", caption = round(value, 2) .. " /s"}
    end
end
-- Adds to a 3 column table of ingredients
local function addIngredientRow(gui_element, text, value, spritePath)
    if (gui_element and gui_element.valid) then
        gui_element.add {type = "sprite", sprite = spritePath, style = "ACTR_small_sprite"}
        gui_element.add {type = "label", caption = text, style = "bold_label"}
        gui_element.add {type = "label", caption = round(value, 2) .. " /s"}
    end
end

local function createProductionDetailsInElement(gui_element, entity, playerIndex, multiplier)
    local production = ACTR.getProductionNumbersForEntity(entity, playerIndex)
    local player = game.players[playerIndex]
    if production then
        productionFlow = gui_element.add {type = "flow", direction = "horizontal", name = entity.unit_number .. "_productionFlow"}
        recipeFlow = productionFlow.add {type = "flow", direction = "horizontal", name = entity.unit_number .. "_recipeFlow"}
        if (production.summary_ingredients) then
            ingredientFrame = recipeFlow.add {type = "flow", direction = "vertical", name = entity.unit_number .. "_ingredientFlow"}
            ingredientFrame.add {type = "label", caption = "Ingredients", style = "heading_2_label"}
            local container = ingredientFrame.add {type = "table", column_count = 3, direction = "vertical", caption = "Ingredients"}
            for i = 1, #production.summary_ingredients do
                local ingredient = production.summary_ingredients[i]
                local sprite = getValidSprite(player, ingredient.spritePath)
                local amount = ingredient.amount * multiplier
                local name = game[ingredient.type .. "_prototypes"][ingredient.name].localised_name

                addIngredientRow(container, name, amount, sprite)
            end
        end
        if (production.summary_products) then
            productFlow = recipeFlow.add {type = "flow", direction = "vertical", name = entity.unit_number .. "_productFlow"}
            productFlow.add {type = "label", caption = "Products", style = "heading_2_label"}
            local container = productFlow.add {type = "table", column_count = 3, direction = "vertical"}
            for i = 1, #production.summary_products do
                local prod = production.summary_products[i]
                local sprite = getValidSprite(player, prod.spritePath)
                local amount = prod.amount * multiplier
                local name = game[prod.type .. "_prototypes"][prod.name].localised_name
                addIngredientRow(container, name, amount, sprite)
            end
        end
    end
end

local function createProductionMultiplierInElement(gui_element, entity, multiplier, multiplierMax)
    local container = gui_element.add {type = "flow", direction = "vertical", name = entity.unit_number .. "_slider_container"}
    container.add {type = "label", caption = "Multiplier: " .. multiplier, name = entity.unit_number .. "_slider_label"}
    local slider =
        container.add {
        type = "slider",
        caption = "Multiplier",
        name = entity.unit_number .. "_ACTR_multiplier_slider",
        value = multiplier,
        minimum_value = 1,
        maximum_value = multiplierMax
    }
    --container.add {type = "text-box", caption = "Multiplier", name = playerIndex .. "_slider_value", value = multiplier}
    global.ACTR.registeredEntityMultipliers[entity.unit_number .. "_ACTR_multiplier_slider"] = entity
end

Calculator.openGui = function(playerIndex)
    local player = game.players[playerIndex]
    local guiContext = player.gui.left
    local frame =
        guiContext.add {
        type = "frame",
        name = "ACTR_Calculator_Frame",
        direction = "vertical",
        caption = "Production Calculator"
    }
end

-- MiscAddon
Calculator.removeEntity = function(event, entity, playerIndex)
    game.players[event.player_index].print("ACTR-MiscAddon; CallOrder B; see Log!")
    game.write_file("ACTR-MiscAddon.log", "\n" .. "CallOrder B", true)
--     game.write_file("ACTR-MiscAddon.log", "\nEntity.help(): " .. serpent.block(entity.help()), true)
    game.write_file("ACTR-MiscAddon.log", "\nPlayerIndex: " .. serpent.block(playerIndex), true)
    if (playerIndex) then
        local player = game.players[playerIndex]
        if (entity and player.gui.left.ACTR_Calculator_Frame) then
            game.players[event.player_index].print("ACTR-MiscAddon; CallOrder C; see Log!")
            game.write_file("ACTR-MiscAddon.log", "\n" .. "CallOrder C", true)
            game.write_file("ACTR-MiscAddon.log", "\n" .. serpent.block(entity.children_names[1]), true)
            if (player.gui.left.ACTR_Calculator_Frame[entity.children_names[1] .. "_entity_flow"]) then
                player.gui.left.ACTR_Calculator_Frame[entity.children_names[1] .. "_entity_flow"].destroy()
            end
        end
    end
end  -- MiscAddon

Calculator.closeGui = function(playerIndex)
    local player = game.players[playerIndex]
    if (player) then
        if player.gui.left.ACTR_Calculator_Frame then
            player.gui.left.ACTR_Calculator_Frame.destroy()
        end
    end
end

local function addEntity(entity, playerIndex)
    if (playerIndex) then
        local player = game.players[playerIndex]
        local multiplierMax = settings.get_player_settings(player)["ACTR-Multiplier"].value or 200
        if (entity and player.gui.left.ACTR_Calculator_Frame) then
            local productionNumbers = ACTR.getProductionNumbersForEntity(entity, playerIndex)
            if (productionNumbers) then
                if (player.gui.left.ACTR_Calculator_Frame[entity.unit_number .. "_entity_flow"]) then
                    player.gui.left.ACTR_Calculator_Frame[entity.unit_number .. "_entity_flow"].destroy()
                end
                local entity_flow = player.gui.left.ACTR_Calculator_Frame.add {type = "flow", name = entity.unit_number .. "_entity_flow", direction = "vertical"}
                local header = entity_flow.add {type = "flow", direction = "horizontal"}

                header.add {type = "label", style = "heading_1_label", caption = entity.prototype.localised_name}
                if (productionNumbers.effects.productivity.bonus > 0 or productionNumbers.effects.speed.bonus > 0) then
                    header.add {
                        type = "label",
                        style = "heading_3_label",
                        caption = "(Spd:" ..
                            round(productionNumbers.effects.speed.bonus * 100, 0) .. "% Prod:" .. round(productionNumbers.effects.productivity.bonus * 100, 0) .. "%)"
                    }
                end

                prod = entity_flow.add {type = "flow", name = entity.unit_number .. "_production_flow"}
                createProductionDetailsInElement(prod, entity, playerIndex, 1)
                control = entity_flow.add {type = "flow", name = entity.unit_number .. "_control_flow"}
                createProductionMultiplierInElement(control, entity, 1,multiplierMax)

                -- MiscAddon
                local removeButton = entity_flow.add {
                     type = "sprite-button",
                     name = "ACTR_remove_button",
                     tooltip = {"gui.ACTR_remove_button"},
                     sprite = "item/deconstruction-planner",
                     style = "mod_gui_button"
                }
                removeButton.add { type="label", name=entity.unit_number }
                -- TODO: get entity.unit_number or other unique identifier into event information and select from global
                player.print("ACTR-MiscAddon; CallOrder A; see Log!")
                game.write_file("ACTR-MiscAddon.log", "\n" .. "CallOrder A", true)
                game.write_file("ACTR-MiscAddon.log", "\nEntity: " .. serpent.block(entity), true)
                game.write_file("ACTR-MiscAddon.log", "\nEntity.unit_number: " .. serpent.block(entity.unit_number), true)
--                 game.write_file("ACTR-MiscAddon.log", "\nEntity_flow.help(): " .. serpent.block(entity_flow.help()), true)
--                 game.write_file("ACTR-MiscAddon.log", "\nRemoveButton.help(): " .. serpent.block(removeButton.help()), true)  -- MiscAddon
            end
        end
    end
end

local function on_gui_opened(event)
    if event.gui_type == defines.gui_type.entity then
        addEntity(event.entity, event.player_index)
    end
end

local function on_gui_closed(event)
    if event.gui_type == defines.gui_type.entity then
    --closeGui(event.player_index)
    end
end

local function on_gui_value_changed(event)
    if event.element.name:find("ACTR_multiplier_slider") then
        local playerIndex = event.player_index
        local player = game.players[playerIndex]
        local entity = global.ACTR.registeredEntityMultipliers[event.element.name]
        if (entity.valid) then
            local entityMultiplier = round(event.element.slider_value, 0) or 1

            if player.gui.left.ACTR_Calculator_Frame then
                local entityFlow = player.gui.left.ACTR_Calculator_Frame[entity.unit_number .. "_entity_flow"]
                entityFlow[entity.unit_number .. "_production_flow"].clear()
                createProductionDetailsInElement(entityFlow[entity.unit_number .. "_production_flow"], entity, playerIndex, entityMultiplier)
                entityFlow[entity.unit_number .. "_control_flow"][entity.unit_number .. "_slider_container"][entity.unit_number .. "_slider_label"].caption =
                    "Multiplier: " .. entityMultiplier
            -- guiContext[frameName][playerIndex .. "_control_flow"][playerIndex .. "_slider_container"][playerIndex .. "_slider"].slider_value = entityMultiplier
            end
        else
        end
    end
end

local function on_gui_click(event)
end

script.on_event(defines.events.on_gui_opened, on_gui_opened)

script.on_event(defines.events.on_gui_closed, on_gui_closed)

script.on_event(defines.events.on_gui_click, on_gui_click)

script.on_event(defines.events.on_gui_value_changed, on_gui_value_changed)

return Calculator
