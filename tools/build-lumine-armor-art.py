"""Build four head/body armor stages from the character's exact directional sprites.

Source frames retain their dimensions and pivots, so the existing animation rig
continues to control facing, skirt layering, and attachment positions.
"""
from pathlib import Path
import math
import xml.etree.ElementTree as ET
from PIL import Image, ImageDraw, ImageChops, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "reference/workshop-3808204425/model-export"
OUT = ROOT / "art/working/armor"
CONCEPT = Image.open(ROOT / "art/source/armor/lumine-armor-concept.png").convert("RGBA")
SCML = ET.parse(MODEL / "lumine.scml").getroot()

TIERS = (
    ("traveler", (169, 133, 70), (46, 56, 78), .26),
    ("dawn", (208, 166, 76), (52, 90, 124), .42),
    ("stone", (221, 172, 78), (87, 72, 78), .55),
    ("celestial", (245, 207, 115), (93, 120, 139), .72),
)


def source_files(symbol):
    folder = next(f for f in SCML.findall("folder") if f.get("name") == symbol)
    return [(int(f.get("id")), f) for f in folder.findall("file")]


def gem(draw, x, y, radius, gold, blue):
    r = max(3, radius)
    p = [(x, y-r), (x+r, y), (x, y+r), (x-r, y)]
    draw.polygon(p, fill=gold)
    draw.line(p+[p[0]], fill=(28, 25, 27, 240), width=max(2, r//3), joint="curve")
    q = [(x, y-r+3), (x+r-3, y), (x, y+r-3), (x-r+3, y)]
    draw.polygon(q, fill=blue)


def clear_export_padding(src):
    # Both imported head and torso frames contain fully opaque, pure black
    # rectangles outside the actual art. Preserve the dark brown line work.
    im = src.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a and r <= 8 and g <= 8 and b <= 8:
                px[x, y] = (0, 0, 0, 0)
    return im


def head_frame(src, index, gold, blue, intensity):
    im = clear_export_padding(src)
    overlay = Image.new("RGBA", im.size)
    d = ImageDraw.Draw(overlay)
    w, h = im.size
    # Five original frames: front, profile, back, front variations.
    if index == 1:
        path = [(int(w*.34),int(h*.28)), (int(w*.52),int(h*.19)), (int(w*.75),int(h*.24))]
        cx, cy = int(w*.53), int(h*.18)
    elif index == 2:
        path = [(int(w*.25),int(h*.26)), (int(w*.50),int(h*.22)), (int(w*.75),int(h*.26))]
        cx, cy = int(w*.50), int(h*.21)
    else:
        path = [(int(w*.28),int(h*.29)), (int(w*.49),int(h*.21)), (int(w*.78),int(h*.29))]
        cx, cy = int(w*.50), int(h*.20)
    d.line(path, fill=(28,24,26,235), width=8, joint="curve")
    d.line(path, fill=(*gold,255), width=5, joint="curve")
    gem(d,cx,cy,int(8+intensity*6),gold,blue)
    if intensity > .4:
        for side in (-1,1):
            gem(d,cx+side*int(w*.15),cy+8,5,gold,(245,231,189))
    overlay.putalpha(ImageChops.multiply(overlay.getchannel("A"), im.getchannel("A")))
    im.alpha_composite(overlay)
    return im


def body_frame(src, index, gold, blue, intensity):
    im = clear_export_padding(src)
    w,h = im.size
    # Tint only existing fabric. Never expand the silhouette beyond the source.
    pixels=im.load()
    for y in range(h):
        for x in range(w):
            r,g,b,a=pixels[x,y]
            if a<20: continue
            if b>r*.95 and b>g*.95 and r<145:
                t=.18+intensity*.24
                pixels[x,y]=(int(r*(1-t)+blue[0]*t),int(g*(1-t)+blue[1]*t),
                             int(b*(1-t)+blue[2]*t),a)
    overlay=Image.new("RGBA", im.size)
    d=ImageDraw.Draw(overlay)
    # In every direction the emblem sits within the torso's existing fabric.
    cx=int(w*(.50 if index not in (2,3,4,8) else .56))
    cy=int(h*(.47 if index!=9 else .55))
    radius=max(4,int(min(w,h)*(.055+intensity*.025)))
    gem(d,cx,cy,radius,gold,blue)
    if index in (0,1,2,5,10):
        shoulder_y=int(h*.27)
        for x0,x1 in ((.14,.33),(.67,.86)):
            d.line([(int(w*x0),shoulder_y),(int(w*x1),shoulder_y+int(h*.07))],
                   fill=(*gold,int(135+intensity*110)),width=max(2,int(2+intensity*3)))
        d.line([(int(w*.35),int(h*.51)),(int(w*.65),int(h*.51))],
               fill=(*gold,int(130+intensity*115)),width=max(2,int(2+intensity*3)))
        d.arc((int(w*.19),int(h*.23),int(w*.81),int(h*.84)),20,160,
              fill=(*gold,int(175+intensity*65)),width=max(2,int(2+intensity*2)))
    overlay.putalpha(ImageChops.multiply(overlay.getchannel("A"),src.getchannel("A")))
    im.alpha_composite(overlay)
    return im


def icon(kind, gold, blue, intensity):
    # Separate isolated motifs from the generated concept sheet. The 90-pixel
    # maximum leaves enough breathing room in both inventory and crafting UI.
    box=(765,0,1310,314) if kind=="head" else (780,330,1350,1020)
    part=CONCEPT.crop(box)
    bounds=part.getchannel("A").point(lambda a:255 if a>15 else 0).getbbox()
    part=part.crop(bounds) if bounds else part
    part.thumbnail((92,92),Image.Resampling.LANCZOS)
    canvas=Image.new("RGBA",(128,128))
    halo=Image.new("RGBA",(128,128))
    hd=ImageDraw.Draw(halo)
    hd.ellipse((28,24,100,100),fill=(*blue,85))
    canvas.alpha_composite(halo.filter(ImageFilter.GaussianBlur(14)))
    canvas.alpha_composite(part,((128-part.width)//2,(128-part.height)//2))
    marks=1 if intensity<.3 else 2 if intensity<.5 else 3 if intensity<.65 else 4
    d=ImageDraw.Draw(canvas)
    for i in range(marks):
        x=64+(i-(marks-1)/2)*15
        y=112
        d.polygon([(x,y-5),(x+4,y),(x,y+5),(x-4,y)],fill=(*gold,255))
    return canvas


def scml(name, symbol, paths, icon_path):
    data=ET.Element("spriter_data",scml_version="1.0",generator="BrashMonkey Spriter",generator_version="b5")
    folder=ET.SubElement(data,"folder",id="0",name=symbol)
    metadata=source_files(symbol)
    for i,(_,original) in enumerate(metadata):
        ET.SubElement(folder,"file",id=str(i),name=f"{symbol}/{paths[i].name}",
                      width=original.get("width"),height=original.get("height"),
                      pivot_x=original.get("pivot_x"),pivot_y=original.get("pivot_y"))
    item_folder=ET.SubElement(data,"folder",id="1",name="item")
    ET.SubElement(item_folder,"file",id="0",name=f"item/{icon_path.name}",
                  width="128",height="128",pivot_x="0.5",pivot_y="0.5")
    entity=ET.SubElement(data,"entity",id="0",name=name)
    for aid,(anim_name,count,folder_id) in enumerate((("idle",1,1),("swap",len(paths),0))):
        anim=ET.SubElement(entity,"animation",id=str(aid),name=anim_name,
                           length=str(count*100),looping="true")
        main=ET.SubElement(anim,"mainline")
        timeline=ET.SubElement(anim,"timeline",id="0",name="item" if folder_id else symbol,object_type="sprite")
        for i in range(count):
            key=ET.SubElement(main,"key",id=str(i),time=str(i*100))
            ET.SubElement(key,"object_ref",id="0",timeline="0",key=str(i),z_index="0")
            tk=ET.SubElement(timeline,"key",id=str(i),time=str(i*100))
            ET.SubElement(tk,"object",folder=str(folder_id),file=str(i if folder_id==0 else 0),
                          x="0",y="0",angle="0",scale_x="1",scale_y="1")
    ET.indent(data)
    ET.ElementTree(data).write(OUT/name/f"{name}.scml",encoding="utf-8",xml_declaration=True)


for tier,gold,blue,intensity in TIERS:
    for kind,symbol in (("head","headbase_hat"),("body","torso")):
        name=f"lumine_{tier}_{kind}"
        root=OUT/name
        folder=root/symbol
        item=root/"item"
        folder.mkdir(parents=True,exist_ok=True)
        item.mkdir(parents=True,exist_ok=True)
        paths=[]
        for index,meta in source_files(symbol):
            src=Image.open(MODEL/symbol/f"{symbol}-{index}.png").convert("RGBA")
            result=(head_frame(src,index,gold,blue,intensity) if kind=="head"
                    else body_frame(src,index,gold,blue,intensity))
            path=folder/f"{symbol}-{index}.png"
            result.save(path)
            paths.append(path)
        item_path=item/f"{name}-0.png"
        icon(kind,gold,blue,intensity).save(item_path)
        icon(kind,gold,blue,intensity).save(root/f"{name}-icon.png")
        scml(name,symbol,paths,item_path)
        print(name,len(paths))
