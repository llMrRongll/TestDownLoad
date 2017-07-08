//
//  DLQData.h
//  TestDownLoad
//
//  Created by RJ on 2017/6/30.
//  Copyright © 2017年 RJ. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DLQData : NSObject
@property (assign, nonatomic) NSInteger startSize;
@property (assign, nonatomic) NSInteger endSize;
@property (strong, nonatomic) NSData *data;
@end
