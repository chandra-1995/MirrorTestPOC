//
//  OABadgeLabel.swift
//  ViewTemplate
//
//  Created by Pankaj Verma on 09/05/19.
//  Copyright © 2019 Pankaj Verma. All rights reserved.
//

import UIKit

enum OALabelTagType {
    enum Badge: Int {
        case inProgress = 101
        case success = 102
        case error = 103
        case onHold = 104
        case new = 105
        case freeTril = 106
    }
}
class OABadgeLabel: UILabel {
    
    @IBInspectable var topInset: CGFloat = 4.0
    @IBInspectable var bottomInset: CGFloat = 4.0
    @IBInspectable var leftInset: CGFloat = 8.0
    @IBInspectable var rightInset: CGFloat = 8.0
    
    override var text: String? {
        didSet {
            if let newText = text?.lowercased() {
                switch newText {
                case "cancelled", "rejected":
                    self.tag = OALabelTagType.Badge.error.rawValue
                case "on-hold":
                    self.tag = OALabelTagType.Badge.onHold.rawValue
                default:
                    self.tag = OALabelTagType.Badge.onHold.rawValue
                }
            }
        }
    }
    
    override func drawText(in rect: CGRect) {
        //Swift 4+
        //        let animationRect = rect.inset(by: UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset))
        //        super.drawText(in: animationRect)
        
        //Swift 3
        let insets = UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset)
        super.drawText(in: rect.inset(by: insets))
        
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialiseView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialiseView()
    }
    
    override var tag: Int {
        didSet {
            initialiseView()
        }
    }
    
    private func initialiseView() {
        commonConfig()
        specificConfig()
        sizeToFit()
        
    }
    
    private func commonConfig(){
        layer.cornerRadius = 2
        textAlignment = .center
        layer.borderWidth = 1.0
        font = DLSFont.tags.bold
    }
    
    func specificConfig(){
        switch tag {
        case OALabelTagType.Badge.inProgress.rawValue:
            textColor = UIColor.buttonBlue
            layer.borderColor = UIColor.buttonBlue.cgColor
        case OALabelTagType.Badge.onHold.rawValue:
            textColor = UIColor.saffronYellow
            layer.borderColor = UIColor.saffronYellow.cgColor
        case OALabelTagType.Badge.success.rawValue:
            textColor = UIColor.seaGreen
            layer.borderColor = UIColor.seaGreen.cgColor
        case OALabelTagType.Badge.error.rawValue:
            textColor = UIColor.errorMessage
            layer.borderColor = UIColor.errorMessage.cgColor
        case OALabelTagType.Badge.new.rawValue:
            backgroundColor = UIColor.saffronYellow
            layer.borderColor = UIColor.clear.cgColor
            textColor = .white
            clipsToBounds = true
        case OALabelTagType.Badge.freeTril.rawValue:
            backgroundColor = UIColor.saffronYellow
            layer.borderColor = UIColor.clear.cgColor
            textColor = .white
            clipsToBounds = true
        default:
            break
        }
    }
    
    override var intrinsicContentSize: CGSize {
        get {
            var contentSize = super.intrinsicContentSize
            contentSize.height += topInset + bottomInset
            contentSize.width += leftInset + rightInset
            return contentSize
        }
    }
}



