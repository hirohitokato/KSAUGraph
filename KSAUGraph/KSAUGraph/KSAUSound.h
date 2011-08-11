//
//  KSAUSound.h
//  KSAUGraph
//
//  Created by 加藤寛人 on 11/08/11.
//  Copyright 2011 KatokichiSoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import "iPhoneCoreAudio.h"

@interface KSAUSound : NSObject {
    AudioUnitSampleType **playBuffer_;  // サウンドデータ
    UInt32 numberOfChannels_;           // サウンドファイルのチャンネル数
    SInt64 totalFrames_;                // サウンドファイルの全フレーム数
}
@property (nonatomic, readonly, assign)AudioUnitSampleType **data;  // サウンドデータ
@property (nonatomic, readonly, assign)UInt32 numberOfChannels; // サウンドファイルのチャンネル数
@property (nonatomic, readonly, assign)SInt64 totalFrames;      // サウンドファイルの全フレーム数

+(id)soundWithContentsOfURL:(NSURL*)url;
-(id)initWithContentsOfURL:(NSURL*)url;
@end
