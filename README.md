# SyncStartTV

Shows how to synchronize playback of two live HLS streams.

## Overview

This sample requires that two live HLS streams be set up (although a single stream can be used twice for demonstration). Each stream must contain `EXT-X-PROGRAM-DATE-TIME` tags; the dates must accurately reflect the authoring time of each segment, and must be based on a common clock.


## Getting Started

This sample requires tvOS 11 or greater, and Xcode 9 or greater. (It is also possible to run this code on iOS 11 instead, with minor modifications.)

This sample requires two HLS live streams that are advertised via Bonjour as HTTP services, with the URL path in the "path" element of the TXT record. The path must specify a live m3u8 playlist.

You can set up a proxy advertisement to an existing stream by using the dns-sd command line tool running on a computer on the same local network link. For example, the following command will advertise http://live.example.com/LIVE/master.m3u8:

```
dns-sd -P "My live stream on example.com" "_http._tcp" "" 80 live.example.com live.example.com path=/LIVE/master.m3u8
```

Each HLS live stream must contain `EXT-X-PROGRAM-DATE-TIME` tags. The dates must be based on a shared clock, and they must be exact (i.e., to within a frame duration, using millisecond-level dates such as 2010-02-19T14:54:23.031Z). A single stream can be used instead of two streams; it just won't be as interesting.

Once the streams are set up, tapping "Select Left Video" or "Select Right Video" will bring up a browser that will display the advertised URLs. Selecting a page will start the stream. Select the left video to start it, then select the right video to have it join playback in sync with the left video.

## The BrowseViewController

The BrowseViewController implements a generic Bonjour service browser that browses for HTTP service advertisements

## ViewController.swift

This UIViewController coordinates the selection of the Left Video stream and the Right View stream. It starts each stream playing as soon as it is selected. The first stream starts playing at the live edge of the stream. The second stream to be selected will sync its playback position to that of the first stream, and begin playing in sync.

The basic approach to starting a second stream playing in sync with a first is:

1. Start the first stream playing (at rate 1.0).

2. Seek the second stream to the vicinity of the first.

3. Use the AVPlayerItem currentTime and currentDate properties of each stream to determine their relative time offset, relying on the fact that the dates are in sync.

4. Wait until the second player has enough buffered ahead of the current position of the first player to begin playback of the second player.

5. Once the second player has enough buffered, use the `AVPlayer` `setRate( time: atHostTime:)` method to set the rate on the second player to 1.0. To start it in sync with the first player, get the current time of the first player and the corresponding host time, then pass the corresponding time in the second player and the host time to the setRate call. See tryToStartSecondPlayerInSync() for more detail.
