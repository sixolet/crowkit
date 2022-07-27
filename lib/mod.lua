local mod = require 'core/mods'
local toolkit = require('toolkit/lib/mod')
local music = require("musicutil")


local scale_names = {}
for i = 1, #music.SCALES do
  table.insert(scale_names, music.SCALES[i].name)
end

local MODES = {"none", "pulse", "gate", "voltage", "note"}

local n = function(i, name)
    return "ck_"..i.."_"..name
end

local make_crow_output = function(i)
    params:add_group("crow out"..i, 9)
    local scale = {}
    params:add_option(n(i, "mode"), "mode", MODES, 1)
    local routine
    params:set_action(n(i, "mode"), function(m)
        if routine ~= nil then
            clock.cancel(routine)
            routine = nil
        end
        for _, id in ipairs({"pulse", "pulse_len", "gate", "voltage", "resolution", "note", "tuning", "scale"}) do
            params:hide(n(i, id))
            crow.output[i].slew = 0
        end
        if m == 2 then
            params:show(n(i, "pulse"))
            params:show(n(i, "pulse_len"))
        elseif m == 3 then
            params:show(n(i, "gate"))
            params:lookup_param(n(i, "gate")):bang()
        elseif m == 4 then
            params:show(n(i, "voltage"))
            params:show(n(i, "resolution"))
            routine = clock.run(function()
                while params:get(n(i, "mode")) == 4 do
                    crow.output[i].volts = params:get(n(i, "voltage"))
                    clock.sleep(params:get(n(i, "resolution")))
                end
            end)
            params:lookup_param(n(i, "resolution")):bang()
        elseif m == 5 then
            params:show(n(i, "note"))
            params:show(n(i, "tuning"))
            params:show(n(i, "scale"))
            params:lookup_param(n(i, "note")):bang()
        end
        _menu.rebuild_params()
    end)
    toolkit.defer_bang(n(i, "mode"))
    params:add_trigger(n(i, "pulse"), "pulse")
    params:add_control(n(i, "pulse_len"), "pulse length", controlspec.new(0.005, 10, "exp", 0, 0.01))
    local on = false
    params:set_action(n(i, "pulse"), function()
        if params:get(n(i, "mode")) ~= 2 then
            return
        end        
        if not on then
            crow.output[i].volts = 10
            on = true
            clock.run(function()
                clock.sleep(params:get(n(i, "pulse_len")))
                on = false
                if params:get(n(i, "mode")) == 2 then
                    crow.output[i].volts = 0
                end
            end)
        end
    end)
    
    params:add_binary(n(i, "gate"), "gate", "toggle", 0)
    params:set_action(n(i, "gate"), function(g)
        if params:get(n(i, "mode")) ~= 3 then
            return
        end        
        crow.output[i].volts = 10*g
    end)
    
    params:add_control(n(i, "voltage"), "voltage", controlspec.new(-5, 10, "lin", 0, 0))
    params:add_control(n(i, "resolution"), "resolution", controlspec.new(0.05, 0.5, "exp", 0, 0.1))
    params:set_action(n(i, "resolution"), function(r)
        if params:get(n(i, "mode")) ~= 4 then
            return
        end
        crow.output[i].slew = r
    end)
    
    params:add_number(n(i, "note"), "note", 0, 127, 48)
    params:add_control(n(i, "tuning"), "hz at 0v", controlspec.FREQ)
    params:set_action(n(i, "note"), function (note)
        if params:get(n(i, "mode")) ~= 5 then
            return
        end
        local hz = music.note_num_to_freq(music.snap_note_to_array(note, scale))
        local ratio = hz/params:get(n(i, "tuning"))
        crow.output[i].volts = math.log(ratio)/math.log(2)
    end)
    toolkit.defer_bang(n(i, "note"))
    params:add_option(n(i, "scale"), "scale", scale_names, 1)
    params:set_action(n(i, "scale"), function ()
        local s = scale_names[params:get(n(i, "scale"))]
        scale = music.generate_scale(12, s, 8)
    end)
    toolkit.defer_bang(n(i, "scale"), 2)
end

local pre_init = function()
    for i=1,4,1 do
        table.insert(toolkit.registered_binaries, n(i, "pulse"))
        table.insert(toolkit.registered_binaries, n(i, "gate"))
        table.insert(toolkit.registered_numbers, n(i, "voltage"))
        table.insert(toolkit.registered_numbers, n(i, "note"))
    end
    toolkit.post_init["crowkit"] = function()
        for i=1,4,1 do
            make_crow_output(i)
        end
    end
end

mod.hook.register("script_pre_init", "crowkit pre init", pre_init)
