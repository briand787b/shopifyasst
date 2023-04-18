ffmpeg -i small.mp4 -i watermark-citystock.png \
    -filter_complex "[1]lut=a=val*0.3[a];[0][a]overlay=(main_w-overlay_w)/2:(main_h-overlay_h)/2" \
    -codec:a copy output.mp4