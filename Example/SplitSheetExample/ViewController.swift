//
//  ViewController.swift
//  SplitSheetExample
//
//  Created by A. Zheng (github.com/aheze) on 6/5/22.
//  Copyright © 2022 A. Zheng. All rights reserved.
//

import Combine
import SplitSheet
import UIKit

enum Shared {
    /// Store references to Combine sinks.
    /// Used for observing changes in `parentSplitSheetController.$showing`.
    static var cancellables = Set<AnyCancellable>()
}

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

class MainViewController: UIViewController {
    lazy var imageView: UIImageView = {
        /// image credit: https://unsplash.com/photos/aEK8X33l7V4
        let image = UIImage(named: "Image")
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true

        view.addSubview(imageView)
        imageView.pinEdgesToSuperview()
        return imageView
    }()

    lazy var button: UIButton = {
        var container = AttributeContainer()
        container.font = UIFont.boldSystemFont(ofSize: 32)

        var configuration = UIButton.Configuration.borderedProminent()
        configuration.buttonSize = .large

        let button = UIButton(configuration: configuration)
        button.addAction(for: .touchUpInside) { [weak parentSplitSheetController] _ in
            guard let parentSplitSheetController = parentSplitSheetController else { return }
            parentSplitSheetController.show(!parentSplitSheetController.showing)
        }

        view.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        if let parentSplitSheetController = parentSplitSheetController {
            parentSplitSheetController
                .publisher(for: \.showing)

                /// Called whenever `parentSplitSheetController.showing` changes.
                /// Note: is also called immediately - see https://stackoverflow.com/q/60568858/14351818
                .sink { [weak button] showing in
                    configuration.baseBackgroundColor = showing ? UIColor.systemGreen : UIColor.systemOrange
                    configuration.attributedTitle = AttributedString(showing ? "Sheet Shown" : "Sheet Hidden", attributes: container)
                    button?.configuration = configuration
                }
                .store(in: &Shared.cancellables)
        }

        return button
    }()

    @objc var toggleSheet: (() -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        _ = imageView
        _ = button
    }
}

class SheetViewController: UIViewController {
    lazy var label: UILabel = {
        let label = UILabel()
        label.text = "Hi! I'm a sheet view controller. You can put anything here!"
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .title1)
        label.numberOfLines = 0

        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 64),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -600),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
        ])
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        _ = label
    }
}

/// from https://www.biteinteractive.com/control-target-and-action-in-ios-14
extension UIControl {
    func addAction(for event: UIControl.Event, handler: @escaping UIActionHandler) {
        addAction(UIAction(handler: handler), for: event)
    }
}
