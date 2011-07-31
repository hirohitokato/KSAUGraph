//
//  ksauIntervalInfo.m
//  KSAUGraph
//
//  Created by 加藤 寛人 on 11/07/30.
//  Copyright 2011 KatokichiSoft. All rights reserved.
//

#import "ksauIntervalInfo.h"


@implementation ksauIntervalInfo
@synthesize nextTriggerFrame=nextTriggerFrame_, channel=channel_, count=count_;
- (id)init {
    self = [super init];
    if (self) {
        nextTriggerFrame_ = 0;
        channel_ = -1;
        count_ = 0;
    }
    return self;
}
@end
