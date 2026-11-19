local Screen = require("widgets/screen")
local Widget = require("widgets/widget")
local Image = require("widgets/image")
local ImageButton = require("widgets/imagebutton")
local UIAnim = require("widgets/uianim")
local Text = require("widgets/text")
local Templates = require("widgets/redux/templates")
local Data = require("lumine_artifact_data")
local RelicCollection = require("lumine_relic_collection")

local WHITE={.96,.92,.80,1}
local MUTED={.72,.76,.72,1}

local function Fill(parent,x,y,w,h,colour)
    local image=parent:AddChild(Image("images/ui.xml","white.tex"))
    image:SetSize(w,h)
    image:SetPosition(x,y)
    image:SetTint(unpack(colour))
    image:SetClickable(false)
    return image
end
local function Label(parent,size,value,x,y,colour)
    local text=parent:AddChild(Text(CHATFONT,size,value))
    text:SetPosition(x,y)
    text:SetColour(unpack(colour))
    text:SetClickable(false)
    return text
end
local function Button(parent,value,x,y,w,fn)
    local button=parent:AddChild(Templates.StandardButton(fn,value,{w,42}))
    button:SetPosition(x,y)
    return button
end

local Artifacts=Class(Screen,function(self,owner,on_activate,on_focus)
    Screen._ctor(self,"LumineArtifacts")
    self.owner=owner
    self.on_activate=on_activate
    self.on_focus=on_focus
    self.set_index=1
    self.is_popup=true
    local shade=self:AddChild(ImageButton("images/global.xml","square.tex"))
    shade.scale_on_focus=false
    shade.move_on_click=false
    shade.image:SetScaleMode(SCALEMODE_FILLSCREEN)
    shade.image:SetHAnchor(ANCHOR_MIDDLE)
    shade.image:SetVAnchor(ANCHOR_MIDDLE)
    shade.image:SetTint(0,0,0,.73)
    shade:SetOnClick(function() self:Close() end)
    shade:SetHelpTextMessage("")

    self.root=self:AddChild(Widget("artifact_root"))
    self.root:SetHAnchor(ANCHOR_MIDDLE)
    self.root:SetVAnchor(ANCHOR_MIDDLE)
    self.root:SetScaleMode(SCALEMODE_PROPORTIONAL)
    local panel=self.root:AddChild(ImageButton("images/global.xml","square.tex"))
    panel.scale_on_focus=false
    panel.move_on_click=false
    panel:ForceImageSize(940,650)
    panel.image:SetTint(.13,.14,.14,.98)
    panel:SetOnClick(function() end)
    panel:SetHelpTextMessage("")
    panel:SetFocusScale(1,1)
    Fill(self.root,0,294,892,3,{.85,.69,.43,1})
    Fill(self.root,0,-271,892,2,{.42,.36,.27,1})
    Label(self.root,34,"旅途圣遗物",-329,258,WHITE)
    Label(self.root,17,"拿起圣遗物，再右键随身星辉圣匣收录。",12,254,MUTED)
    Label(self.root,16,"各圣匣共享收藏。装备圣匣后所选页生效，同页四件解锁能力。",0,214,MUTED)
    for index,set in ipairs(Data.SETS) do
        Button(self.root,set.short,-290+(index-1)*290,168,164,function()
            self.set_index=index
            self:Render()
        end)
    end
    self.content=self.root:AddChild(Widget("artifact_collection"))
    self.closebutton=Button(self.root,"关闭",360,-297,116,function() self:Close() end)
    self.default_focus=self.closebutton
    owner._lumine_artifact_screen=self
    self:StartUpdating()
    self:Render()
end)

function Artifacts:GetProgress()
    local value=self.owner._lumine_artifacts and self.owner._lumine_artifacts:value() or ""
    local owned,active,focus=value:match("^([01]+):([0123]):([0123])$")
    return owned or "000000000000000",active or "0",focus or "0",value
end

function Artifacts:OnUpdate()
    local _,_,_,value=self:GetProgress()
    local inventory = self.owner.replica.inventory
    if not RelicCollection.GetCarried(inventory) then
        self:Close()
    elseif value~=self.last_value or self.equipped~=(RelicCollection.GetEquipped(inventory) ~= nil) then
        self:Render()
    end
end

function Artifacts:Render()
    self.content:KillAllChildren()
    local owned,active,focus,value=self:GetProgress()
    self.last_value=value
    self.equipped=RelicCollection.GetEquipped(self.owner.replica.inventory) ~= nil
    local set=Data.SETS[self.set_index]
    local count=0
    for i=1,5 do
        if owned:sub((self.set_index-1)*5+i,(self.set_index-1)*5+i)=="1" then count=count+1 end
    end
    local selected=active==tostring(self.set_index)
    local focused=focus==tostring(self.set_index)
    local status=selected and (self.equipped and "  ·  已生效" or "  ·  已选择") or ""
    Label(self.content,22,set.name.."  ·  "..count.."/5"..status,-105,126,set.colour)
    Label(self.content,15,"当前定向："..(focus=="0" and "无" or Data.SETS[tonumber(focus)].short),329,126,MUTED)
    for i=1,5 do
        local piece=Data.ALL[(self.set_index-1)*5+i]
        local x=-348+(i-1)*174
        local found=owned:sub((self.set_index-1)*5+i,(self.set_index-1)*5+i)=="1"
        Fill(self.content,x,2,164,212,found and {.24,.26,.22,1} or {.18,.20,.20,1})
        Fill(self.content,x,105,153,3,set.colour)
        Label(self.content,18,Data.SLOTS[i].name,x,85,WHITE)
        local icon=self.content:AddChild(UIAnim())
        icon:GetAnimState():SetBank("lumine_relic_icons")
        icon:GetAnimState():SetBuild("lumine_relic_icons")
        icon:GetAnimState():PlayAnimation(piece.id,true)
        icon:SetScale(.50)
        icon:SetPosition(x,27)
        if not found then icon:GetAnimState():SetMultColour(.35,.37,.38,.72) end
        Label(self.content,16,piece.name,x,-20,WHITE)
        local effective=found and selected and self.equipped
        Label(self.content,14,piece.stat,x,-47,effective and set.colour or MUTED)
        Label(self.content,14,found and (effective and "属性生效中" or "已收藏·未生效") or "尚未发现",x,-79,
            effective and set.colour or MUTED)
    end
    Fill(self.content,0,-180,870,103,{.18,.20,.20,1})
    Label(self.content,20,"完整收藏能力",-310,-145,set.colour)
    Label(self.content,17,set.ability,35,-176,count>=4 and WHITE or MUTED)
    Button(self.content,focused and "取消定向" or "定向收集",-305,-222,132,function()
        if self.on_focus then self.on_focus(focused and "none" or set.id) end
    end)
    if count>=1 then
        Button(self.content,selected and "收起本页" or "选用本页",328,-222,134,function()
            if self.on_activate then self.on_activate(selected and "none" or set.id) end
        end)
    else
        Label(self.content,16,"尚无收藏",332,-222,MUTED)
    end
    Label(self.content,14,(selected and ("当前生效："..count.." 项单件属性；"..(count>=4 and "四件能力已开启" or "四件能力未开启"))
        or "此页未激活，收藏属性暂不生效").."。定向目标有 70% 机会优先掉落该套缺件。",-15,-251,MUTED)
end

function Artifacts:Close()
    if self.closed then return end
    self.closed=true
    TheFrontEnd:PopScreen(self)
end
function Artifacts:OnDestroy()
    if self.owner and self.owner._lumine_artifact_screen==self then self.owner._lumine_artifact_screen=nil end
    Artifacts._base.OnDestroy(self)
end
function Artifacts:OnControl(control,down)
    if Artifacts._base.OnControl(self,control,down) then return true end
    if not down and (control==CONTROL_CANCEL or control==CONTROL_MENU_BACK or control==CONTROL_PAUSE) then
        self:Close()
    end
    return true
end

return Artifacts
