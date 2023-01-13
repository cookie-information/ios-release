import UIKit

final class PopUpPresentationController: UIPresentationController {
    override var shouldPresentInFullscreen: Bool { false }
    
    override var shouldRemovePresentersView: Bool { false }
    
    override var frameOfPresentedViewInContainerView: CGRect {
        let superFrame = super.frameOfPresentedViewInContainerView
        let safeAreaInsets = presentingViewController.view.safeAreaInsets
        
        let hInset: CGFloat = 10
        let vInset: CGFloat = 10
        
        return CGRect(
            x: hInset,
            y: safeAreaInsets.top + vInset,
            width: superFrame.width - 2 * hInset,
            height: superFrame.height - safeAreaInsets.bottom - safeAreaInsets.top - 2 * vInset
        )
    }
    
    override func presentationTransitionWillBegin() {
        containerView?.backgroundColor = .popUpOverlay
        presentedView?.layer.cornerRadius = 5
        presentedView?.layer.masksToBounds = true
    }
}
