from exif import Image

import exifread


with open('small.jpg', 'rb') as image_file:
    tags = exifread.process_file(image_file, debug=True)
    # my_image = Image(image_file)

# print(f'{my_image.has_exif =}')
print(f'{tags = }')