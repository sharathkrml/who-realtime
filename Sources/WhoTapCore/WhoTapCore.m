#import "WhoTapCore.h"
#import <CoreAudio/CATapDescription.h>

AudioObjectID WhoTapCreateMonoProcessTap(NSArray<NSNumber *> *processObjectIDs,
                                         NSString *name,
                                         NSError **outError) {
    CATapDescription *description = [[CATapDescription alloc] initMonoMixdownOfProcesses:processObjectIDs];
    if (description == nil) {
        if (outError) {
            *outError = [NSError errorWithDomain:@"WhoTapCore" code:-1 userInfo:@{
                NSLocalizedDescriptionKey: @"CoreAudio refused to build the tap description.",
            }];
        }
        return kAudioObjectUnknown;
    }
    description.name = name;

    AudioObjectID tap = kAudioObjectUnknown;
    OSStatus status = AudioHardwareCreateProcessTap(description, &tap);
    if (status != noErr) {
        if (outError) {
            *outError = [NSError errorWithDomain:@"WhoTapCore" code:status userInfo:@{
                NSLocalizedDescriptionKey: [NSString stringWithFormat:
                    @"Creating the process tap failed (OSStatus %d).", (int)status],
            }];
        }
        return kAudioObjectUnknown;
    }
    return tap;
}
