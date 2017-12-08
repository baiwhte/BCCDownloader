//
//  BCCTableViewCell.h
//  CandyDownloader Example
//
//  Created by Candy on 2017/12/8.
//  Copyright © 2017年 Candy. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BCCTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *urlLabel;

@property (weak, nonatomic) IBOutlet UILabel *progressLabel;

@end
