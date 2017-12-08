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

@interface BCCDownloader : NSObject

/*! 允许同时下载数,最大值为3 */
@property (nonatomic, assign) NSInteger maxConcurrentDownloadCount;

+ (instancetype)shareInstance;

- (void)addDownloadTaskWithURLString:(NSString *)URLString filename:(NSString *)filename;

// delete single task. if delete multi tasks
// use 'deleteTaskWithModels:' method
- (void)deleteTaskWithModel:(BCCModel *)model;
// delete multi tasks
- (void)deleteTaskWithModels:(RLMResults *)results;

- (void)deleteTaskByPrimaryKey:(NSString *)key;

@end
