#import "RSSavePanel.h"

@implementation RSSavePanel

+ (id) savePanel
{
    NSSavePanel* savePanel = [super savePanel];
    return savePanel;
}

- (void) dealloc
{
    [_quality release];
    [super dealloc];
}

- (void) setFilename:(NSString*)filename
{
    [_nameField setStringValue:filename];
	[self setQuality:0.0];
}

- (NSNumber*) quality
{
    if(!_quality) {
        [self setQuality:1.0];
    }
    return _quality;
}

- (void) setQuality:(float)quality
{
    [_quality release];
    _quality = [[NSNumber numberWithFloat:quality] retain];
}

@end
