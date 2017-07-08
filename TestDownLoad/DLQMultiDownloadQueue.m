//
//  DLQMultiDownloadQueue.m
//  TestDownLoad
//
//  Created by RJ on 2017/6/29.
//  Copyright © 2017年 RJ. All rights reserved.
//

#import "DLQMultiDownloadQueue.h"
#import "DLQData.h"
#import <UIKit/UIKit.h>

#define blockSize 1024*1024

@interface DLQMultiDownloadQueue()<NSURLSessionDownloadDelegate>
@property (strong, nonatomic) NSURLSession *session;
@end

@implementation DLQMultiDownloadQueue

{
    NSMutableArray *_aOperation;
    NSMutableArray *_aReceivedData;
    NSMutableData *_fileData;
    NSFileHandle *_fileHandle;
    NSString *_filePath;
    NSOperationQueue *_operationQueue;
    
    NSInteger _completedLength;
    double _wholeFileLength;
    NSOperationQueue *_queue;

}

- (NSURLSession *)session{
    if (_session == nil) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue currentQueue]];
    }
    return _session;
}

- (instancetype)init{
    if (self = [super init]) {
        _aOperation = [NSMutableArray array];
        _aReceivedData = [NSMutableArray array];
        _fileData = [NSMutableData data];
        _operationQueue = [[NSOperationQueue alloc] init];
        _completedLength = 0;
        _queue = [[NSOperationQueue alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)appWillResignActive:(NSNotification *)notification{
    [_queue setSuspended:YES];
}

- (void)appDidBecomeActive:(NSNotification *)notification{
    if (_queue.suspended) {
        [_queue setSuspended:NO];
    }
}

- (void)multiDownloadWithFileLength:(NSInteger)fileLength url:(NSURL *)url{
    _wholeFileLength = fileLength;

    NSString *filePath = [self filePathWithFileName:url.lastPathComponent];
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:filePath]) {
        [fm removeItemAtPath:filePath error:nil];
    }
    [[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil];

    _filePath = filePath;
    _fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    [_fileHandle truncateFileAtOffset:fileLength];
    
    NSBlockOperation *addOperationOP = [NSBlockOperation blockOperationWithBlock:^{
        while (_completedLength < fileLength) {
            long long startSize = _completedLength;
            long long endSize = startSize+blockSize;
            
            if (endSize > fileLength) {
                endSize = fileLength - 1;
                _completedLength = fileLength;
            } else {
                _completedLength += blockSize;
            }
            
            //一个operation对应一个downloadTask
            
            NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
                
                NSString *range=[NSString stringWithFormat:@"bytes=%lld-%lld", startSize, endSize];
                NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
                [request setValue:range forHTTPHeaderField:@"Range"];
                NSLog(@"requestHeader:%@", request.allHTTPHeaderFields);
                NSURLSessionDownloadTask *task = [self.session downloadTaskWithRequest:request];
                
                [task resume];
                
            }];
            [_queue addOperation:operation];
        }
    }];
    [_queue addOperation:addOperationOP];
    
}


- (NSString *)filePathWithFileName:(NSString *)fileName{
    NSString *fullname = fileName;
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    path = [path stringByAppendingPathComponent:fullname];
    return path;
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location{
    
    DLQData *tmpReceivedData = [[DLQData alloc] init];
    NSInteger startSize = 0;
    NSInteger endSize = 0;
    
    if ([downloadTask.response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *tmpResponse = (NSHTTPURLResponse *)downloadTask.response;
        NSDictionary *dic = tmpResponse.allHeaderFields;
//        NSLog(@"diiiiiic: %@", dic[@"Content-Range"]);
        NSString *fileRange = dic[@"Content-Range"];
        fileRange = [fileRange stringByReplacingOccurrencesOfString:@"bytes" withString:@""];
        fileRange = [fileRange stringByReplacingOccurrencesOfString:@" " withString:@""];
        NSArray *aTmp1 = [fileRange componentsSeparatedByString:@"/"];
        NSArray *aTmp2 = @[];
        if (aTmp1.count) {
            NSString *tmpStr = aTmp1[0];
            aTmp2 = [tmpStr componentsSeparatedByString:@"-"];
            if (aTmp1.count >= 2) {
                NSString *startSizeStr = aTmp2[0];
                NSString *endSizeStr = aTmp2[1];
                startSize = startSizeStr.integerValue;
                endSize = endSizeStr.integerValue;
        
                tmpReceivedData.data = [NSData dataWithContentsOfURL:location];
                tmpReceivedData.startSize = startSize;
                tmpReceivedData.endSize = endSize;
                
                [_fileHandle seekToFileOffset:tmpReceivedData.startSize];
                [_fileHandle writeData:tmpReceivedData.data];
                [_fileData appendData:tmpReceivedData.data];
                
                NSLog(@"realDataLength = %lu calculatedDataLength = %ld", (unsigned long)tmpReceivedData.data.length, tmpReceivedData.endSize - tmpReceivedData.startSize);
                
                double progress = _fileData.length/_wholeFileLength;
                progress = progress >= 1 ? 1 : progress;
                if (progress == 1) {
                    NSLog(@"分段下载完成");
                    NSLog(@"downloadProgress:%f", progress);
                    
                    [_operationQueue cancelAllOperations];
                    _operationQueue = nil;
                    
                    if ([self.delegate respondsToSelector:@selector(multiDownloadDidFinished:)] && [self.delegate respondsToSelector:@selector(multiDownloadProgress:)]) {
                        NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];
                        [mainQueue addOperationWithBlock:^{
                            [self.delegate multiDownloadProgress:progress];
                            [self.delegate multiDownloadDidFinished:_filePath];

                        }];
                    }
                }else{
                    if ([self.delegate respondsToSelector:@selector(multiDownloadProgress:)]) {
                        NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];
                        [mainQueue addOperationWithBlock:^{
                            [self.delegate multiDownloadProgress:progress];
                        }];
                    }
                }
            }
        }
    }
}
@end
