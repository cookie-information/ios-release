import UIKit

final class GradientContainer<T: UIScrollView>: UIView {
    struct Config {
        let color: UIColor
        let gradientHeight: CGFloat
        let gradientHorizontalInset: CGFloat
        let gradientBottomOffset: CGFloat
    }
    
    let view: T

    private let containerStackView = UIStackView()
    private let gradientView: GradientView
    private let config: Config
    
    private var contentOffsetObservation: NSKeyValueObservation?
    
    private var gradientAlpha: CGFloat = 1.0 {
        didSet {
            gradientView.gradientAlpha = gradientAlpha
        }
    }
    
    init(_ scrollView: T, config: Config) {
        self.view = scrollView
        self.config = config
        self.gradientView = GradientView(color: config.color)
        
        super.init(frame: .zero)
        
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        setupScrollView()
    }
    
    private func setupScrollView() {
        view.clipsToBounds = true

        addSubview(view)
        
        view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        contentOffsetObservation = view.observe(\.contentOffset) { [weak self] _, _ in
            self?.scrollViewDidScroll()
        }
        
        addSubview(gradientView)
        
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        gradientView.isUserInteractionEnabled = false
        
        NSLayoutConstraint.activate([
            gradientView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: config.gradientBottomOffset),
            gradientView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: config.gradientHorizontalInset),
            gradientView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -config.gradientHorizontalInset),
            gradientView.heightAnchor.constraint(equalToConstant: config.gradientHeight)
        ])
    }
    
    private func scrollViewDidScroll() {
        let scrolledOffset = view.contentOffset.y + view.frame.height
        let scrollDifference = view.contentSize.height - scrolledOffset
        let alphaChangeRange: ClosedRange<CGFloat> = 0...16
        let clampedDifference = scrollDifference.clamped(to: alphaChangeRange)
        
        gradientAlpha = clampedDifference / alphaChangeRange.upperBound
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private final class GradientView: UIView {
    private let gradientLayer = CAGradientLayer()
    private let gradientColor: UIColor
    
    var gradientAlpha: CGFloat = 1.0 {
        didSet { updateGradientColors() }
    }
    
    init(color: UIColor) {
        self.gradientColor = color
        
        super.init(frame: .zero)
        
        layer.addSublayer(gradientLayer)
        
        updateGradientColors()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        gradientLayer.frame = bounds
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if #available(iOS 12.0, *) {
            guard traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle else {
                return
            }
        } else {
            return
        }
        
        updateGradientColors()
    }
    
    private func updateGradientColors() {
        gradientLayer.colors = [
            gradientColor.withAlphaComponent(0.0).cgColor,
            gradientColor.withAlphaComponent(gradientAlpha).cgColor
        ]
    }
}
