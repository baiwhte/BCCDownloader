//
//  ViewController.m
//  CandyDownloader Example
//
//  Created by Candy on 2017/12/7.
//  Copyright © 2017年 Candy. All rights reserved.
//

#import "BCCViewController.h"

#import "BCCDownloader.h"

@interface BCCViewController ()

@property (nonatomic, copy) NSArray *downloadArr;

@end

@implementation BCCViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.downloadArr = @[
                         
                         ];
    NSLog(@"%@", self.tableView);
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
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

    NSString *URLString = self.downloadArr[indexPath.row];
    cell.textLabel.text = URLString;

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
    }
}
@end
