import Cocoa
import FinderSync

@objc(SyncExtension)
class SyncExtension: FIFinderSync {
    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "__TARGET__")]
    }
}
