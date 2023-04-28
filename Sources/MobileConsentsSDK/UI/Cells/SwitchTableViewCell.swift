import UIKit

final class SwitchTableViewCell: BaseTableViewCell {
    var valueChanged: ((Bool) -> Void)?
    private var viewModel: SwitchCellViewModel?

    private let uiSwitch = UISwitch()
    
    private lazy var titleView: UILabel =  {
        let label = UILabel()
        label.adjustsFontForContentSizeCategory = true
        label.font = .systemFont(ofSize: 17, weight: .regular)
        return label
    }()
    
    private lazy var descriptionView: UILabel = {
        let label = UILabel()
        label.adjustsFontForContentSizeCategory = true
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 0
        label.isEnabled = false
        
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        titleView.text = nil
        descriptionView.text = nil
        uiSwitch.isOn = false
        valueChanged = nil
        isSeparatorHidden = true
    }
    
    func setViewModel(_ viewModel: SwitchCellViewModel) {
        self.viewModel = viewModel
        
        titleView.text = viewModel.title
        titleView.font = UIFontMetrics(forTextStyle: .title3).scaledFont(for: viewModel.fontSet.body.withSize(17))
        titleView.accessibilityLabel = "\(viewModel.title) \n \(viewModel.description)"
        
        descriptionView.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: viewModel.fontSet.body)
        if viewModel.description.containsHtml, let attributedString = viewModel.description.attributedHtmlString {
            descriptionView.attributedText = attributedString

        } else {
            descriptionView.text = viewModel.description
        }

        setIsSelected(viewModel.isRequired || viewModel.isSelected) //required settings will be selected by default
        uiSwitch.onTintColor = viewModel.accentColor
        uiSwitch.isEnabled = !viewModel.isRequired
        uiSwitch.accessibilityLabel = "\(viewModel.title) switch"
        valueChanged = { [weak viewModel] isSelected in
            viewModel?.selectionDidChange(isSelected)
        }
        
        viewModel.onUpdate = { [weak self] viewModel in
            self?.setIsSelected(viewModel.isSelected)
        }
        
        
    }
    
    func setIsSelected(_ isSelected: Bool) {
        uiSwitch.isOn = isSelected
        
    }
    
    func setText(_ text: String, isRequired: Bool) {
        
    }
    
    
    func setValue(_ value: Bool) {
        uiSwitch.isOn = value
    }
    
    private func setup() {
        accessibilityElements = [titleView, uiSwitch]
        selectionStyle = .none
        self.isSeparatorHidden = false
        uiSwitch.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        
        contentView.addSubview(titleView)
        contentView.addSubview(uiSwitch)
        contentView.addSubview(descriptionView)
        
        titleView.translatesAutoresizingMaskIntoConstraints = false
        uiSwitch.translatesAutoresizingMaskIntoConstraints = false
        titleView.translatesAutoresizingMaskIntoConstraints = false
        descriptionView.translatesAutoresizingMaskIntoConstraints = false
        
        
        NSLayoutConstraint.activate([
            titleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 27),
            // Setting constraint to `uiSwitch.leadingAnchor` causes layout to
            // break when cell is reused
            titleView.trailingAnchor.constraint(equalTo: uiSwitch.leadingAnchor, constant: -16),
            uiSwitch.centerYAnchor.constraint(equalTo: titleView.centerYAnchor),
            uiSwitch.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -29),
            
            descriptionView.topAnchor.constraint(equalTo: uiSwitch.bottomAnchor, constant: 8),
            descriptionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 27),
            descriptionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            descriptionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
        
    }

    
    @objc private func switchValueChanged() {
        valueChanged?(uiSwitch.isOn)
    }
}


private extension String {
    var containsHtml: Bool {
        let range = NSRange(location: 0, length: self.utf16.count)
        let regex = try! NSRegularExpression(pattern: #"</?\w+((\s+\w+(\s*=\s*(?:".*?"|'.*?'|[^'">\s]+))?)+\s*|\s*)/?>"#)
        return !regex.matches(in: self, range: range).isEmpty
    }
    
    var attributedHtmlString: NSAttributedString? {
        let page = """
<html>
<head>
<style>
\(baseCSS)
</style>
<head>
<body>
\(self)
</body>
</html>
"""
        let data = Data(page.utf8)
        return try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil)
        
    }
    
    var baseCSS: String {
"""
html, body, div, span, applet, object, iframe,
h1, h2, h3, h4, h5, h6, p, blockquote, pre,
a, abbr, acronym, address, big, cite, code,
del, dfn, em, img, ins, kbd, q, s, samp,
small, strike, strong, sub, sup, tt, var,
b, u, i, center,
dl, dt, dd, ol, ul, li,
fieldset, form, label, legend,
table, caption, tbody, tfoot, thead, tr, th, td,
article, aside, canvas, details, embed,
figure, figcaption, footer, header, hgroup,
menu, nav, output, ruby, section, summary,
time, mark, audio, video {
    margin: 0;
    padding: 0;
    border: 0;
    font-size: 100%;
    font: inherit;
    vertical-align: baseline;
}
/* HTML5 display-role reset for older browsers */
article, aside, details, figcaption, figure,
footer, header, hgroup, menu, nav, section {
    display: block;
}
body {
    line-height: 1;
    font: -apple-system-body; font-family: -apple-system;

}
ol, ul {
    list-style: none;
}
blockquote, q {
    quotes: none;
}
blockquote:before, blockquote:after,
q:before, q:after {
    content: '';
    content: none;
}
table {
    border-collapse: collapse;
    border-spacing: 0;
}

h1 {font: -apple-system-headine; font-family: -apple-system;}
p {font: -apple-system-body; font-family: -apple-system;}
b {font: -apple-system-body; font-family: -apple-system; font-weight: bold;}
i {font: -apple-system-body; font-family: -apple-system; font-style: italic;}

"""
    }
}
