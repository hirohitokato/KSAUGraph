/*
 *  iPhoneCoreAudio.c
 *
 *  Created by nagano on 09/07/20.
 *
 */

#include "iPhoneCoreAudio.h"

#pragma mark ASBD utilities
AudioStreamBasicDescription AUCanonicalASBD(Float64 sampleRate, 
                                            UInt32 channel){
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate         = sampleRate;
    audioFormat.mFormatID           = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags        = kAudioFormatFlagsAudioUnitCanonical;
    audioFormat.mChannelsPerFrame   = channel;
    audioFormat.mBytesPerPacket     = sizeof(AudioUnitSampleType);
    audioFormat.mBytesPerFrame      = sizeof(AudioUnitSampleType);
    audioFormat.mFramesPerPacket    = 1;
    audioFormat.mBitsPerChannel     = 8 * sizeof(AudioUnitSampleType);
    audioFormat.mReserved           = 0;
    return audioFormat;
}


AudioStreamBasicDescription CanonicalASBD(Float64 sampleRate, 
                                          UInt32 channel){
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate         = sampleRate;
    audioFormat.mFormatID           = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags        = kAudioFormatFlagsCanonical;
    audioFormat.mChannelsPerFrame   = channel;
    audioFormat.mBytesPerPacket     = sizeof(AudioSampleType) * audioFormat.mChannelsPerFrame;
    audioFormat.mBytesPerFrame      = sizeof(AudioSampleType) * audioFormat.mChannelsPerFrame;
    audioFormat.mFramesPerPacket    = 1;
    audioFormat.mBitsPerChannel     = 8 * sizeof(AudioSampleType);
    audioFormat.mReserved           = 0;
    return audioFormat;
}

void AudioSessionSetFrameBufferSize(Float64 sampleRate,
                                    int frameBufferSize) {
    AudioSessionInitialize(NULL, NULL, NULL, NULL);
    Float32 duration = frameBufferSize / sampleRate;
    UInt32 size = sizeof(Float32);
    OSStatus err = AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration,
                                           size, &duration);
    KSAUCheckError(err, "error setting PreferredHardwareIOBufferDuration");
    if (1) { // debug
        Float32 newDuration;
        size = sizeof(Float32);
        AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareIOBufferDuration,
                                &size, &newDuration);
        NSLog(@"New buffer size(%f) <== requested size(%d)",
              sampleRate*newDuration, frameBufferSize);
    }
    AudioSessionSetActive(TRUE);
}

void printASBD(AudioStreamBasicDescription audioFormat){
    UInt32 mFormatFlags = audioFormat.mFormatFlags;
    NSMutableArray *flags = [NSMutableArray array];
    
    if(mFormatFlags & kAudioFormatFlagIsFloat)[flags addObject:@"kAudioFormatFlagIsFloat"];
    if(mFormatFlags & kAudioFormatFlagIsBigEndian)[flags addObject:@"kAudioFormatFlagIsBigEndian"];
    if(mFormatFlags & kAudioFormatFlagIsSignedInteger)[flags addObject:@"kAudioFormatFlagIsSignedInteger"];
    if(mFormatFlags & kAudioFormatFlagIsPacked)[flags addObject:@"kAudioFormatFlagIsPacked"];
    if(mFormatFlags & kAudioFormatFlagIsNonInterleaved)[flags addObject:@"kAudioFormatFlagIsNonInterleaved"];
    
    if(mFormatFlags & kAudioFormatFlagIsAlignedHigh)[flags addObject:@"kAudioFormatFlagIsAlignedHigh"];
    if(mFormatFlags & kAudioFormatFlagIsNonMixable)[flags addObject:@"kAudioFormatFlagIsNonMixable"];
    if(mFormatFlags & (kAudioUnitSampleFractionBits << kLinearPCMFormatFlagsSampleFractionShift))[flags addObject:@"(kAudioUnitSampleFractionBits << kLinearPCMFormatFlagsSampleFractionShift)"];
    
    NSMutableString *flagsString = [NSMutableString string];
    for(int i = 0; i < [flags count]; i++){
        [flagsString appendString:[flags objectAtIndex:i]];
        if(i != [flags count] - 1)[flagsString appendString:@"|"];
    }
    if([flags count] == 0)[flagsString setString:@"0"];
    
    char formatID[5];
	*(UInt32 *)formatID = CFSwapInt32HostToBig(audioFormat.mFormatID);
	formatID[4] = '\0';
    
    printf("\n");
    printf("audioFormat.mSampleRate       = %.2f;\n",audioFormat.mSampleRate);
    printf("audioFormat.mFormatID         = '%-4.4s;'\n",formatID);
    printf("audioFormat.mFormatFlags      = %s;\n",[flagsString UTF8String]);
    printf("audioFormat.mBytesPerPacket   = %lu;\n",audioFormat.mBytesPerPacket);
    printf("audioFormat.mFramesPerPacket  = %lu;\n",audioFormat.mFramesPerPacket);
    printf("audioFormat.mBytesPerFrame    = %lu;\n",audioFormat.mBytesPerFrame);
    printf("audioFormat.mChannelsPerFrame = %lu;\n",audioFormat.mChannelsPerFrame);
    printf("audioFormat.mBitsPerChannel   = %lu;\n",audioFormat.mBitsPerChannel);
    printf("\n");
}

#pragma mark -
#pragma mark Error checker
void KSAUCheckError(OSStatus err,const char *message){
    if(err){
        char property[5];
        *(UInt32 *)property = CFSwapInt32HostToBig(err);
        property[4] = '\0';
        NSLog(@"%s = %-4.4s, %ld",message, property,err);
        exit(1);
    }
}
