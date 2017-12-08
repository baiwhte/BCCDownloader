//
//  BCCModel.m
//  CandyDownloader Example
//
//  Created by Candy on 2017/12/7.
//  Copyright © 2017年 Candy. All rights reserved.
//

#import "BCCModel.h"

@interface BCCModel()

@property NSString *uniqueId;
@property NSDate   *createdAt;

@end

@implementation BCCModel

- (instancetype)init 
{
    self = [super init];
    if (self)
    {
        self.uniqueId  = [[NSUUID UUID] UUIDString];
        self.createdAt = [NSDate date];
        self.updatedAt = [NSDate date];
    }
    return self;
}

+ (NSString *)primaryKey {
    return @"URLString";
}

/**
- (id)copyWithZone:(nullable NSZone *)zone
{
    return [[[self class] allocWithZone:zone] init];
}
*/
@end
