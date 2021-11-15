//
//  TagsRegularGreyLabel.swift
//  OneAssist-Swift
//
//  Created by Pankaj Verma on 03/04/19.
//  Copyright © 2019 OneAssist. All rights reserved.
//

import UIKit

class TagsRegularGreyLabel: UILabel {

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
        textColor = UIColor.bodyTextGray
    }
}
