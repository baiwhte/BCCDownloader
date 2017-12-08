//
//  BCCDownloader.h
//  CandyDownloader Example
//
//  Created by Candy on 2017/12/7.
//  Copyright © 2017年 Candy. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "BCCModel.h"

typedef void (^BCCBackgroundSessionCompletionHandler)(void);

@class BCCDownloader;
@protocol BCCDownloaderDelegate <NSObject>

@optional

- (void)downloader:(BCCDownloader *)downloader model:(BCCModel *)model didCompletedWithWithError:(NSError *)error;

- (void)downloader:(BCCDownloader *)downloader model:(BCCModel *)model
        didWriteData:(int64_t)bytesWritten
        totalBytesWritten:(int64_t)totalBytesWritten
        totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite;

@end

@interface BCCDownloader : NSObject

/*! 允许同时下载数,最大值为3 */
@property (nonatomic, assign) NSInteger maxConcurrentDownloadCount;

@property (nonatomic, weak  ) id<BCCDownloaderDelegate> delegate;

+ (instancetype)shareInstance;

- (void)addDownloadTaskWithURLString:(NSString *)URLString filename:(NSString *)filename;

// delete single task. if delete multi tasks
// use 'deleteTaskWithModels:' method
- (void)deleteTaskWithModel:(BCCModel *)model;
// delete multi tasks
- (void)deleteTaskWithModels:(RLMResults *)results;

- (void)deleteTaskByPrimaryKey:(NSString *)key;
- (BCCModel *)objectForPrimaryKey:(NSString *)key;

@end
