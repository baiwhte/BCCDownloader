//
//  BCCPersistence.h
//  CandyDownloader Example
//
//  Created by Candy on 2017/12/7.
//  Copyright © 2017年 Candy. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BCCModel.h"

@interface BCCPersistance : NSObject

- (void)createOrUpdateModel:(BCCModel *(^)(void))transaction;

- (void)deleteModel:(BCCModel *)model;

- (void)deleteModels:(id<NSFastEnumeration>)models;

- (RLMResults<BCCModel *> *)objectsWithPredicate:(NSPredicate *)predicate;
- (RLMResults<BCCModel *> *)objectsWithClass:(Class)cls 
                                  predicate:(NSPredicate *)predicate;

- (RLMResults<BCCModel *> *)objectsWhere:(NSString *)predicateFormat, ... ;
- (RLMResults<BCCModel *> *)objectsWithClass:(Class)cls 
                                       where:(NSString *)predicateFormat
                                        args:(va_list)args;


- (__kindof BCCModel *)objectForPrimaryKey:(NSString *)key;

@end
