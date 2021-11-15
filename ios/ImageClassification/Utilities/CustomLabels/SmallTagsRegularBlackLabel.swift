//
//  SmallTagsRegularBlackLabel.swift
//  OneAssist-Swift
//
//  Created by Anand Kumar on 05/09/2019.
//  Copyright © 2019 OneAssist. All rights reserved.
//

import UIKit

class SmallTagsRegularBlackLabel: UILabel {

    override init(frame: CGRect) {
        super.init(frame: frame)
        initialiseView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialiseView()
    }
    
    private func initialiseView() {
        font = DLSFont.smallTag.regular
    }
}
