from PIL import Image, ImageDraw, ImageFilter

# One stud cell (tiles seamlessly): transparent background, a dark L-shaped bevel on the
# bottom-left and a soft light catch on the top-right — like a Roblox stud seen from above.
S = 4  # supersample
N = 64
img = Image.new("RGBA", (N * S, N * S), (0, 0, 0, 0))

shadow = Image.new("L", img.size, 0)
d = ImageDraw.Draw(shadow)
pad, thick = 12 * S, 7 * S
left, top, right, bottom = pad, pad, N * S - pad, N * S - pad
d.rounded_rectangle([left, top + 6 * S, left + thick, bottom], radius=3 * S, fill=255)
d.rounded_rectangle([left, bottom - thick, right - 6 * S, bottom], radius=3 * S, fill=255)
shadow = shadow.filter(ImageFilter.GaussianBlur(1.2 * S))

light = Image.new("L", img.size, 0)
d = ImageDraw.Draw(light)
d.rounded_rectangle([left + thick, top, right, top + thick - 2 * S], radius=3 * S, fill=255)
d.rounded_rectangle([right - thick + 2 * S, top, right, bottom - thick], radius=3 * S, fill=255)
light = light.filter(ImageFilter.GaussianBlur(1.5 * S))

dark = Image.new("RGBA", img.size, (0, 0, 0, 255))
dark.putalpha(shadow.point(lambda v: int(v * 0.85)))
bright = Image.new("RGBA", img.size, (255, 255, 255, 255))
bright.putalpha(light.point(lambda v: int(v * 0.55)))
img = Image.alpha_composite(img, bright)
img = Image.alpha_composite(img, dark)
img = img.resize((N, N), Image.LANCZOS)
out = __file__.replace("make_stud.py", "stud.png")
img.save(out)
print("saved", out)
