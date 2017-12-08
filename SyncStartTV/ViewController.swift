/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 ViewController for the main view
 */

import UIKit
import AVFoundation

class ViewController: UIViewController, NetServiceDelegate {
    
    let kVideoButtonTagBase: Int = 100
    let kVideoViewTagBase: Int = 200
    
    @IBOutlet weak var leftButton: UIButton!
    @IBOutlet weak var rightButton: UIButton!
    
    var resolvingService: NetService?
    var players: [AVPlayer]
    var items: [AVPlayerItem]
    var timeToDateMapping: [TimeInterval]
    var startedFirst: Bool
    var positionedSecond: Bool
    var startedSecond: Bool
    var used: Bool
    
    required init?(coder: NSCoder) {
        self.resolvingService = nil
        self.players = []
        self.items = []
        self.timeToDateMapping = []
        self.startedFirst = false
        self.positionedSecond = false
        self.startedSecond = false
        self.used = false
        super.init(coder: coder)
    }
    
    /// Create a new player that is bound to the view corresponding to buttonTag
    func bindNewPlayerToView(buttonTag: Int) {
        let player = AVPlayer()
        players.append(player)
        
        let playerLayer = AVPlayerLayer(player: player)
        if let videoView = view.viewWithTag(buttonTag - kVideoButtonTagBase + kVideoViewTagBase) {
            videoView.layer.addSublayer(playerLayer)
        }
        playerLayer.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 960, height: 540))
    }
    
    /// Provide the network address of the target stream to the currently-initializing player
    func setupPlayer(hostName: String, port: Int, path: String) {
        guard let index = players.indices.last else { return }
        
        /* How to Bonjour-advertise a remote site, from a Mac in Terminal:
         dns-sd -P "<title>" "_http._tcp" "" <port> <host> <IP> <TXT>
         for example,
         dns-sd -P "My live stream on example.com" "_http._tcp" "" 80 live.example.com live.example.com path=/LIVE/master.m3u8
         */
        
        let url = String(format: "http://%@:%d%@", hostName, port, path.isEmpty ? "/" : path)
        let asset = AVAsset(url: URL(string: url)!)
        items.append(AVPlayerItem(asset: asset))
        if index == 0 {
            items[index].addObserver(self, forKeyPath: "loadedTimeRanges", options: [], context: &firstPlayerKVOContext)
            items[index].addObserver(self, forKeyPath: "status", options: [], context: &firstPlayerKVOContext)
        } else if index == 1 {
            items[index].addObserver(self, forKeyPath: "loadedTimeRanges", options: [], context: &secondPlayerKVOContext)
            items[index].addObserver(self, forKeyPath: "status", options: [], context: &secondPlayerKVOContext)
        }
        
        players[index].isMuted = true // do not attempt to mix audio
        players[index].replaceCurrentItem(with: items[index])
    }
    
    /// Retrieve the chosen service record advertising the stream from the BrowseViewController when it is dismissed
    @IBAction func myUnwindAction(unwindSegue: UIStoryboardSegue) {
        if let browserView = unwindSegue.source as? BrowseViewController {
            resolvingService = browserView.selectedService
        }
    }
    
    /// When focus returns to UIButton following a Browse segue, initiate playback in the appropriate view
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        if context.previouslyFocusedView == nil {
            if leftButton.isFocused || rightButton.isFocused {
                if resolvingService != nil {
                    bindNewPlayerToView(buttonTag: context.nextFocusedView!.tag)
                    resolvingService!.delegate = self
                    resolvingService!.resolve(withTimeout: 5.0)
                    
                    let buttonToDisable = leftButton.isFocused ? leftButton : rightButton
                    buttonToDisable?.isEnabled = false // disable button to block reselection
                    setNeedsFocusUpdate()
                }
            }
        }
    }
    
    /// NetServiceDelegate callback, called when Bonjour service is resolved
    func netServiceDidResolveAddress(_ sender: NetService) {
      var path = ""
        if let txtRecordData = sender.txtRecordData() {
            let txtDict = NetService.dictionary(fromTXTRecord: txtRecordData)
            if let pathData = txtDict["path"] {
                path = String(data: pathData, encoding: .utf8)!
            }
            
        }
      
      setupPlayer(hostName: "127.0.0.1", port: 80, path: path)
        
    }
    
    func getBufferedDurationAheadOf(item: AVPlayerItem, mark: CMTime) -> Double {
        if let lastRangeValue = item.loadedTimeRanges.last {
            let loadedRange = lastRangeValue.timeRangeValue
            if mark >= loadedRange.start {
                return CMTimeGetSeconds(CMTimeSubtract(CMTimeAdd(loadedRange.start, loadedRange.duration), mark))
            }
        }
        
        return 0.0
    }
    
    func establishDateMapping(forItem: Int) {
        // the time-to-date mapping must be established while the rate is 0
        if let currentDate = items[forItem].currentDate() {
            let currentTime = CMTimeGetSeconds(items[forItem].currentTime())
            timeToDateMapping.append(currentTime - currentDate.timeIntervalSinceReferenceDate)
        }
    }
    
    /// Given that player[0] is running and player[1] is starting, return the current playback time in three forms:
    ///        - in the timebase time of the starter
    ///        - as a Date
    ///        - in host time
    func getRunnerTimeForStarter() -> (CMTime, Date, CMTime) {
        let currentHostTime = CMClockGetTime(CMClockGetHostTimeClock())
        let currentTimeOfRunner = items[0].currentTime()
        let offsetToRunner = timeToDateMapping[1] - timeToDateMapping[0]
        
        let dateCorrespondingToNowInRunner = Date(timeIntervalSinceReferenceDate: CMTimeGetSeconds(currentTimeOfRunner) - timeToDateMapping[0])
        let timeInStarterCorrespondingToNowInRunner = CMTimeAdd(currentTimeOfRunner, CMTimeMakeWithSeconds(offsetToRunner, 90_000))
        return (timeInStarterCorrespondingToNowInRunner, dateCorrespondingToNowInRunner, currentHostTime)
    }
    
    /// Check if player[1] has buffered enough to start playing in sync with player[0]
    func tryToStartSecondPlayerInSync() {
        // The player needs a bit buffered ahead of the common start time in order to start cleanly
        let (timeInStarterCorrespondingToNowInRunner, currentDateOfRunner, _) = getRunnerTimeForStarter()
        let timeAhead = getBufferedDurationAheadOf(item: items[1], mark: timeInStarterCorrespondingToNowInRunner)
        if timeAhead >= 1.0 {
            // Move the playhead to the start position and then set rate to 1.0
            players[1].currentItem!.seek(to: currentDateOfRunner, completionHandler: { _ in
                let (timeInStarterCorrespondingToNowInRunner, _, currentHostTime) = self.getRunnerTimeForStarter()
                self.players[1].setRate(1.0, time: timeInStarterCorrespondingToNowInRunner, atHostTime: currentHostTime)
                print("CT", currentHostTime)
            })
        } else {
            let when = DispatchTime.now() + .milliseconds(200)
            DispatchQueue.main.asyncAfter(deadline: when, execute: {
                self.tryToStartSecondPlayerInSync()
            })
        }
    }
    
    /// Tell player to seek to the live edge, but in terms of date to ensure that player establishes its date mapping
    func seekToLiveByDate(player: AVPlayer) {
        if let currentDate = player.currentItem!.currentDate(),
            let seekableRange = player.currentItem?.seekableTimeRanges.first?.timeRangeValue {
            startedFirst = true
            let timeFromEnd = CMTimeSubtract(CMTimeAdd(seekableRange.start, seekableRange.duration), player.currentTime())
            let endDate = currentDate.addingTimeInterval(CMTimeGetSeconds(timeFromEnd))
            player.currentItem!.seek(to: endDate, completionHandler: { _ in })
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &firstPlayerKVOContext { // this is the first player selected; begin by having it seek to current date
            if keyPath == "loadedTimeRanges" && !startedFirst {
                establishDateMapping(forItem: 0)
                seekToLiveByDate(player: players[0])
                players[0].rate = 1.0 // and then start playing as soon as possible
                startedFirst = true
            }
        } else if context == &secondPlayerKVOContext { // this is the second player to be selected:
            // once it is ready to play, move it to time of first player and start it
            if keyPath == "loadedTimeRanges" {
                if !positionedSecond { // first time we become ready to play, seek to vicinity of first player
                    seekToLiveByDate(player: players[1])
                    positionedSecond = true
                }
            } else if keyPath == "status" && players[1].currentItem!.status == .readyToPlay {
                if !startedSecond { // the first time we become readyToPlay, we are eligible to start playing in sync
                    startedSecond = true
                    establishDateMapping(forItem: 1)
                    players[1].automaticallyWaitsToMinimizeStalling = false // necessary before calling setRate(_:time:atHostTime:)
                    tryToStartSecondPlayerInSync()
                }
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}

// Used for the KVO.
private var firstPlayerKVOContext = 0
private var secondPlayerKVOContext = 0

