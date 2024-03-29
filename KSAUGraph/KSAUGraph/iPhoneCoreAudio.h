/*
 *  iPhoneCoreAudio.h
 *
 *  Created by Norihisa Nagano
 *
 */

#if !defined(__iPhoneCoreAudio_h__)
#define __iPhoneCoreAudio_h__
#include <AudioToolbox/AudioToolbox.h>

extern AudioStreamBasicDescription AUCanonicalASBD(Float64 sampleRate, 
                                                   UInt32 channel);
extern AudioStreamBasicDescription CanonicalASBD(Float64 sampleRate, 
                                                 UInt32 channel);
extern void AudioSessionSetFrameBufferSize(Float64 sampleRate,
                                           int frameBufferSize);
extern OSStatus KSAudioSessionSetCategory(UInt32 category);

extern void printASBD(AudioStreamBasicDescription audioFormat);

extern void KSAUCheckError(OSStatus err,const char *message);
#endif  //  __iPhoneCoreAudio_h__