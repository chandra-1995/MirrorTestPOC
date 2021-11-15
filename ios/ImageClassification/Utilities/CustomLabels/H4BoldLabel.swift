//
//  H4BoldLabel.swift
//  OneAssist-Swift
//
//  Created by Chandra Bhushan on 04/08/20.
//  Copyright © 2020 OneAssist. All rights reserved.
//

import UIKit

class H4BoldLabel: UILabel {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialiseView()
    }
    
    override var isEnabled: Bool {
        didSet {
            if isEnabled {
                textColor = UIColor.charcoalGrey
            }
            else {
                textColor = UIColor.disabledAndLines
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialiseView()
    }
    
    private func initialiseView() {
        font = DLSFont.h4.bold
        textColor = UIColor.charcoalGrey
    }
}
