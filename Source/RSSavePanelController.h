#import <Cocoa/Cocoa.h>

@class RSSavePanel;

@interface RSSavePanelController : NSObject {
    RSSavePanel* savePanel;
    NSMutableArray* allowedFileTypes;
    IBOutlet NSView* accessoryView;
    IBOutlet NSPopUpButton* formatPopup;
	IBOutlet NSSlider* qualitySlider;
    IBOutlet NSTextField* footer;
    int selectedFileType;
    float _quality;
}

- (id) init;

- (RSSavePanel*) savePanel;

- (void) setSelectedFileType:(int)selectedFileType;
- (int) selectedFileType;

- (void) setQuality:(float)quality;
- (float) quality;

- (void) setFooterText:(NSString*)text;

- (BOOL) isQualityEnabled;

@end
