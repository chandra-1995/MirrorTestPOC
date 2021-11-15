//
//  OATipLabel.swift
//  OneAssist-Swift
//
//  Created by Anand Kumar on 30/05/19.
//  Copyright © 2019 OneAssist. All rights reserved.
//

import UIKit

class OATipLabel: UILabel {
    
    @IBInspectable var topInset: CGFloat = 8.0
    @IBInspectable var bottomInset: CGFloat = 8.0
    @IBInspectable var leftInset: CGFloat = 8.0
    @IBInspectable var rightInset: CGFloat = 8.0
    
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
    
    private func initialiseView() {
        font = DLSFont.tags.regular//UIFont.setLatoRegular(with: .tags)
        textColor = UIColor.charcoalGrey
        backgroundColor = UIColor.backgroundInProgress
        layer.cornerRadius = 4
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
