#import <Cocoa/Cocoa.h>

@interface RSSavePanel : NSSavePanel {
}

+ (id) savePanel;

- (void) setFilename:(NSString*)filename;

@end
