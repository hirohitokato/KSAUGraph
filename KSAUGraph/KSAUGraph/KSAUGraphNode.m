//
//  KSAUGraphNode.m
//  KSAUGraph
//
//  Created by 加藤寛人 on 11/07/27.
//  Copyright 2011 KatokichiSoft. All rights reserved.
//

#import "KSAUGraphNode.h"
#import "KSAUSound.h"
#import "iPhoneCoreAudio.h"

@interface KSAUGraphNode ()
@end

@implementation KSAUGraphNode
@synthesize channel = channel_, sound = sound_;
@synthesize isPlaying = isPlaying_;
@synthesize cumulativeFrames = cumulativeFrames_;
@synthesize currentFrame = currentPos_;
@synthesize nextTriggerFrame = nextTriggerFrame_;
@synthesize nextChannel = nextChannel_;

#pragma mark Memory management
- (id)init {
    self = [super init];
    if (self) {
        sound_ = nil;
        [self reset];
    }
    return self;
}
- (void)dealloc {
    [sound_ release];
    [super dealloc];
}

#pragma mark -
#pragma mark Rendering
- (void)reset {
    currentPos_ = 0;
    cumulativeFrames_ = 0;
    nextChannel_ = -1;
    nextTriggerFrame_ = 0;
    isPlaying_ = NO;
}
- (void)preparePlay {
    if (!sound_) {
        NSLog(@"Error: Unable to play sound. the data is nil.");
        return;
    }
    currentPos_ = 0;
    isPlaying_ = YES;
}

- (UInt32)renderCallbackWithFlags:(AudioUnitRenderActionFlags *)ioActionFlags
                        timeStamp:(const AudioTimeStamp *)inTimeStamp
                        busNumber:(UInt32)inBusNumber
                   inNumberFrames:(UInt32)inNumberFrames
                          outLeft:(AudioUnitSampleType *)outL
                         outRight:(AudioUnitSampleType *)outR {

    AudioUnitSampleType **buffer = sound_.data;
    SInt64 currentPos = currentPos_;
    SInt64 totalFrames = sound_.totalFrames;
    UInt32 numberOfChannels = sound_.numberOfChannels;

    int amount;
    for (amount = 0; amount< inNumberFrames; amount++) {
        if (isPlaying_){
            // 全データの埋め込みが完了したかどうか判定
            if (currentPos >= totalFrames) {
                currentPos = 0;
                isPlaying_ = NO;
            }
            // データの埋め込み
            if (numberOfChannels == 2) { //ステレオの場合
                *outL++ = buffer[0][currentPos++];
                *outR++ = buffer[1][currentPos];    
            } else { // モノラル
                *outL++ = buffer[0][currentPos++];
                *outR++ = buffer[0][currentPos];
            }
        } else {
            //再生するサンプルが無いので0で埋める
            *outL++ = *outR++ = 0;
        }
    }    
    currentPos_ = currentPos;
    cumulativeFrames_ += inNumberFrames;

    return amount;
}


@end
