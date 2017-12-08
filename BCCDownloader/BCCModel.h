//
//  BCCModel.h
//  CandyDownloader Example
//
//  Created by Candy on 2017/12/7.
//  Copyright © 2017年 Candy. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Realm/Realm.h>

typedef NS_ENUM(NSInteger, BCCDownloadState) 
{
    BCCDownloadStateWaiting = 0,
    BCCDownloadStateRunning = 1,
    BCCDownloadStateSuspended = 2,
    BCCDownloadStateSuccess = 3,
    BCCDownloadStateFailure = 4,
    BCCDownloadStateWillBeDeleted
};

@interface BCCModel : RLMObject <NSCopying>

@property NSString *URLString;
// 
@property NSString *filename;

@property BCCDownloadState state;
@property int64_t filebytes;
@property int64_t downloadFilebytes;
//realm unsupport NSUInteger type
@property NSInteger sessionTaskIdentifier;
@property NSDate   *updatedAt;
@property NSDate  *downloadCompletedAt;

@end
