// Linked only into the Mac light tuner. SDL's Metal backend uses the system default device.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <stdint.h>
#include <stdio.h>

typedef struct { const uint8_t *data; int64_t len; } CapturePath;

uint8_t tuner_capture_start(CapturePath path) {
    @autoreleasepool {
        MTLCaptureManager *manager = [MTLCaptureManager sharedCaptureManager];
        if (![manager supportsDestination:MTLCaptureDestinationGPUTraceDocument]) {
            fprintf(stderr, "Metal file capture is unavailable. Start the tuner with MTL_CAPTURE_ENABLED=1.\n");
            return 0;
        }
        NSString *name = [[[NSString alloc] initWithBytes:path.data
                                                   length:(NSUInteger)path.len
                                                 encoding:NSUTF8StringEncoding] autorelease];
        if (!name) return 0;
        MTLCaptureDescriptor *descriptor = [[[MTLCaptureDescriptor alloc] init] autorelease];
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (!device) return 0;
        descriptor.captureObject = device;
        descriptor.destination = MTLCaptureDestinationGPUTraceDocument;
        descriptor.outputURL = [NSURL fileURLWithPath:name isDirectory:NO];
        NSError *error = nil;
        BOOL started = [manager startCaptureWithDescriptor:descriptor error:&error];
        if (!started) fprintf(stderr, "Metal capture: %s\n", error.localizedDescription.UTF8String ?: "unknown error");
        [device release];
        return started;
    }
}

void tuner_capture_stop(void) {
    @autoreleasepool {
        [[MTLCaptureManager sharedCaptureManager] stopCapture];
    }
}
