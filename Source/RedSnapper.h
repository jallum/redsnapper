#import <Cocoa/Cocoa.h>

@class WebView;

@interface RedSnapper : NSObject {
@private
    NSDictionary* parameters;
}

+ (RedSnapper*) sharedInstance;
- (NSDictionary*) parameters;

- (void) savePanelDidEnd:(NSSavePanel*)sheet returnCode:(int)returnCode contextInfo:(WebView*)webView;
- (void) alertForCorruption:(NSWindow*)window;
- (void) alertForExpiration:(NSWindow*)window;
- (void) snapWebViewToClipboardImage:(WebView*)webView;
- (void) snapWebViewToClipboardPDF:(WebView*)webView;
- (void) snapWebViewToFile:(WebView*)webView expiresOn:(NSDate*)expiresOn;
- (void) snapPageFromToolbar:(id)sender;
- (void) snapPageFromMenu:(id)sender;

int MDItemSetAttribute(MDItemRef item, CFStringRef attribute, CFTypeRef value);

@end
