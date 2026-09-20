# The social card

`card.html` is the source of `app/assets/images/landing-og.jpg`: the hero
artwork with the headline card over it. Edit the text here, then render it
with headless Chrome at twice the size and downsample:

```sh
cd site/script/og
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --disable-gpu --hide-scrollbars \
  --window-size=1200,630 --force-device-scale-factor=2 --virtual-time-budget=8000 \
  --screenshot=card-2x.png "file://$PWD/card.html"
magick card-2x.png -resize 1200x630 -strip -quality 88 ../../app/assets/images/landing-og.jpg
rm card-2x.png
```

The fonts load from Google Fonts, so the render needs the network; the
virtual time budget gives them time to arrive before the shot.
