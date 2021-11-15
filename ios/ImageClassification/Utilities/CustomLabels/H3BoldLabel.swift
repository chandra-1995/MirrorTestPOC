//
//  H3BoldLabel.swift
//  OneAssist-Swift
//
//  Created by Himanshu Dagar on 20/03/19.
//  Copyright © 2019 OneAssist. All rights reserved.
//

import UIKit

class H3BoldLabel: UILabel {
    
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
        font = DLSFont.h3.bold
        textColor = UIColor.charcoalGrey
    }
}
