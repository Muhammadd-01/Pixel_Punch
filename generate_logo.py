import math
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def create_pixel_punch_logo():
    width, height = 512, 512
    # Create RGBA canvas
    img = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = 256, 230

    # 1. Outer dynamic comic burst / starburst
    num_spikes = 16
    burst_points = []
    for i in range(num_spikes * 2):
        angle = i * (math.pi / num_spikes)
        r = 210 if i % 2 == 0 else 145
        px = cx + r * math.cos(angle)
        py = cy + r * math.sin(angle)
        burst_points.append((px, py))

    # Outer burst shadow & outline
    draw.polygon(burst_points, fill=(15, 23, 42, 255))
    
    # Inner burst (Golden Orange/Yellow)
    inner_burst = []
    for i in range(num_spikes * 2):
        angle = i * (math.pi / num_spikes)
        r = 196 if i % 2 == 0 else 135
        px = cx + r * math.cos(angle)
        py = cy + r * math.sin(angle)
        inner_burst.append((px, py))
    draw.polygon(inner_burst, fill=(255, 107, 53, 255))

    # Highlight burst
    hl_burst = []
    for i in range(num_spikes * 2):
        angle = i * (math.pi / num_spikes)
        r = 175 if i % 2 == 0 else 120
        px = cx + r * math.cos(angle)
        py = cy + r * math.sin(angle)
        hl_burst.append((px, py))
    draw.polygon(hl_burst, fill=(255, 191, 0, 255))

    # 2. Pixel fragments bursting outward
    pixel_offsets = [
        (-160, -110, 18, (46, 196, 182, 255)),
        (-140, -135, 12, (255, 255, 255, 255)),
        (150, -120, 20, (255, 107, 53, 255)),
        (180, -90, 14, (46, 196, 182, 255)),
        (-170, 60, 16, (255, 191, 0, 255)),
        (165, 50, 16, (255, 255, 255, 255)),
        (140, 110, 14, (46, 196, 182, 255)),
        (-150, 120, 16, (255, 107, 53, 255)),
        (0, -180, 22, (255, 255, 255, 255)),
        (-60, -170, 14, (46, 196, 182, 255)),
        (70, -170, 14, (255, 191, 0, 255)),
    ]
    for ox, oy, sz, col in pixel_offsets:
        bx = cx + ox
        by = cy + oy
        # Draw pixel box with outline
        draw.rectangle([bx-sz//2-2, by-sz//2-2, bx+sz//2+2, by+sz//2+2], fill=(15, 23, 42, 255))
        draw.rectangle([bx-sz//2, by-sz//2, bx+sz//2, by+sz//2], fill=col)

    # 3. Action / Speed lines behind fist
    for angle_deg in range(130, 230, 20):
        rad = math.radians(angle_deg)
        x1 = cx + 80 * math.cos(rad)
        y1 = cy + 80 * math.sin(rad)
        x2 = cx + 180 * math.cos(rad)
        y2 = cy + 180 * math.sin(rad)
        draw.line([x1, y1, x2, y2], fill=(255, 255, 255, 200), width=6)

    # 4. Stylized Boxing Glove / Punch Fist
    # Forearm
    arm_poly = [(cx - 130, cy + 50), (cx - 70, cy + 20), (cx - 50, cy + 70), (cx - 120, cy + 100)]
    draw.polygon(arm_poly, fill=(15, 52, 96, 255))
    draw.line(arm_poly + [arm_poly[0]], fill=(10, 20, 40, 255), width=6)

    # Glove wrist strap (Cyan)
    strap_poly = [(cx - 85, cy + 15), (cx - 35, cy - 10), (cx - 20, cy + 45), (cx - 75, cy + 70)]
    draw.polygon(strap_poly, fill=(46, 196, 182, 255))
    draw.line(strap_poly + [strap_poly[0]], fill=(15, 23, 42, 255), width=6)

    # Main glove ball (Fiery Punch Red-Orange)
    glove_center_x, glove_center_y = cx + 25, cy + 10
    glove_r = 85
    # Shadow/Border
    draw.ellipse([glove_center_x - glove_r - 8, glove_center_y - glove_r - 8,
                  glove_center_x + glove_r + 8, glove_center_y + glove_r + 8],
                 fill=(20, 15, 30, 255))
    # Base red-orange
    draw.ellipse([glove_center_x - glove_r, glove_center_y - glove_r,
                  glove_center_x + glove_r, glove_center_y + glove_r],
                 fill=(235, 45, 30, 255))

    # Knuckle highlights / segments (stylized punch face)
    draw.ellipse([glove_center_x - 30, glove_center_y - 70,
                  glove_center_x + 75, glove_center_y + 35],
                 fill=(255, 107, 53, 255))
    # Shiny gloss highlight on glove
    draw.ellipse([glove_center_x + 10, glove_center_y - 55,
                  glove_center_x + 55, glove_center_y - 20],
                 fill=(255, 255, 255, 230))

    # Thumb segment
    thumb_poly = [(glove_center_x - 65, glove_center_y + 10),
                  (glove_center_x - 20, glove_center_y + 20),
                  (glove_center_x - 10, glove_center_y + 70),
                  (glove_center_x - 55, glove_center_y + 60)]
    draw.polygon(thumb_poly, fill=(20, 15, 30, 255))
    thumb_inner = [(glove_center_x - 60, glove_center_y + 15),
                   (glove_center_x - 25, glove_center_y + 25),
                   (glove_center_x - 18, glove_center_y + 63),
                   (glove_center_x - 50, glove_center_y + 55)]
    draw.polygon(thumb_inner, fill=(235, 45, 30, 255))

    # Comic impact spark at the point of punch (right side)
    spark_cx, spark_cy = glove_center_x + 75, glove_center_y - 15
    for angle_deg in range(0, 360, 45):
        rad = math.radians(angle_deg)
        length = 40 if angle_deg % 90 == 0 else 25
        sx = spark_cx + length * math.cos(rad)
        sy = spark_cy + length * math.sin(rad)
        draw.line([spark_cx, spark_cy, sx, sy], fill=(255, 255, 255, 255), width=6)
        draw.line([spark_cx, spark_cy, sx, sy], fill=(46, 196, 182, 255), width=3)

    # 5. Bold Badge Banner for Title "PIXELPUNCH"
    banner_y = 370
    banner_h = 95
    # Banner drop shadow
    draw.rectangle([25, banner_y + 8, 487, banner_y + banner_h + 8], fill=(10, 15, 30, 255))
    # Banner base (Dark Navy/Slate)
    draw.rectangle([20, banner_y, 492, banner_y + banner_h], fill=(15, 32, 60, 255))
    # Banner border (Electric Cyan)
    draw.rectangle([20, banner_y, 492, banner_y + banner_h], outline=(46, 196, 182, 255), width=5)

    # Inner banner golden accent line
    draw.line([25, banner_y + 5, 487, banner_y + 5], fill=(255, 191, 0, 255), width=3)
    draw.line([25, banner_y + banner_h - 5, 487, banner_y + banner_h - 5], fill=(255, 191, 0, 255), width=3)

    # Draw bold text letters procedurally / using font if available
    font_loaded = False
    try:
        # Check standard Windows fonts
        for font_name in ["impact.ttf", "arialbd.ttf", "segoeuib.ttf"]:
            font_path = os.path.join(os.environ.get("WINDIR", "C:\\Windows"), "Fonts", font_name)
            if os.path.exists(font_path):
                title_font = ImageFont.truetype(font_path, 54)
                sub_font = ImageFont.truetype(font_path, 16)
                font_loaded = True
                break
    except Exception:
        font_loaded = False

    text_title = "PIXELPUNCH"
    text_sub = "YOUR ZONE • YOUR RIVALS • YOUR VICTORY"

    if font_loaded:
        # Title text shadow
        draw.text((cx - 150 + 4, banner_y + 12 + 4), text_title, font=title_font, fill=(0, 0, 0, 255))
        # Title text main (Golden gradient fill)
        draw.text((cx - 150, banner_y + 12), text_title, font=title_font, fill=(255, 191, 0, 255))
        # Subtitle
        draw.text((cx - 165, banner_y + 70), text_sub, font=sub_font, fill=(46, 196, 182, 255))
    else:
        # Procedural fallback text styling
        draw.text((cx - 140, banner_y + 20), text_title, fill=(255, 191, 0, 255))
        draw.text((cx - 140, banner_y + 65), text_sub, fill=(46, 196, 182, 255))

    # Save output
    os.makedirs("assets/branding", exist_ok=True)
    target_path = "assets/branding/pixel_punch_logo.png"
    img.save(target_path, "PNG")
    print(f"Successfully generated PixelPunch logo at {target_path}")

    # Also save an icon version (192x192)
    icon = img.resize((192, 192), Image.Resampling.LANCZOS)
    icon.save("assets/branding/pixel_punch_icon.png", "PNG")
    print("Successfully generated PixelPunch icon at assets/branding/pixel_punch_icon.png")

if __name__ == "__main__":
    create_pixel_punch_logo()
