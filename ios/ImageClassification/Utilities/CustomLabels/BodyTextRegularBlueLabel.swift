//
//  BodyTextRegularBlueLabel.swift
//  OneAssist-Swift
//
//  Created by Raj on 01/05/19.
//  Copyright © 2019 OneAssist. All rights reserved.
//

import Foundation
import UIKit

class BodyTextRegularBlueLabel: UILabel {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialiseView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialiseView()
    }
    
    private func initialiseView() {
        font = DLSFont.bodyText.regular// UIFont.setLatoRegular(with: .bodyText)
        textColor = UIColor.buttonBlue
    }
}
