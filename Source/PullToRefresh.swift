//
//  PullToRefresh.swift
//  Refreshable
//
//  Created by Hoangtaiki on 7/20/18.
//  Copyright © 2018 toprating. All rights reserved.
//

import UIKit
import QuartzCore

/// Pull To Refresh State
/// idle
/// loading: When user
/// pullToRefresh: When scrollview is scroll
/// releaseToRefresh: When scrolled distance are larger than view's height
public enum PullToRefreshState {
    case idle
    case loading
    case pullToRefresh
    case releaseToRefresh
}

public protocol PullToRefreshDelegate {
    func pullToRefreshAnimationDidStart(_ view: PullToRefreshView)
    func pullToRefreshAnimationDidEnd(_ view: PullToRefreshView)
    func pullToRefresh(_ view: PullToRefreshView, stateDidChange state: PullToRefreshState)
}

public class PullToRefreshView: UIView {
    
    public var activityIndicatorViewStyle:UIActivityIndicatorView.Style = .gray
    
    var isLoading: Bool = false {
        didSet {
            if isLoading != oldValue {
                if isLoading {
                    startAnimating()
                } else {
                    stopAnimating()
                }
            }
        }
    }

    private var observation: NSKeyValueObservation?
    private var scrollView: UIScrollView!
    private var originalContentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    private var insetTopDelta: CGFloat = 0.0

    private var animator: PullToRefreshDelegate
    private var action: (() -> ()) = {}


    convenience init(action: @escaping (() -> ()), frame: CGRect,activityIndicatorViewStyle:UIActivityIndicatorView.Style = .gray) {
        var bounds = frame
        bounds.origin.y = 0
        let animator = PullToRefreshAnimator(frame: bounds,style: activityIndicatorViewStyle)
        self.init(frame: frame, animator: animator)
        self.action = action
        addSubview(animator)
    }

    convenience init(action: @escaping (() -> ()), frame: CGRect, animator: PullToRefreshDelegate & UIView) {
        self.init(frame: frame, animator: animator)
        self.action = action
        animator.frame = bounds
        addSubview(animator)
    }

    public init(frame: CGRect, animator: PullToRefreshDelegate & UIView) {
        self.animator = animator
        super.init(frame: frame)
        self.autoresizingMask = .flexibleWidth
    }

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func willMove(toSuperview newSuperview: UIView!) {
        super.willMove(toSuperview: newSuperview)

        guard newSuperview is UIScrollView else { return }

        observation?.invalidate()
        scrollView = newSuperview as? UIScrollView
        scrollView.alwaysBounceVertical = true
        originalContentInset = scrollView.contentInset

        observation = scrollView.observe(\.contentOffset, options: [.initial]) { [unowned self] (sc, change) in
            self.handleScrollViewOffsetChange()
        }
    }

    deinit {
        observation?.invalidate()
    }
}

extension PullToRefreshView {

    private func handleScrollViewOffsetChange() {

        // Why we need that code when isLoading?
        // We need handle two case
        // 1. It is normal case: Scroll and drag then scrollview will scroll to a postion and spin
        // After spin scrollview will scroll to original content inset
        // 2. After scrollview move to and spin. User scroll up. RefreshView and spinner is moved to offset
        // In this case we will update scrollview inset to default value
        if isLoading {
            let contentOffset = scrollView.contentOffset
            var oldInset = scrollView.contentInset
            var insetTop = originalContentInset.top

            if -contentOffset.y > originalContentInset.top {
                insetTop = -contentOffset.y
            }

            if insetTop > frame.size.height + originalContentInset.top {
                insetTop = frame.size.height + originalContentInset.top
            }
            oldInset.top = insetTop

            scrollView.contentInset = oldInset
            insetTopDelta = originalContentInset.top - insetTop
            return
        }

        var adjustedContentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        if #available(iOS 11.0, *) {
            adjustedContentInset = scrollView.adjustedContentInset
        }

        originalContentInset = scrollView.contentInset

        // We only trigger when use scroll down
        // And content offset must be less than -adjustedContentInset.top
        if scrollView.contentOffset.y < -adjustedContentInset.top {
            if abs(scrollView.contentOffset.y) - adjustedContentInset.top > frame.size.height {
                // After scrollview is scrolled down and it isn't dragged
                // We will animate scrollview (inset and offset) then start spinner animation
                if !scrollView.isDragging {
                    isLoading = true
                    animator.pullToRefresh(self, stateDidChange: .loading)
                } else {
                    animator.pullToRefresh(self, stateDidChange: .releaseToRefresh)
                }
            } else {
                animator.pullToRefresh(self, stateDidChange: .pullToRefresh)
            }
        }

        // When scrollview offset return to the original content offset
        // We will change state to idle and stop spinner
        if -scrollView.contentOffset.y == adjustedContentInset.top {
            animator.pullToRefresh(self, stateDidChange: .idle)
        }
    }

    private func startAnimating() {
        let frameHeight = frame.size.height
        let contentInset = scrollView.contentInset
        var contentOffset = CGPoint(x: 0, y: -frameHeight)
        if #available(iOS 11.0, *) {
            contentOffset.y = -scrollView.adjustedContentInset.top - frameHeight
        }
        UIView.animate(withDuration: 0.3, delay: 0, options: UIView.AnimationOptions(), animations: {
            self.scrollView.contentInset = UIEdgeInsets(top: frameHeight + contentInset.top, left: 0, bottom: 0, right: 0)
            self.scrollView.contentOffset = contentOffset
        }, completion: { finished in
            self.animator.pullToRefreshAnimationDidStart(self)
            self.action()
        })
    }

    private func stopAnimating() {
        UIView.animate(withDuration: 0.3, animations: {
            var oldInset = self.scrollView.contentInset
            oldInset.top = oldInset.top + self.insetTopDelta
            self.scrollView.contentInset = oldInset
        }, completion: { finished in
            self.animator.pullToRefreshAnimationDidEnd(self)
        })
    }
}
