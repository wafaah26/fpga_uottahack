# from PIL import Image

# # Open image WITH alpha channel
# img = Image.open("logo.png").convert("RGBA")

# # Resize (change size if you want)
# img = img.resize((128, 128), Image.BICUBIC)

# with open("sprite.hex", "w") as f:
#     for y in range(128):
#         for x in range(128):
#             r, g, b, a = img.getpixel((x, y))

#             # If pixel is transparent → write magenta
#             if a == 0:
#                 f.write("FF00FF\n")
#             else:
#                 f.write(f"{r:02X}{g:02X}{b:02X}\n")
# from PIL import Image

# # Hardcode PNG file
# png = "8.png"

# SIZE = 32

# hexname = png.replace(".png", ".hex")

# img = Image.open(png).convert("RGBA")
# img = img.resize((SIZE, SIZE), Image.BICUBIC)

# with open(hexname, "w") as f:
#     for y in range(SIZE):
#         for x in range(SIZE):
#             r, g, b, a = img.getpixel((x, y))
#             if a < 20:   # transparent → magenta
#                 f.write("FF00FF\n")
#             else:
#                 f.write(f"{r:02X}{g:02X}{b:02X}\n")

# print(f"Generated {hexname}")
from PIL import Image
import os

# List of your letter PNG files
letters = ["U.png", "O.png", "T.png", "T2.png", "A.png", "H.png",
           "A2.png", "C.png", "K.png", "space.png", "8.png"]

SIZE = 32  # New size for all letters

for png in letters:
    if not os.path.exists(png):
        print(f"File not found: {png}")
        continue

    hexname = png.replace(".png", ".hex")
    
    img = Image.open(png).convert("RGBA")
    img = img.resize((SIZE, SIZE), Image.BICUBIC)
    
    with open(hexname, "w") as f:
        for y in range(SIZE):
            for x in range(SIZE):
                r, g, b, a = img.getpixel((x, y))
                if a < 20:  # transparent → magenta
                    f.write("FF00FF\n")
                else:
                    f.write(f"{r:02X}{g:02X}{b:02X}\n")
    
    print(f"Generated {hexname}")
