//
//  DLQDownloadQueue.h
//  APP2
//
//  Created by RJ on 17/3/20.
//  Copyright © 2017年 RJ. All rights reserved.
//

#import <Foundation/Foundation.h>
@class DLQDownloadQueue;
@protocol DownloadQueueDelegate <NSObject>

/**
 下载进度回调
 @param taskIndex 任务序号
 @param progress 进度
 */
- (void)downloadTaskIndex:(NSInteger)taskIndex progress:(double)progress queue:(DLQDownloadQueue *)queue;

/**
 下载完成回调
 
 @param taskIndex 任务序号
 @param savePath 文件保存路径
 */
- (void)downloadTaskIndex:(NSInteger)taskIndex didFinishWithSavePath:(NSString *)savePath;

@end
@interface DLQDownloadQueue : NSObject

@property (strong, nonatomic) id<DownloadQueueDelegate>delegate;

- (void)addDownloadTaskURL:(NSString *)url;

- (void)startDownload;

- (void)startDownloadTheBigFile;

@end
