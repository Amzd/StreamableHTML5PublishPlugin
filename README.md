# StreamableHTML5PublishPlugin

Use streamable videos without iframe, embed or javascript.


## Usage

```swift
.installPlugin(.streamableToHTML5Video())
.installPlugin(.streamableDuration())
```

## What it does

Converts codeblocks:

    ```streamable
    video: 4vbhuo
    poster: /files/IMG_5190.JPG
    options: controls muted autoplay loop
    ```

or images (so you can use this in tables):

    ![]({ "video": "gle2pp", "poster": "/files/IMG_5190.JPG", "options": "controls muted autoplay loop" })

to 

```html
<video id="streamable-video-player-4vbhuo" class="streamable-video-player" poster="/files/IMG_5190.JPG" controls muted autoplay loop>
    <source src="<DIRECT_URL_TO_STREAMABLE_VIDEO>" type="video/mp4">
</video>
```

using the streamable API to get the direct url to the mp4 file. 

And adds `Item.streamableVideos.totalDuration` to grab the total duration of videos in that Item.

## Expiring direct urls

The direct url to the mp4 file of your streamable video expires and you will have to generate your website again every few days to grab a new url again. In my experience the expiration time is 4 days.

`streamableToHTML5Video(useCacheUntilExpiresWithin:)` uses 86400 (aka one day) as default. This means that if the cached direct URL expires within a day, it will get a new one from the streamable API.

So if you would make sure that exactly every 3 days you regenerate your website then you barely cover it so there will never be expired link on your website.

I have a [Github Action that runs on schedule](https://docs.github.com/en/free-pro-team@latest/actions/reference/events-that-trigger-workflows#schedule) every 2 days and use the default cache expires within 1 day to be sure I will always have valid streaming urls.
