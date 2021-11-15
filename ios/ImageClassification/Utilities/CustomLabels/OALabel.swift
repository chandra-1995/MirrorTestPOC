//
//  OALabel.swift
//  OneAssist-Swift
//
//  Created by Pankaj Verma on 20/05/19.
//  Copyright © 2019 OneAssist. All rights reserved.
//

import UIKit

class OALabel: UILabel {

    override init(frame: CGRect) {
        super.init(frame: frame)
        initialiseView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialiseView()
    }
    
    override var isEnabled: Bool {
        didSet {
            if isEnabled {
                textColor = UIColor.charcoalGrey
            }
            else {
                textColor = UIColor.bodyTextGray
            }
        }
    }
    private func initialiseView() {
        textColor = UIColor.charcoalGrey
    }
}
