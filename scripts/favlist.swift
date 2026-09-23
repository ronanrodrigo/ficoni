// favlist.swift — enumerate / add / remove Finder sidebar favorites via LSSharedFileList
// usage: favlist list | favlist add <path> | favlist remove <path>
import Foundation
import CoreServices

func favoritesList() -> LSSharedFileList? {
    LSSharedFileListCreate(nil, kLSSharedFileListFavoriteItems.takeRetainedValue(), nil)?.takeRetainedValue()
}

let args = CommandLine.arguments
let mode = args.count > 1 ? args[1] : "list"

if mode == "list" {
    guard let list = favoritesList() else { exit(1) }
    var seed: UInt32 = 0
    guard let items = LSSharedFileListCopySnapshot(list, &seed)?.takeRetainedValue() as? [LSSharedFileListItem] else { exit(1) }
    for (i, it) in items.enumerated() {
        let name = LSSharedFileListItemCopyDisplayName(it).takeRetainedValue() as String
        var urlStr = ""
        if let u = LSSharedFileListItemCopyResolvedURL(it, 0, nil) { urlStr = (u.takeRetainedValue() as URL).absoluteString }
        print("\(i)\t\(name)\t\(urlStr)")
    }
} else if mode == "add", args.count >= 3 {
    guard let list = favoritesList() else { exit(1) }
    let url = URL(fileURLWithPath: (args[2] as NSString).expandingTildeInPath)
    let item = LSSharedFileListInsertItemURL(list, kLSSharedFileListItemLast.takeRetainedValue(), nil, nil, url as CFURL, nil, nil)
    print(item != nil ? "added \(url.path)" : "failed")
} else if mode == "remove", args.count >= 3 {
    guard let list = favoritesList() else { exit(1) }
    var seed: UInt32 = 0
    guard let items = LSSharedFileListCopySnapshot(list, &seed)?.takeRetainedValue() as? [LSSharedFileListItem] else { exit(1) }
    let target = (args[2] as NSString).expandingTildeInPath
    var removed = false
    for it in items where (LSSharedFileListItemCopyResolvedURL(it, 0, nil).map { ($0.takeRetainedValue() as URL).path } == target) {
        LSSharedFileListItemRemove(list, it); removed = true
    }
    print(removed ? "removed \(target)" : "not found \(target)")
}
