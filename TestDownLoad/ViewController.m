//
//  ViewController.m
//  TestDownLoad
//
//  Created by RJ on 2017/6/29.
//  Copyright © 2017年 RJ. All rights reserved.
//

#import "ViewController.h"
#import "DLQDownloadQueue.h"

@interface ViewController ()<DownloadQueueDelegate>
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UIProgressView *progressView1;
@property (strong, nonatomic) DLQDownloadQueue *queue1;
@property (strong, nonatomic) DLQDownloadQueue *queue2;

@end

@implementation ViewController

//    支持HEAD请求URL
//    http://mvvideo2.meitudata.com/5785a7e3e6a1b824.mp4
static NSString *url = @"http://mvvideo2.meitudata.com/5785a7e3e6a1b824.mp4";

- (void)viewDidLoad {
    [super viewDidLoad];
    self.progressView.progress = 0;
    self.progressView.transform = CGAffineTransformMakeScale(1.0, 3.0);
    
    self.progressView1.progress = 0;
    self.progressView1.transform = CGAffineTransformMakeScale(1.0, 3.0);
    
    

    self.queue1 = [[DLQDownloadQueue alloc] init];
    self.queue1.delegate = self;
    [self.queue1 addDownloadTaskURL:url];
    [self.queue1 startDownloadTheBigFile];
    
    self.queue2 = [[DLQDownloadQueue alloc] init];
    self.queue2.delegate = self;
    [self.queue2 addDownloadTaskURL:url];
    
    
    [self.queue2 startDownload];
    
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)downloadTaskIndex:(NSInteger)taskIndex progress:(double)progress queue:(DLQDownloadQueue *)queue{
    if (queue == self.queue1) {
        [self.progressView setProgress:progress animated:YES];

    }else{
        [self.progressView1 setProgress:progress animated:YES];
    }
}

- (void)downloadTaskIndex:(NSInteger)taskIndex didFinishWithSavePath:(NSString *)savePath{
    NSLog(@"path:%@", savePath);
}
- (IBAction)testDownload:(id)sender {
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSArray<NSString *> *subPaths = [fm subpathsAtPath:path];
    if (subPaths.count) {
        for (int i = 0; i < subPaths.count; i++) {
            NSLog(@"subPath:%@", subPaths[i]);
            NSString *tmpPath = [path stringByAppendingPathComponent:subPaths[i]];
            [fm removeItemAtPath:tmpPath error:nil];
        }
    }
    
    [self.progressView setProgress:0 animated:NO];
    [self.progressView1 setProgress:0 animated:NO];
    self.queue1 = [[DLQDownloadQueue alloc] init];
    self.queue1.delegate = self;
    [self.queue1 addDownloadTaskURL:url];
    [self.queue1 startDownloadTheBigFile];
    
    self.queue2 = [[DLQDownloadQueue alloc] init];
    self.queue2.delegate = self;
    [self.queue2 addDownloadTaskURL:url];
    [self.queue2 startDownload];
}

@end
//
