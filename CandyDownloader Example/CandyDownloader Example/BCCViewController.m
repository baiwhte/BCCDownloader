//
//  ViewController.m
//  CandyDownloader Example
//
//  Created by Candy on 2017/12/7.
//  Copyright © 2017年 Candy. All rights reserved.
//

#import "BCCViewController.h"
#import "BCCTableViewCell.h"
#import "BCCDownloader.h"

@interface BCCViewController () <BCCDownloaderDelegate>

@property (nonatomic, copy) NSArray *downloadArr;

@end

@implementation BCCViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.downloadArr = @[
                         
                         ];
    NSLog(@"%@", self.tableView);
    
    [BCCDownloader shareInstance].delegate = self;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - UITableViewDelegate, UITableViewDataSource

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.downloadArr count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"cell";
    BCCTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

    NSString *URLString = self.downloadArr[indexPath.row];
    cell.urlLabel.text = URLString;
    cell.progressLabel.text = @"0";
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    NSString *URLString = self.downloadArr[indexPath.row];
    [[BCCDownloader shareInstance] addDownloadTaskWithURLString:URLString 
                                                       filename:[NSString stringWithFormat:@"file%ld.mp4", (long)indexPath.row]];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleDelete;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSString *URLString = self.downloadArr[indexPath.row];
        [[BCCDownloader shareInstance] deleteTaskByPrimaryKey:URLString];
        BCCTableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        if (cell) {
            cell.progressLabel.text = @"0";
        }
    }
}

#pragma mark - BCCDownloaderDelegate

- (void)downloader:(BCCDownloader *)downloader model:(BCCModel *)model didCompletedWithWithError:(NSError *)error
{
    NSInteger index = [self.downloadArr indexOfObject:model.URLString];
    BCCTableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
    if (cell == nil) {
        return;
    }
    cell.progressLabel.text = @"100%";
}

- (void)downloader:(BCCDownloader *)downloader model:(BCCModel *)model
        didWriteData:(int64_t)bytesWritten
        totalBytesWritten:(int64_t)totalBytesWritten
        totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
    NSInteger index = [self.downloadArr indexOfObject:model.URLString];
    BCCTableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
    if (cell == nil) {
        return;
    }
    float percentFloat = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
    NSInteger percentInt = percentFloat * 100;
    cell.progressLabel.text = [NSString stringWithFormat:@"%d%%", (int)percentInt];
}
@end
