local L = require("languages/lumine").For("screens/paimon_wishes")
local Screen = require("widgets/screen")
local Widget = require("widgets/widget")
local ImageButton = require("widgets/imagebutton")
local Text = require("widgets/text")
local Companion = require("paimon/companion")
local C = require("paimon/config")
local FONT = NEWFONT or UIFONT

local Wishes = Class(Screen,function(self,owner,pet)
    Screen._ctor(self,"PaimonWishes")
    self.owner,self.pet,self.hud=owner,pet,owner.HUD
    self.is_popup=true
    local shade=self:AddChild(ImageButton("images/global.xml","square.tex"))
    shade.scale_on_focus=false;shade.move_on_click=false
    shade.image:SetScaleMode(SCALEMODE_FILLSCREEN)
    shade.image:SetHAnchor(ANCHOR_MIDDLE);shade.image:SetVAnchor(ANCHOR_MIDDLE)
    shade.image:SetTint(0,0,0,.45)
    shade:SetOnClick(function()self:Close()end);shade:SetHelpTextMessage("")
    local anchor=self:AddChild(Widget("paimon_wishes_anchor"))
    anchor:SetHAnchor(ANCHOR_MIDDLE);anchor:SetVAnchor(ANCHOR_MIDDLE)
    anchor:SetScaleMode(SCALEMODE_PROPORTIONAL)
    self.root=anchor:AddChild(Widget("paimon_wishes"))
    self.root:SetScale(.60)
    local paper=self.root:AddChild(ImageButton("images/quagmire_recipebook.xml","quagmire_recipe_menu_bg.tex"))
    paper.scale_on_focus=false;paper.move_on_click=false
    paper:ForceImageSize(560,470);paper:SetFocusScale(1,1)
    paper:SetOnClick(function()end);paper:SetHelpTextMessage("")
    local title=self.root:AddChild(Text(FONT,44,"派蒙的旅途记录"))
    title:SetPosition(0,175);title:SetColour(.22,.12,.07,1);title:SetClickable(false)
    self.status=self.root:AddChild(Text(FONT,34,""))
    self.status:SetPosition(0,35);self.status:SetColour(.16,.12,.08,1)
    self.status:SetRegionSize(480,170);self.status:EnableWordWrap(true);self.status:SetClickable(false)
    local function Button(label,y,width,fn)
        local button=self.root:AddChild(ImageButton("images/frontend.xml","button_long.tex",
            "button_long_highlight.tex","button_long_disabled.tex","button_long_down.tex",
            nil,{1,1},{0,0}))
        button.scale_on_focus=false
        button:ForceImageSize(width,56)
        button:SetFont(FONT);button:SetDisabledFont(FONT);button:SetTextSize(30)
        button:SetTextColour(.12,.08,.04,1);button:SetTextFocusColour(.05,.03,.01,1)
        button:SetTextDisabledColour(.32,.29,.24,1)
        button:SetText(label);button:SetPosition(0,y);button:SetOnClick(fn)
        return button
    end
    local hint=self.root:AddChild(Text(FONT,24,"带证物给派蒙；图文线索请查看旅行手册"))
    hint:SetPosition(0,-145);hint:SetColour(.30,.22,.14,1);hint:SetClickable(false)
    self.closebutton=Button(L(4,"关闭"),-195,180,function()self:Close()end)
    self.default_focus=self.closebutton
    owner._paimon_wishes=self
    self:Refresh()
end)

function Wishes:Refresh()
    self.status:SetString(self.pet._companion_status:value())
end
function Wishes:Close()
    if self.closed then return end
    self.closed=true
    TheFrontEnd:PopScreen(self)
end
function Wishes:OnDestroy()
    if self.owner._paimon_wishes==self then self.owner._paimon_wishes=nil end
    if self.owner:IsValid() and self.pet:IsValid() then Companion.Request("close",self.pet) end
    Wishes._base.OnDestroy(self)
end
function Wishes:OnUpdate(dt)
    local owner,pet=self.owner,self.pet
    if self.closed then return end
    if not owner:IsValid() or not pet:IsValid() or pet._owner:value()~=owner
        or owner:HasTag("playerghost") or owner:HasTag("INLIMBO") or pet:HasTag("INLIMBO")
        or pet:HasTag("NOCLICK") or not owner.HUD or owner.HUD~=self.hud
        or owner:GetDistanceSqToInst(pet)>C.BAG_OPEN_DISTANCE^2 then self:Close();return end
    self:Refresh()
end
function Wishes:OnControl(control,down)
    if Wishes._base.OnControl(self,control,down) then return true end
    if not down and (control==CONTROL_CANCEL or control==CONTROL_MENU_BACK or control==CONTROL_PAUSE) then
        self:Close()
    end
    return true
end
function Wishes:OnRawKey() return true end
return Wishes
