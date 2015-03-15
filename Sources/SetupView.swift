import CloudKit.CKRecordID
import PromiseKit
import TSMarkdownParser
import UIKit


private enum State {
    case Loading
    case Registering
    case Pairing
}


class SetupView: UIView {
    private var contentView: UIView?

    var promise: Promise<(CKRecordID, String)>!

    private var state: State = .Loading {
        willSet {
            contentView?.removeFromSuperview()
        }
        didSet {
            switch state {
            case .Loading:
                let spinner = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
                spinner.startAnimating()
                contentView = spinner
            case .Registering:
                contentView = RegistrationView()
            case .Pairing:
                contentView = PairingView()
            }
            addSubview(contentView!)
        }
    }

    required init(coder: NSCoder = NSCoder.empty()) {
        super.init(coder: coder)

        swiftSucks()

        promise = CKContainer.defaultContainer().fetchUserRecordID().then { _ -> Promise<String> in
            self.state = .Registering
            return (self.contentView as! RegistrationView).promise
        }.then { username -> Promise<Void> in
            self.state = .Pairing
            return pair(username)
        }.then { () -> Promise<(CKRecordID, String)> in
            if let lover = NSUserDefaults.standardUserDefaults().lover {
                return Promise(lover)
            } else {
                return Promise(NSError(luv: "Unknown Pairing Error"))
            }
        }
    }

    private func swiftSucks() {
        // bypass swift not running willSet/didSet from the initializer
        state = .Loading
    }

    override func layoutSubviews() {
        contentView?.bounds = bounds
        contentView?.center = bounds.center
    }
}


private class RegistrationView: UIView {
    private let label = UILabel()
    private let textField = UITextField()

    required init(coder: NSCoder = NSCoder.empty()) {
        super.init(coder: coder)
        label.attributedText = welcomeText()
        label.textColor = UIColor.whiteColor()
        label.textAlignment = .Center
        label.numberOfLines = 0

        textField.textColor = UIColor.whiteColor()
        textField.autocorrectionType = .No
        textField.font = UIFont(name: "HelveticaNeue-Medium", size: 40)
        textField.textAlignment = .Center
        textField.returnKeyType  = .Go
        textField.text = NSUserDefaults.standardUserDefaults().objectForKey("Username") as? String ?? ""
        textField.addTarget(self, action: "onchange", forControlEvents: .EditingChanged)
        textField.addTarget(self, action: "go", forControlEvents: .EditingDidEndOnExit)

        addSubview(textField)
        addSubview(label)

        textField.becomeFirstResponder()

        switch UIDevice.model() {
        case .iPhone4:
            transform = CGAffineTransformTranslate(CGAffineTransformMakeScale(0.9, 0.9), 0, -42)
        default:
            break
        }
    }

    @objc func go() {
        if !textField.text.isEmpty {
            fulfill(textField.text)
        }
    }

    @objc func onchange() {
        NSUserDefaults.standardUserDefaults().setObject(textField.text, forKey: "Username")
    }

    override func layoutSubviews() {
        label.frame = CGRectInset(bounds, 20, 20)
        label.frame.origin.y += 40
        label.sizeToFit()
        textField.sizeToFit()
        textField.frame.size.width = label.bounds.width - 40
        textField.center.x = bounds.size.width / 2
        textField.frame.origin.y = CGRectGetMaxY(label.frame) + 20
    }

    let (promise, fulfill, reject) = Promise<String>.defer()
}


class PairingView: UIView {
    private let phone1 = _PhoneView()
    private let phone2 = _PhoneView()
    private let label = UILabel()
    private let spinner = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
    private let button = BorderedButton(text: "Share App Store Link", size: 16)

    let (promise, fulfill, reject) = Promise<(CKRecordID, String)>.defer()

    required init(coder: NSCoder = NSCoder.empty()) {
        super.init(frame: UIScreen.mainScreen().bounds)
        label.attributedText = pairingText()
        label.textColor = UIColor.whiteColor()
        label.numberOfLines = 0
        label.textAlignment = .Center
        label.frame = CGRectInset(bounds, 20, 20)
        label.sizeToFit()
        spinner.color = UIColor.hotPink()
        spinner.startAnimating()
        button.addTarget(self, action: "share", forControlEvents: .TouchUpInside)

        addSubview(label)
        addSubview(phone1)
        addSubview(phone2)
        addSubview(spinner)
        addSubview(button)

        NSOperationQueue.mainQueue().addOperationWithBlock(go)

        if UIDevice.model() == .iPhone4 {
            transform = CGAffineTransformMakeTranslation(0, -10)
        }


    }

    func go() {
        UIView.animateWithDuration(0.8) {
            let w = self.bounds.size.width / 2
            self.phone1.transform = CGAffineTransformMakeTranslation(250, 0)
            self.phone2.transform = CGAffineTransformMakeTranslation(-250, 0)
            self.label.transform = CGAffineTransformMakeTranslation(0, 200)
        }
    }

    override func layoutSubviews() {
        label.center = CGPoint(x: bounds.size.width / 2, y: -112)
        phone1.center = CGPoint(x: -160, y: 275)
        phone2.center = CGPoint(x: bounds.size.width + 160, y: 275)

        button.center.x = label.center.x
        button.center.y = bounds.size.height - 20 - button.bounds.size.height / 2

        spinner.center.x = label.center.x
        spinner.center.y = button.frame.origin.y - 60
    }

    @objc func share() {
        let vc = UIActivityViewController(messagePrefix: "Here’s the app:")
        parentViewController?.presentViewController(vc, animated: true, completion: nil)
    }
}


private class _PhoneView: UIView {
    let phone = PhoneView()

    required init(coder: NSCoder = NSCoder.empty()) {
        super.init(coder: coder)
        addSubview(phone)
    }

    override func layoutSubviews() {
        phone.center = CGPointZero
    }
}



private func welcomeText() -> NSAttributedString {
    let lines = [
        "# Welcome",
        "Use Kissogram to send that **special someone** a message of love when you’re thinking of them.",
        "What’s your name?"]
    let text = "\n\n".join(lines)

    let parser = TSMarkdownParser.standardParser()
    parser.h1Font = UIFont(name: "HelveticaNeue-UltraLight", size: 40)
    parser.strongFont = UIFont(name: "HelveticaNeue-Light", size: 16)
    parser.paragraphFont = UIFont(name: "HelveticaNeue-Thin", size: 16)

    return parser.attributedStringFromMarkdown(text)
}


private func pairingText() -> NSAttributedString {
    let parser = TSMarkdownParser.standardParser()
    parser.h1Font = UIFont(name: "HelveticaNeue-UltraLight", size: 45)
    parser.paragraphFont = UIFont(name: "HelveticaNeue-Thin", size: 14)

    let text = "# Pairing\nHold phones close"

    return parser.attributedStringFromMarkdown(text)
}
