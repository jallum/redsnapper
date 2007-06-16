#import <Cocoa/Cocoa.h>

@class RSSavePanel;

@interface RSSavePanelController : NSObject {
    RSSavePanel* savePanel;
    NSMutableArray* allowedFileTypes;
	NSMutableArray* compressibleFileTypes;
    IBOutlet NSView* accessoryView;
    IBOutlet NSPopUpButton* formatPopup;
	IBOutlet NSSlider* qualitySlider;
    IBOutlet NSComboBox* _widthComboBox;
    IBOutlet NSTextField* footer;
    int selectedFileType;
    float _quality;
	int _width;
}

- (id) init;

- (RSSavePanel*) savePanel;

- (void) setSelectedFileType:(int)selectedFileType;
- (int) selectedFileType;

- (void) setQuality:(float)quality;
- (float) quality;

- (void) setWidth:(int)width;
- (int) width;

- (void) setFooterText:(NSString*)text;

- (BOOL) isQualityEnabled;

@end
