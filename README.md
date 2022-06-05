# SplitSheet

A split sheet made with `UIScrollView`.

https://user-images.githubusercontent.com/49819455/172063485-9cf70388-cad3-4c79-97ec-e73a176e73d8.mp4

### Installation
Add the Swift Package Manager URL:

```
https://github.com/aheze/SplitSheet
```

### Usage

```swift
import Combine
import SplitSheet
import UIKit

class ViewController: UIViewController {
    let mainViewController = MainViewController()
    let sheetViewController = SheetViewController()
    lazy var splitSheetController = SplitSheetController(
        mainViewController: mainViewController,
        sheetViewController: sheetViewController
    )

    override var childForStatusBarStyle: UIViewController? {
        return splitSheetController
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        /// If true, `mainViewController` will shift up as the sheet is shown.
        splitSheetController.displaceContent = true

        /// Show a grabber handle.
        splitSheetController.showHandle = true

        /// The minimum sheet height.
        splitSheetController.minimumSheetHeight = CGFloat(400)

        /// When the sheet is shown and dragged within this limit, the sheet will bounce back.
        splitSheetController.snappingDistance = CGFloat(150)

        /// How long the show/hide animation takes.
        splitSheetController.animationDuration = CGFloat(0.6)

        /// If swiping up to show the sheet is allowed or not.
        splitSheetController.swipeUpToShowAllowed = true

        /// Override the status bar color.
        splitSheetController.statusBarStyle = UIStatusBarStyle.default
        
        /// Add the sheet.
        embed(splitSheetController, inside: view)
    }
}
```
