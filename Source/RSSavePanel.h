#import <Cocoa/Cocoa.h>

@interface RSSavePanel : NSSavePanel {
	float _quality;
}

+ (id) savePanel;

- (void) setFilename:(NSString*)filename;

- (float) quality;

- (void) setQuality:(float)quality;

@end
