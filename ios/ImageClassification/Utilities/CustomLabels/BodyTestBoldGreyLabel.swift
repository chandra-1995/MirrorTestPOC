//
//  BodyTestBoldGreyLabel.swift
//  OneAssist-Swift
//
//  Created by Ankur Batham on 04/09/19.
//  Copyright © 2019 OneAssist. All rights reserved.
//

import UIKit

class BodyTestBoldGreyLabel: UILabel {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialiseView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialiseView()
    }
    
    private func initialiseView() {
        font = DLSFont.bodyText.bold
        textColor = UIColor.bodyTextGray
    }
}
