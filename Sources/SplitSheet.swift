//
//  SplitSheet.swift
//  SplitSheet
//
//  Created by A. Zheng (github.com/aheze) on 6/4/22.
//  Copyright © 2022 A. Zheng. All rights reserved.
//
//  -
//
//  MIT License
//
//  Copyright (c) 2022 A. Zheng
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import UIKit

public class SplitSheetController: UIViewController {
    // MARK: - External parameters

    /// The main content view controller.
    public let mainViewController: UIViewController

    /// The supplementary sheet view controller.
    public let sheetViewController: UIViewController

    /// If true, `mainViewController` will shift up as the sheet is shown.
    public var displaceContent = true

    /// Show a grabber handle.
    public var showHandle = true

    /// The minimum sheet height.
    public var minimumSheetHeight = CGFloat(400)

    /// When the sheet is shown and dragged within this limit, the sheet will bounce back.
    public var snappingDistance = CGFloat(150)

    /// How long the show/hide animation takes.
    public var animationDuration = CGFloat(0.6)

    /// If swiping up to show the sheet is allowed or not.
    public var swipeUpToShowAllowed = true

    /// Override the status bar color.
    public var statusBarStyle = UIStatusBarStyle.default

    // MARK: - State

    /// The current state of the sheet. `true` if shown, `false` if hidden.
    /// Observable with Combine.
    @objc public private(set) dynamic var showing = false

    // MARK: - Internal Properties

    public lazy var scrollView = UIScrollView()

    /// 2 "main" containers are needed to support `displaceContent` true/false.
    public lazy var mainPlaceholderContainerView = UIView() /// Provides a top anchor for `sheetContainerView`.
    public lazy var mainOuterContainerView = UIView() /// Pinned to the scroll view.
    public lazy var mainInnerContainerView = UIView() /// Embedded inside `mainOuterContainerView`.
    public lazy var sheetContainerView = UIView()
    public var handleView: UIView?

    /// Constraint to be adjusted later
    public lazy var mainOuterTopConstraint = mainOuterContainerView.topAnchor.constraint(equalTo: scrollView.topAnchor)
    public lazy var mainInnerBottomConstraint = mainInnerContainerView.bottomAnchor.constraint(equalTo: mainOuterContainerView.bottomAnchor)

    /// Make sure the sheet is at least as high as `minimumSheetHeight`.
    public lazy var sheetHeightConstraint = sheetContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: minimumSheetHeight)

    /// Create a new `SplitSheetController`.
    public init(
        mainViewController: UIViewController,
        sheetViewController: UIViewController
    ) {
        self.mainViewController = mainViewController
        self.sheetViewController = sheetViewController
        super.init(nibName: nil, bundle: nil)
        setup()
    }

    /// Apply `statusBarStyle`.
    override public var preferredStatusBarStyle: UIStatusBarStyle {
        return statusBarStyle
    }

    /// Dismiss the sheet after an orientation change.
    override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        show(false)
    }

    /// Boilerplate code
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("You must create this view controller programmatically.")
    }
}

// MARK: - Setup

public extension SplitSheetController {
    func setup() {
        // MARK: - Configuration

        scrollView.decelerationRate = .fast
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        if #available(iOS 11.0, *) {
            /// Prevent snapping to wrong offsets.
            scrollView.contentInsetAdjustmentBehavior = .never
        }

        updateShowing(false)

        // MARK: Add subviews

        view.addSubview(scrollView)
        scrollView.addSubview(mainPlaceholderContainerView)
        scrollView.addSubview(mainOuterContainerView)
        mainOuterContainerView.addSubview(mainInnerContainerView)
        scrollView.addSubview(sheetContainerView)

        // MARK: Add sub-view controllers

        embed(mainViewController, inside: mainInnerContainerView)
        embed(sheetViewController, inside: sheetContainerView)

        // MARK: Add constraints

        /// Basic pin-to-edge constraints.
        scrollView.pinEdgesToSuperview()

        /// More precise constraints.
        mainPlaceholderContainerView.translatesAutoresizingMaskIntoConstraints = false
        mainOuterContainerView.translatesAutoresizingMaskIntoConstraints = false
        mainInnerContainerView.translatesAutoresizingMaskIntoConstraints = false
        sheetContainerView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            mainPlaceholderContainerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            mainPlaceholderContainerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            mainPlaceholderContainerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            mainPlaceholderContainerView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),

            mainOuterContainerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            mainOuterContainerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            mainOuterContainerView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),

            /// These constraints will be modified later in `scrollViewDidScroll`.
            mainOuterTopConstraint,
            mainInnerBottomConstraint,

            mainInnerContainerView.trailingAnchor.constraint(equalTo: mainOuterContainerView.trailingAnchor), /// Pin to edges.
            mainInnerContainerView.leadingAnchor.constraint(equalTo: mainOuterContainerView.leadingAnchor),
            mainInnerContainerView.topAnchor.constraint(equalTo: mainOuterContainerView.topAnchor),

            sheetContainerView.topAnchor.constraint(equalTo: mainPlaceholderContainerView.bottomAnchor),
            sheetContainerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            sheetContainerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            sheetContainerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            sheetContainerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            /// Apply the minimum height constraint.
            sheetHeightConstraint,
        ])
    }

    /// Add a handle view.
    func addHandle() {
        guard self.handleView == nil else { return }
        let handleView = UIView()

        if #available(iOS 13.0, *) {
            handleView.backgroundColor = .secondaryLabel
        } else {
            handleView.backgroundColor = .gray
        }

        handleView.layer.cornerRadius = 2.5
        sheetContainerView.addSubview(handleView)
        handleView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            handleView.topAnchor.constraint(equalTo: sheetContainerView.topAnchor, constant: 9),
            handleView.centerXAnchor.constraint(equalTo: sheetContainerView.centerXAnchor),
            handleView.widthAnchor.constraint(equalToConstant: 36),
            handleView.heightAnchor.constraint(equalToConstant: 5),
        ])
        self.handleView = handleView
    }
}

// MARK: - Update state

public extension SplitSheetController {
    /// Show or hide the scroll sheet.
    func show(_ shouldShow: Bool) {
        updateShowing(shouldShow)

        UIView.animate(
            withDuration: animationDuration,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 1
        ) {
            if shouldShow {
                self.scrollView.contentOffset.y = self.minimumSheetHeight
            } else {
                self.scrollView.contentOffset.y = 0
            }
            self.scrollView.layoutIfNeeded() /// Needed to animate constraints correctly.
        }
    }

    /// Update `showing` and other properties.
    private func updateShowing(_ showing: Bool) {
        self.showing = showing

        /// If `swipeUpToShowAllowed` is not enabled, prevent scrolling up when hidden.
        if !swipeUpToShowAllowed {
            scrollView.isScrollEnabled = showing
        }

        if showHandle {
            addHandle()
        } else if let handleView = handleView {
            handleView.removeFromSuperview() /// Hide the handle if it already exists.
            self.handleView = nil
        }
    }
}

// MARK: - Observe scroll view

extension SplitSheetController: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        mainOuterTopConstraint.constant = scrollView.contentOffset.y

        if displaceContent {
            mainInnerBottomConstraint.constant = -min(
                scrollView.contentOffset.y, /// Shrink the main view controller's height...
                view.bounds.height /// ... but make sure it doesn't shrink under 0.
            )
        } else {
            mainInnerBottomConstraint.constant = 0
        }
    }

    public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        /// The distance to the just-shown detent (shown, but not fully expanded).
        let distanceToShown = minimumSheetHeight - targetContentOffset.pointee.y

        /// The content offset where the sheet is hidden.
        let hiddenDetent = CGFloat(0)

        /// The content offset where the sheet is *just* shown.
        let shownDetent = minimumSheetHeight

        /// The content offset where the scroll view hits the bottom.
        let expandedDetent = scrollView.contentSize.height - scrollView.bounds.height

        let detents = [hiddenDetent, shownDetent, expandedDetent]
        let predictedContentOffset = targetContentOffset.pointee.y /// Use the system-predicted target content to take care of flicking with the finger.

        print("distanceToShown: \(distanceToShown)")
        switch velocity.y {
        /// When the velocity is negative (scrolled down.)
        case ..<0:

            /// Only select smaller detents (prevents a flickering glitch.)
            let availableDetents = detents.filter { $0 < predictedContentOffset }
            let closestDetent = availableDetents.min { abs(predictedContentOffset - $0) < abs(predictedContentOffset - $1) }
            targetContentOffset.pointee.y = closestDetent ?? 0 /// If scrolling overshot, just hide the sheet.

        /// When the velocity is positive (scrolled up.)
        case CGFloat.leastNormalMagnitude...:

            /// Only select larger detents (prevents a flickering glitch.)
            let availableDetents = detents.filter { $0 > predictedContentOffset }
            let closestDetent = availableDetents.min { abs(predictedContentOffset - $0) < abs(predictedContentOffset - $1) }
            targetContentOffset.pointee.y = closestDetent ?? expandedDetent /// If scrolling overshot, fully expand the sheet.

        /// Handle velocity == 0 case.
        default:

            /// Ignore if sheet was released near the `expanded` detent.
            guard distanceToShown > -snappingDistance else { return }

            if distanceToShown < snappingDistance {
                targetContentOffset.pointee.y = minimumSheetHeight
            } else {
                targetContentOffset.pointee.y = 0 /// Hide if near the bottom.
            }
        }
        
        /// When the offset is 0, the sheet is hidden. Otherwise, it's shown.
        updateShowing(targetContentOffset.pointee.y != 0)
    }
}

public extension UIViewController {
    /// The parent scroll sheet controller if it exists.
    var parentSplitSheetController: SplitSheetController? {
        if let splitSheetController = parent as? SplitSheetController {
            return splitSheetController
        } else {
            print("[\(self)] isn't embedded in a split sheet controller.")
            return nil
        }
    }
}

// MARK: - Utilities

public extension UIView {
    /// Pin a view to its parent.
    func pinEdgesToSuperview() {
        guard let superview = superview else { return }
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: superview.topAnchor),
            rightAnchor.constraint(equalTo: superview.rightAnchor),
            bottomAnchor.constraint(equalTo: superview.bottomAnchor),
            leftAnchor.constraint(equalTo: superview.leftAnchor),
        ])
    }
}

public extension UIViewController {
    /// Add a child view controller inside a view.
    func embed(_ childViewController: UIViewController, inside view: UIView) {
        /// Add the view controller as a child
        addChild(childViewController)

        /// Insert as a subview.
        view.insertSubview(childViewController.view, at: 0)

        childViewController.view.pinEdgesToSuperview()

        /// Notify the child view controller.
        childViewController.didMove(toParent: self)
    }
}
