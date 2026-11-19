local M = {}
function M.Outside(x,y,width,height)
    -- 给高大建筑和屏幕边缘留余量；已经露出一部分也不补报。
    return x < -100 or x > width+100 or y < -160 or y > height+100
end
function M.Position(px,py,tx,ty,width,height,lastangle)
    local dx,dy = tx-px,ty-py
    local length = math.sqrt(dx*dx+dy*dy)
    if length<1 and lastangle==nil then return nil end
    local margin = math.min(110,width*.25,height*.25)
    -- 固定在派蒙身体右侧，避免随目标方向绕到她头顶的台词上。
    local x = math.max(margin,math.min(width-margin,px+112))
    local y = math.max(margin,math.min(height-margin,py+48))
    -- arrow_right.tex 的原始图案朝右，UI 的旋转为顺时针。
    return x,y,length>=1 and -math.atan2(dy,dx)*180/math.pi or lastangle
end
return M
