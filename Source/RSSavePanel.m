#import "RSSavePanel.h"

@implementation RSSavePanel

+ (id) savePanel
{
    NSSavePanel* savePanel = [super savePanel];
    return savePanel;
}

- (void) setFilename:(NSString*)filename
{
    [_nameField setStringValue:filename];
}

@end
