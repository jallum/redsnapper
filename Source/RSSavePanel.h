#import <Cocoa/Cocoa.h>

@interface RSSavePanel : NSSavePanel {
	NSNumber* _quality;
}

+ (id) savePanel;

- (void) setFilename:(NSString*)filename;

- (NSNumber*) quality;

- (void) setQuality:(float)quality;

@end
