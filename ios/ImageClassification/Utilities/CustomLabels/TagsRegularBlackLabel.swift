//
//  TagsRegularBlackLabel.swift
//  OneAssist-Swift
//
//  Created by Pankaj Verma on 22/04/19.
//  Copyright © 2019 OneAssist. All rights reserved.
//

import UIKit

class TagsRegularBlackLabel: UILabel {

    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initialiseView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialiseView()
    }
    
    private func initialiseView() {
        font = DLSFont.tags.regular
    }
}
