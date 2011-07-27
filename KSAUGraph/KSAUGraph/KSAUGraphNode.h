//
//  KSAUGraphNode.h
//  KSAUGraph
//
//  Created by 加藤寛人 on 11/07/27.
//  Copyright 2011 KatokichiSoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import "iPhoneCoreAudio.h"

@class KSAUGraphManager;

typedef struct {
    void*                       inRefCon;
    AudioUnitRenderActionFlags* ioActionFlags;
    const AudioTimeStamp*       inTimeStamp;
    UInt32                      inBusNumber;
    UInt32                      inNumberFrames;
    AudioBufferList*            ioData;
} ksAUGraphNodeCallBackInfo;

@interface KSAUGraphNode : NSObject {
    // 接続先グラフ
    KSAUGraphManager *manager_;
    // 接続先のチャネル（バス）番号
    int channel_;
}
@property (assign, nonatomic)KSAUGraphManager* manager;
@property (assign, nonatomic)int channel;

@end
