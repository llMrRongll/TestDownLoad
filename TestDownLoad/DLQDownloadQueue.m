//
//  DLQDownloadQueue.m
//  APP2
//
//  Created by RJ on 17/3/20.
//  Copyright © 2017年 RJ. All rights reserved.
//

#import "DLQDownloadQueue.h"
#import <UIKit/UIKit.h>
#import "DLQMultiDownloadQueue.h"

@interface DLQDownloadQueue()<NSURLSessionDownloadDelegate, DLQMultiDownloadQueueDelegate>

@property (strong, nonatomic) NSMutableArray *urlArray;
@property (strong, nonatomic) NSMutableArray *taskArray;
@property (strong, nonatomic) NSMutableArray *requestArray;
@property (strong, nonatomic) NSOperationQueue *opQueue;
@property (strong, nonatomic) DLQMultiDownloadQueue *multiDownloadQueue;

@end

@implementation DLQDownloadQueue

- (instancetype)init{
    if (self = [super init]) {
        
    }
    return self;
}

- (NSMutableArray *)urlArray{
    if (_urlArray == nil) {
        _urlArray = [NSMutableArray array];
    }
    return _urlArray;
}

- (NSMutableArray *)taskArray{
    if (_taskArray == nil) {
        _taskArray = [NSMutableArray array];
    }
    return _taskArray;
}

- (NSMutableArray *)requestArray{
    if (_requestArray == nil) {
        _requestArray = [NSMutableArray array];
    }
    return _requestArray;
}

- (void)addNotifications{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rjApplicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rjApplicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rjApplicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rjApplicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)addDownloadTaskURL:(NSString *)url{
    if (url.length) {
        NSLog(@"downloadURL:%@", url);
        
        NSURL *URL = [NSURL URLWithString:url];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
        
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue currentQueue]];
        NSURLSessionDownloadTask *task = [session downloadTaskWithRequest:request];
        
        [self.taskArray addObject:task];
        [self.requestArray addObject:request];
        [self.urlArray addObject:url];
    }
}

- (void)startDownload{
    if (!self.taskArray.count) {
        return;
    }
    for (int i = 0; i < self.taskArray.count; i++) {
        if (self.requestArray.count) {
            NSMutableURLRequest *request = [self.requestArray objectAtIndex:i];
            NSURL *url = request.URL;
            NSString *path = [self filePathWithFileName:url.lastPathComponent];
            NSFileManager *manager = [NSFileManager defaultManager];
            if ([manager fileExistsAtPath:path]) {
                NSLog(@"file %@ already exist", url.lastPathComponent);
                NSLog(@"filePath:%@", path);
                continue;
            }
            //start download
            if (path.lastPathComponent && ![[path.lastPathComponent lowercaseString] containsString:@"null"]) {
                NSURLSessionDownloadTask *task = [self.taskArray objectAtIndex:i];
                [task resume];
            }
        }
        
    }
}

- (void)startDownloadTheBigFile{
    if (!self.requestArray.count) {
        return;
    }
    
    for (int i = 0; i < self.requestArray.count; i++) {
        
        NSMutableURLRequest *request = [self.requestArray objectAtIndex:i];
        NSURL *url = request.URL;
        NSString *path = [self filePathWithFileName:url.lastPathComponent];
        NSFileManager *manager = [NSFileManager defaultManager];
        if ([manager fileExistsAtPath:path]) {
            NSLog(@"file %@ already exist", url.lastPathComponent);
            NSLog(@"filePath:%@", path);
            continue;
        }
        [self getFileTotalLengthWithURL:url.absoluteString completion:^(NSInteger length) {
            //multiDownload
            
            DLQMultiDownloadQueue *multiDownload = [[DLQMultiDownloadQueue alloc] init];
            multiDownload.delegate = self;
            [multiDownload multiDownloadWithFileLength:length url:url];
            self.multiDownloadQueue = multiDownload;
        }];
    }
}

#pragma mark NSURLSessionDownloadDelegate
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [self filePathWithFileName:[downloadTask.currentRequest.URL lastPathComponent]];

    [fm moveItemAtURL:location toURL:[NSURL fileURLWithPath:path] error:nil];
    __block NSInteger index = 0;
    [self.taskArray enumerateObjectsUsingBlock:^(NSURLSessionDownloadTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (downloadTask == obj) {
            index = idx;
        }
    }];
    if ([self.delegate respondsToSelector:@selector(downloadTaskIndex:didFinishWithSavePath:)]) {
        [self.delegate downloadTaskIndex:index didFinishWithSavePath:path];
    }
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite{
    double progress = totalBytesWritten/(double)totalBytesExpectedToWrite;
    __block NSInteger index = 0;
    [self.taskArray enumerateObjectsUsingBlock:^(NSURLSessionDownloadTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (downloadTask == obj) {
            index = idx;
        }
    }];
    //返回当前正在下载的任务序号，任务进度
    if ([self.delegate respondsToSelector:@selector(downloadTaskIndex:progress:queue:)]) {
        [self.delegate downloadTaskIndex:index progress:progress queue:self];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error{
    if (error) {
        [task cancel];
        NSURLSessionDownloadTask *downloadTask = (NSURLSessionDownloadTask *)task;
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *path = [self filePathWithFileName:[downloadTask.currentRequest.URL lastPathComponent]];
        __block NSInteger index = 0;
        [self.taskArray enumerateObjectsUsingBlock:^(NSURLSessionDownloadTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (downloadTask == obj) {
                index = idx;
            }
        }];
        [fm removeItemAtPath:path error:nil];
    } else {
        NSLog(@"任务完成");
    }
}

#pragma DLQMultiDownloadQueueDelegate
- (void)multiDownloadProgress:(double)progress{
    if ([self.delegate respondsToSelector:@selector(downloadTaskIndex:progress:queue:)]) {
        [self.delegate downloadTaskIndex:0 progress:progress queue:self];
    }
}

- (void)multiDownloadDidFinished:(NSString *)filePath{
    if ([self.delegate respondsToSelector:@selector(downloadTaskIndex:didFinishWithSavePath:)]) {
        [self.delegate downloadTaskIndex:0 didFinishWithSavePath:filePath];
    }
}

- (NSString *)filePathWithFileName:(NSString *)fileName{
    NSString *fullname = @"tttttt.mp4";
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    path = [path stringByAppendingPathComponent:fullname];
    return path;
}

- (void)getFileTotalLengthWithURL:(NSString *)url
                       completion:(void(^)(NSInteger length))completion{
    NSURL *URL = [NSURL URLWithString:url];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"HEAD";
//    request.HTTPMethod = @"GET";
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *tmpResponse = (NSHTTPURLResponse *)response;
            NSLog(@"allHeaderFields:%@", tmpResponse.allHeaderFields);
        }
        NSInteger fileTotalLength = response.expectedContentLength;
        completion(fileTotalLength);
    }];
    [dataTask resume];
}

- (void)rjApplicationDidBecomeActive:(NSNotification *)notification{

}

- (void)rjApplicationDidEnterBackground:(NSNotification *)notification{

}

- (void)rjApplicationWillResignActive:(NSNotification *)notification{

}

- (void)rjApplicationWillEnterForeground:(NSNotification *)notification{

}

- (void)dealloc{
    [self.urlArray removeAllObjects];
    [self.taskArray removeAllObjects];
}

@end
