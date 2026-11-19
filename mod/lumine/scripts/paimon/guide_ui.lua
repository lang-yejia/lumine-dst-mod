local Widget = require("widgets/widget")
local Image = require("widgets/image")
local C = require("paimon/config")
local Geometry = require("paimon/guide_indicator_math")

local Indicator = Class(Widget,function(self,owner,pet,x,z)
    Widget._ctor(self,"PaimonGuideIndicator")
    self.owner,self.pet,self.x,self.z = owner,pet,x,z
    self.remaining = C.GUIDE_INDICATOR_TIME
    self.elapsed = 0
    self:SetClickable(false)
    self:UpdateWhilePaused(false)
    -- 原版手绘轮廓配亮黄色，放在派蒙身旁，与她的台词集中在同一区域。
    self.pointer = self:AddChild(Widget("PaimonGuidePointer"))
    self.pointer:SetClickable(false)
    self.dashes = {}
    self.dashoutlines = {}
    for i=1,4 do
        -- 原版长分隔线缩到十几像素后会丢失亮部。改用实心白底着色，确保箭身可见。
        local outline = self.pointer:AddChild(Image("images/ui.xml","white.tex"))
        outline:SetSize(22,14);outline:SetClickable(false)
        local dash = self.pointer:AddChild(Image("images/ui.xml","white.tex"))
        dash:SetSize(18,10);dash:SetClickable(false)
        local tilt = i%2==0 and 3 or -3
        outline:SetRotation(tilt);dash:SetRotation(tilt)
        self.dashes[i] = dash
        self.dashoutlines[i] = outline
    end
    self.arrow = self.pointer:AddChild(Image("images/ui.xml","arrow_right.tex"))
    self.arrow:SetSize(100,100);self.arrow:SetClickable(false)
    self.arrow:SetPosition(44,0)
    self.inst:ListenForEvent("onremove",function()
        if owner._paimon_guide_indicator==self then owner._paimon_guide_indicator=nil end
    end)
    self:StartUpdating()
end)

function Indicator:Finish()
    if self.owner._paimon_guide_indicator==self then self.owner._paimon_guide_indicator=nil end
    self:StopUpdating();self:Kill()
end

function Indicator:OnUpdate(dt)
    if not self.owner:IsValid() or self.owner:HasTag("playerghost") or not self.owner.HUD then self:Finish();return end
    if not self.pet:IsValid() or not self.pet._owner or self.pet._owner:value()~=self.owner then self:Finish();return end
    if TheNet:IsServerPaused() then return end
    self.remaining = self.remaining-(dt or 0)
    self.elapsed = self.elapsed+(dt or 0)
    -- 移动和追赶不结束指引；仅按自己的五秒显示时间淡出。
    if self.remaining<=0 then self:Finish();return end
    local ax,ay,az = self.pet.Transform:GetWorldPosition()
    local px,py = TheSim:GetScreenPos(ax,ay,az)
    local tx,ty = TheSim:GetScreenPos(self.x,ay,self.z)
    local w,h = TheSim:GetScreenSize()
    -- 派蒙已经不在画面里时，不把箭头挪回荧身边或屏幕边缘。
    if px<0 or px>w or py<0 or py>h then self:Hide();return end
    local x,y,angle = Geometry.Position(px,py,tx,ty,w,h,self.lastangle)
    if not x then self:Hide();return end
    self:Show();self:SetPosition(x,y)
    self.lastangle = angle
    self.pointer:SetRotation(angle)
    local alpha = math.min(1,self.remaining/.35)
    self.arrow:SetTint(1,.9,.05,alpha)
    -- 四段手绘虚线从尾部向箭头流动，循环边缘淡入淡出，保持清楚的间隔。
    local phase = (self.elapsed*48)%24
    for i,dash in ipairs(self.dashes) do
        local offset = -76+(i-1)*24+phase
        local fade = math.min(1,(offset+84)/16,(28-offset)/16)
        dash:SetPosition(offset,0)
        dash:SetTint(1,.9,.05,alpha*math.max(0,fade))
        local outline = self.dashoutlines[i]
        outline:SetPosition(offset,0)
        outline:SetTint(.18,.12,.025,alpha*math.max(0,fade))
    end
end

local M = {}
function M.Show(owner,x,z)
    if not owner.HUD or not owner.HUD.under_root then return end
    if owner._paimon_guide_indicator then owner._paimon_guide_indicator:Finish() end
    -- _paimon 是服务端引用；远程客户端通过同步的 _owner 找到自己的派蒙。
    -- 仅收到提示时查一次，显示期间直接追踪实体，不逐帧扫描。
    local pet = owner._paimon
    if not (pet and pet:IsValid() and pet._owner and pet._owner:value()==owner) then
        pet = nil
        local ox,oy,oz = owner.Transform:GetWorldPosition()
        for _,candidate in ipairs(TheSim:FindEntities(ox,oy,oz,C.GUIDE_RECOVER_DISTANCE,{"lumine_paimon"},{"INLIMBO"})) do
            if candidate:IsValid() and candidate._owner and candidate._owner:value()==owner then
                pet = candidate;break
            end
        end
    end
    if not pet then return end
    local widget = owner.HUD.under_root:AddChild(Indicator(owner,pet,x,z))
    owner._paimon_guide_indicator = widget
    widget:MoveToFront()
    widget:OnUpdate(0)
end
return M
