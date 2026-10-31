#import <CoreAudio/AudioHardware.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// CoreAudio's process-tap API takes a `CATapDescription`, whose initializers
/// are `NS_REFINED_FOR_SWIFT`. This shim exposes the one call we need.
///
/// Creates a system process tap that mixes down the audio output of the given
/// process objects (audio object IDs, `kAudioHardwarePropertyProcessObjectList`)
/// to mono, and returns the new tap's audio object ID.
extern AudioObjectID WhoTapCreateMonoProcessTap(NSArray<NSNumber *> *processObjectIDs,
                                                NSString *name,
                                                NSError **outError);

NS_ASSUME_NONNULL_END
