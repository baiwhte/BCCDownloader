//
//  BCCPersistence.m
//  CandyDownloader Example
//
//  Created by Candy on 2017/12/7.
//  Copyright © 2017年 Candy. All rights reserved.
//

#import "BCCPersistance.h"

@interface BCCPersistance()

@property (nonatomic) dispatch_queue_t realmQueue;

@end

@implementation BCCPersistance

- (void)dealloc
{
    
}

- (instancetype)init
{
    self = [super init];
    if (self) 
    {
        [self initialize];
    }
    return self;
}

- (void)initialize
{
    self.realmQueue = dispatch_queue_create("com.baiwhte.downloader.realm", DISPATCH_QUEUE_CONCURRENT);
    
    RLMRealmConfiguration *configuration = [RLMRealmConfiguration defaultConfiguration];
    configuration.shouldCompactOnLaunch = ^BOOL(NSUInteger totalBytes, NSUInteger bytesUsed) {
        // totalBytes 指的是硬盘上文件的大小（以字节为单位）(数据 + 可用空间)
        // usedBytes 指的是文件中数据所使用的字节数
        
        // 如果文件的大小超过 100 MB，并且已用空间低于 50%
         NSUInteger oneHundredMB = 100 * 1024 * 1024;
         return (totalBytes > oneHundredMB) && (bytesUsed / totalBytes) < 0.5;
//        return YES;
    };
    configuration.schemaVersion  = [self currentVersion];
    configuration.migrationBlock = ^(RLMMigration *migration, uint64_t oldSchemaVersion) {
        [self performMigrate:migration oldSchemaVersion:oldSchemaVersion];
    };
    
    [RLMRealmConfiguration setDefaultConfiguration:configuration];
    
//    NSError *error = nil;
//    // 如果配置条件满足，那么 Realm 就会在首次打开时被压缩
//    RLMRealm *realm = [RLMRealm realmWithConfiguration:configuration error:&error];
//    if (error) {
//        // 处理打开 Realm 或者压缩时产生的错误
//    }
    
}

#pragma mark - realm migration

- (int64_t)currentVersion
{
    return 1;
}

- (void)performMigrate:(RLMMigration *)migration 
      oldSchemaVersion:(uint64_t)oldSchemaVersion
{
    if (oldSchemaVersion < 1) 
    {
        [migration enumerateObjects:@"BCCModel" 
                              block:^(RLMObject * _Nullable oldObject, 
                                      RLMObject * _Nullable newObject) {
                                  
                              }];
    }
}

#pragma mark - operation database

- (void)createOrUpdateModel:(BCCModel * (^)(void))transaction
{
    dispatch_sync(self.realmQueue, ^{
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm transactionWithBlock:^{
            BCCModel *model = transaction();
            model.updatedAt = [NSDate date];
            [[model class] createOrUpdateInRealm:realm withValue:model];
        }];
    });
}

- (void)deleteModel:(BCCModel *)model
{
    dispatch_sync(self.realmQueue, ^{
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm transactionWithBlock:^{
            [realm deleteObject:model];
        }];
    });
}

- (void)deleteModels:(id<NSFastEnumeration>)models
{
    //???: how copy models
    dispatch_async(self.realmQueue, ^{
        RLMRealm *realm = [RLMRealm defaultRealm];
        [realm transactionWithBlock:^{
            [realm deleteObjects:models];
        }];
    });
}

- (RLMResults<BCCModel *> *)objectsWhere:(NSString *)predicateFormat, ... 
{
    va_list args;
    va_start(args, predicateFormat);
    RLMResults *results = [self objectsWithClass:[BCCModel class] where:predicateFormat args:args];
    va_end(args);
    return results;
}

- (RLMResults<BCCModel *> *)objectsWithPredicate:(NSPredicate *)predicate
{
    return [self objectsWithClass:[BCCModel class] predicate:predicate];
}

- (RLMResults<BCCModel *> *)objectsWithClass:(Class)cls 
                                   predicate:(NSPredicate *)predicate
{
//    NSAssert([cls isKindOfClass:[BCCModel class]], @"cls must be BCCModel subclass");
    __block RLMResults *result = nil;
    dispatch_sync(self.realmQueue, ^{
        result = [cls objectsWithPredicate:predicate];
    });
    return result;
}

- (RLMResults<BCCModel *> *)objectsWithClass:(Class)cls 
                                       where:(NSString *)predicateFormat
                                        args:(va_list)args
{
    return [self objectsWithClass:cls predicate:[NSPredicate predicateWithFormat:predicateFormat arguments:args]];
}

- (__kindof BCCModel *)objectForPrimaryKey:(NSString *)key
{
    __block BCCModel *result = nil;
    dispatch_sync(self.realmQueue, ^{
        result = [BCCModel objectForPrimaryKey:key];
    });
    return result;
}

- (__kindof BCCModel *)objectForPrimaryKey:(NSString *)key
                                   inClass:(Class)cls
{
    __kindof __block BCCModel *result = nil;
    dispatch_sync(self.realmQueue, ^{
        result = [cls objectForPrimaryKey:key];
    });
    return result;
}

@end
