//
//  SupportingTextRegularRedLabel.swift
//  OneAssist-Swift
//
//  Created by Anand Kumar on 30/05/19.
//  Copyright © 2019 OneAssist. All rights reserved.
//

import UIKit

class SupportingTextRegularRedLabel: UILabel {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialiseView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialiseView()
    }
    
    private func initialiseView() {
        font = DLSFont.supportingText.regular//UIFont.setLatoRegular(with: .supportingText)
        textColor = UIColor.errorText
    }
}
