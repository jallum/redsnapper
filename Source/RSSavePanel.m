#import "RSSavePanel.h"

@implementation RSSavePanel

+ (id) savePanel
{
    NSSavePanel* savePanel = [super savePanel];
    return savePanel;
}

- (void) init
{
    _quality = 1.0;
	[super init];
}

- (void) setFilename:(NSString*)filename
{
    [_nameField setStringValue:filename];
}

- (float) quality
{
    return _quality;
}

- (void) setQuality:(float)quality
{
    _quality = quality;
}

@end
