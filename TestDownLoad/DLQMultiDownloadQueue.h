//
//  DLQMultiDownloadQueue.h
//  TestDownLoad
//
//  Created by RJ on 2017/6/29.
//  Copyright © 2017年 RJ. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol DLQMultiDownloadQueueDelegate <NSObject>
@required
- (void)multiDownloadProgress:(double)progress;
- (void)multiDownloadDidFinished:(NSString *)filePath;
@end

@interface DLQMultiDownloadQueue : NSObject

@property (strong, nonatomic) id<DLQMultiDownloadQueueDelegate>delegate;

- (void)multiDownloadWithFileLength:(NSInteger)fileLength url:(NSURL *)url;
@end
