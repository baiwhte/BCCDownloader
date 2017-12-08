//
//  BCCDownloader.m
//  CandyDownloader Example
//
//  Created by Candy on 2017/12/7.
//  Copyright © 2017年 Candy. All rights reserved.
//

#import "BCCDownloader.h"
#import "BCCPersistance.h"

static NSString *kBCCBackgroundSessionIdentifier = @"com.baiwhte.backgroundSession";

@interface BCCDownloader() <NSURLSessionDelegate, NSURLSessionDownloadDelegate>

@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nonatomic, strong) BCCBackgroundSessionCompletionHandler backgroundSessionCompletionHandler;
@property (nonatomic, strong) NSURLSessionConfiguration *sessionConfiguration;
@property (nonatomic, strong) NSURLSession *session;

@property (nonatomic, strong) NSURL *finishFileDirectoryURL;
@property (nonatomic, strong) NSURL *resumeDataDirectoryURL;

@property (nonatomic, strong) BCCPersistance *persistance;

@end

@implementation BCCDownloader

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init
{
    self = [super init];
    if (!self) return nil;
    
    [self initlialize];
    
    return self;
}

+ (instancetype)shareInstance
{
    static BCCDownloader *downloader;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        downloader = [[self alloc] init];
    });
    return downloader;
}

- (void)initlialize
{
    //NSURLSessionConfiguration
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:kBCCBackgroundSessionIdentifier];
    configuration.discretionary = NO;
    self.sessionConfiguration = configuration;
    
    self.session = [NSURLSession sessionWithConfiguration:self.sessionConfiguration
                                                 delegate:self
                                            delegateQueue:[NSOperationQueue mainQueue]];
    
    self.maxConcurrentDownloadCount = 1;
    //各种后台
    self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillTerminate)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationBackgroundRefreshStatus:)
                                                 name:UIApplicationBackgroundRefreshStatusDidChangeNotification
                                               object:nil];
    self.persistance = [[BCCPersistance alloc] init];
    NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject];
    self.finishFileDirectoryURL = [[NSURL URLWithString:cachePath] URLByAppendingPathComponent:@"files"];
    self.resumeDataDirectoryURL = [[self.finishFileDirectoryURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"resumeDatas"];
    [self buildDirectoryWithURL:self.finishFileDirectoryURL];
    [self buildDirectoryWithURL:self.resumeDataDirectoryURL];
}

- (void)addDownloadTaskWithURLString:(NSString *)URLString filename:(NSString *)filename
{
    NSAssert(URLString && filename, @"Both URLString and filename must not be nil");
    
    NSInteger count = [[self.persistance objectsWhere:@"URLString=%@", URLString] count];
    if (count > 0) {
        //任务已经存在
        NSLog(@"任务已经存在:%@", filename);
        return;
    }
    
    BCCModel *model = [[BCCModel alloc] init];
    model.URLString = URLString;
    model.filename  = filename;
    model.state     = BCCDownloadStateWaiting;
    [self.persistance createOrUpdateModel:^BCCModel *{
        return model;
    }];
    [self downloadNext];
}

- (void)downloadNext
{
    //use FIFO
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"state = %d", BCCDownloadStateWaiting];
    BCCModel *model = [[[self.persistance objectsWithPredicate:predicate]
                        sortedResultsUsingKeyPath:@"createdAt" ascending:YES] 
                       firstObject];
    [self resumeTaskWithModel:model];
}

- (void)resumeTaskWithModel:(BCCModel *)model
{
    if (model       == nil ||
        model.state == BCCDownloadStateRunning ||
        model.state == BCCDownloadStateSuccess) 
    {
        return;
    }
    NSInteger runningCount = [[self.persistance objectsWhere:@"state = %d", BCCDownloadStateRunning] count];
    if (runningCount < self.maxConcurrentDownloadCount) 
    {
        //获取断点数据
        NSURL *saveFile = [self.resumeDataDirectoryURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.rd", model.filename]];
        NSData *resumeData = [NSData dataWithContentsOfFile:saveFile.path];
        
        void(^block)(NSURLSessionDownloadTask *sessionDownloadTask) = ^(NSURLSessionDownloadTask *sessionDownloadTask) {
            
            //保存id
            [self.persistance createOrUpdateModel:^BCCModel *{
                model.sessionTaskIdentifier = sessionDownloadTask.taskIdentifier;
                return model;
            }];
            
            [sessionDownloadTask resume];
        };
        NSURLSessionDownloadTask *sessionDownloadTask  = resumeData ? [self.session downloadTaskWithResumeData:resumeData] :
                                                        [self.session downloadTaskWithURL:[NSURL URLWithString:model.URLString]];
        block(sessionDownloadTask);
        //保存状态为下载中
        [self.persistance createOrUpdateModel:^BCCModel *{
            model.state = BCCDownloadStateRunning;
            return model;
        }];
    }
    else if (model.state != BCCDownloadStateWaiting) 
    {
        //保存
        [self.persistance createOrUpdateModel:^BCCModel *{
            //超过并行下载任务数改为等待
            model.state = BCCDownloadStateWaiting;
            return model;
        }];
    }
}

- (void)suspendTaskWithModel:(BCCModel *)model
{
    if (model       == nil ||
        model.state == BCCDownloadStateRunning ||
        model.state == BCCDownloadStateSuccess) 
    {
        return;
    }
    
    //取消并保存断点数据
    [self.session getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> *dataTasks, NSArray<NSURLSessionUploadTask *> *uploadTasks, NSArray<NSURLSessionDownloadTask *> *downloadTasks) {
        for (NSURLSessionDownloadTask *downloadTask in downloadTasks) {
            if (downloadTask.taskIdentifier == model.sessionTaskIdentifier) {
                
                [downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
                    //保存断点数据
                    if (resumeData != nil) {
                        NSURL *saveFile = [self.resumeDataDirectoryURL URLByAppendingPathComponent:model.filename];
                        [resumeData writeToFile:saveFile.path atomically:YES];
                    }
                }];

                //保存
                [self.persistance createOrUpdateModel:^BCCModel *{
                    //状态为暂停
                    model.downloadFilebytes = downloadTask.countOfBytesReceived;
                    return model;
                }];
 
                break;
            }
        }
    }];
    
    //保存
    [self.persistance createOrUpdateModel:^BCCModel *{
        //状态为暂停
        model.state = BCCDownloadStateSuspended;
        return model;
    }];
    
    //继续下载
    [self downloadNext];
}

- (void)deleteTaskByPrimaryKey:(NSString *)key
{
    [self deleteTaskWithModel:[self.persistance objectForPrimaryKey:key]];
}

- (void)deleteTaskWithModel:(BCCModel *)model
{
    [self deleteTaskWithModel:model next:YES];
}

- (void)deleteTaskWithModel:(BCCModel *)model next:(BOOL)next
{
    if (model == nil) return;
    
    //取消任务
    if (model.sessionTaskIdentifier > 0) {
        NSUInteger sessionTaskIdentifier = model.sessionTaskIdentifier;
        [self.session getTasksWithCompletionHandler:^(NSArray<NSURLSessionDataTask *> *dataTasks, NSArray<NSURLSessionUploadTask *> *uploadTasks, NSArray<NSURLSessionDownloadTask *> *downloadTasks) {
            for (NSURLSessionDownloadTask *downloadTask in downloadTasks) {
                if (downloadTask.taskIdentifier == sessionTaskIdentifier) {
                    [downloadTask cancel];
                    break;
                }
            }
        }];
    }
    
    NSURL *videoFileURL = [self fileURLWithModel:model];
    [[NSFileManager defaultManager] removeItemAtPath:videoFileURL.path error:nil];
    
    [self deleteResumeDataWithModel:model];
    [self.persistance deleteModel:model];
    if (next)
    {
        [self downloadNext];
    }
}

- (void)deleteTaskWithModels:(RLMResults *)results
{
    for (BCCModel *model in results) {
        [self deleteTaskWithModel:model next:NO];
    }
    [self downloadNext];
}

- (void)deleteResumeDataWithModel:(BCCModel *)model {
    NSURL *resumeFileURL = [self.resumeDataDirectoryURL URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.rd", model.filename]];
    [[NSFileManager defaultManager] removeItemAtPath:resumeFileURL.path error:nil];
}

- (NSURL *)fileURLWithModel:(BCCModel *)model {
    NSURL *videoFileURL = [self.finishFileDirectoryURL URLByAppendingPathComponent:model.filename];
    return videoFileURL;
}

- (void)buildDirectoryWithURL:(NSURL *)URL {
    BOOL isDirectory = YES;
    if (![[NSFileManager defaultManager] fileExistsAtPath:URL.path isDirectory:&isDirectory]) {
        NSError *error;
        [[NSFileManager defaultManager] createDirectoryAtPath:URL.path
                                  withIntermediateDirectories:YES
                                                   attributes:@{ NSFileProtectionKey: NSFileProtectionNone }
                                                        error:&error];
    }
}

#pragma mark - UIApplicationDelegate selectors

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    UIApplication *app = notification.object;
    if (!app) { return; }
     NSUInteger count = 1;
    if (app.backgroundRefreshStatus != UIBackgroundRefreshStatusAvailable || count == 0) 
    {
        self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalNever];
        return;
    }

    //如果有任务在继续，申请后台时间
    self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^(void) {
        [self applicationWillEnterForeground];
    }];
    //开启后台刷新
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
}

- (void)applicationWillEnterForeground 
{
    //取消申请后台时间
    if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) 
    {
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
        self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    }
}

- (void)applicationWillTerminate 
{
    //结束app进程时暂停任务
    RLMResults *results = [self.persistance objectsWhere:@"state = %d OR state = %d", BCCDownloadStateWaiting, BCCDownloadStateRunning];
    for (BCCModel *model in results)
    {
        [self suspendTaskWithModel:model];
    }
}

- (void)applicationBackgroundRefreshStatus:(NSNotification *)notification
{
    [self applicationDidEnterBackground:notification];
}

- (void)setBackgroundSessionCompletionHandler:(BCCBackgroundSessionCompletionHandler)completionHandler 
                               withIdentifier:(NSString *)identifier 
{
    if ([identifier isEqualToString:self.sessionConfiguration.identifier])
    {
        self.backgroundSessionCompletionHandler = completionHandler;
    }
}

- (void)performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    NSInteger runningAndWaitingCount = [[self.persistance objectsWhere:@"state = %d OR state = %d", 
                                         BCCDownloadStateWaiting, BCCDownloadStateRunning] count];
    if (runningAndWaitingCount > 0) 
    {
        //如果有任务在继续
        completionHandler(UIBackgroundFetchResultNewData);
    } 
    else
    {
        completionHandler(UIBackgroundFetchResultNoData);
    }
}

#pragma mark - NSURLSessionDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)sessionTask
didCompleteWithError:(nullable NSError *)error {
    BCCModel *model = [[BCCModel objectsWhere:@"sessionTaskIdentifier = %d", sessionTask.taskIdentifier] firstObject];
    if (model != nil) {
        //失败
        if (error != nil && error.code != NSURLErrorCancelled) {
            //删除断点数据
            [self deleteResumeDataWithModel:model];
            //保存
            [self.persistance createOrUpdateModel:^BCCModel *{
                model.state = BCCDownloadStateFailure;
                model.sessionTaskIdentifier = 0;
                return model;
            }];
        }
        
       
    }
    
    [self downloadNext];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
    BCCModel *model = [[BCCModel objectsWhere:@"sessionTaskIdentifier = %d", downloadTask.taskIdentifier] firstObject];
    if (model != nil) {
        //保存文件
        NSError *error;
        NSURL *videoFileURL = [self fileURLWithModel:model];
        if ([[NSFileManager defaultManager] fileExistsAtPath:videoFileURL.path]) {
            [[NSFileManager defaultManager] removeItemAtPath:videoFileURL.path error:nil];
        }
        [[NSFileManager defaultManager] moveItemAtPath:location.path toPath:videoFileURL.path error:&error];
        
        BCCDownloadState state;
        if (error != nil) {
            //失败
            state = BCCDownloadStateFailure;
        } else {
            //成功
            state = BCCDownloadStateSuccess;
            
            //删除断点数据
            [self deleteResumeDataWithModel:model];
            
        }
        
        //保存
        [self.persistance createOrUpdateModel:^BCCModel *{
            model.state = state;
            model.sessionTaskIdentifier = 0;
            if (state == BCCDownloadStateSuccess) {
                model.downloadCompletedAt = [NSDate date];
            }
            return model;
        }];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
        didWriteData:(int64_t)bytesWritten
        totalBytesWritten:(int64_t)totalBytesWritten
        totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite 
{
    //通知
    BCCModel *model = [[BCCModel objectsWhere:@"sessionTaskIdentifier = %d", downloadTask.taskIdentifier] firstObject];
    if (model != nil) {
        if (model.filebytes <= 0) {
            //保存文件大小
            [self.persistance createOrUpdateModel:^BCCModel *{
                model.filebytes = totalBytesExpectedToWrite;
                return model;
            }];
        }
    }
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    NSLog(@"URLSessionDidFinishEventsForBackgroundURLSession -------------------");
    if (self.backgroundSessionCompletionHandler) {
        BCCBackgroundSessionCompletionHandler handler = self.backgroundSessionCompletionHandler;
        self.backgroundSessionCompletionHandler = nil;
        handler();
    }
}

#pragma mark - setter

- (void)setMaxConcurrentDownloadCount:(NSInteger)maxConcurrentDownloadCount
{
    if (maxConcurrentDownloadCount > 3) 
    {
        maxConcurrentDownloadCount = 3;
    }
    
    if (maxConcurrentDownloadCount < 1) 
    {
        maxConcurrentDownloadCount = 1;
    }
    
    if (_maxConcurrentDownloadCount != maxConcurrentDownloadCount)
    {
        _maxConcurrentDownloadCount = maxConcurrentDownloadCount;
    }
}
@end
