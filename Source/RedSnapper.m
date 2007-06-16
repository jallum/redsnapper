#import "RedSnapper.h"
#import "RSSavePanel.h"
#import "RSSavePanelController.h"
#import "Safari.h"
#import <openssl/rsa.h>
#import <openssl/sha.h>
#import <objc/objc-class.h>
#import <WebKit/WebKit.h>
#import <Carbon/Carbon.h>

#define RSLocalizedString(x, y)     [[NSBundle bundleForClass:[RedSnapper class]] localizedStringForKey:x value:x table:nil]

@interface NSObject (WebKitPrivateStuff)
- (NSBitmapImageRep*) _printedPluginBitmap;
@end

@interface DOMDocument (RS_10_4)
- (DOMNodeList*) getElementsByTagNameNS:(NSString*)a localName:(NSString*)b;
@end

@interface DOMElement (RS_10_4)
- (NSRect) boundingBox;
- (NSURL*) absoluteLinkURL;
@end

static BOOL supplyInstanceImplementationIfNotPresent(Class aClass, SEL selA, SEL selB)
{
    Method methodA = class_getInstanceMethod(aClass, selA);
    Method methodB = class_getInstanceMethod(aClass, selB);
    if (methodA == nil && methodB != nil) {
        struct objc_method_list* ml = calloc(1, sizeof(struct objc_method_list));
        ml->method_count = 1;
        ml->method_list[0].method_name  = sel_registerName((char*)selA);
        ml->method_list[0].method_types = methodB->method_types;
        ml->method_list[0].method_imp   = methodB->method_imp;
        class_addMethods(aClass, ml);
        return YES;
    } else {
        return NO;
    }
}

static BOOL swapInstanceImplementations(Class aClass, SEL selA, SEL selB)
{
    Method methodA = class_getInstanceMethod(aClass, selA);
    Method methodB = class_getInstanceMethod(aClass, selB);
    if (methodA != nil && methodB != nil) {
        IMP i = methodA->method_imp;
        methodA->method_imp = methodB->method_imp;
        methodB->method_imp = i;
        return YES;
    } else {
        return NO;
    }
}

static NSDictionary* loadParameters()
{
    RSA* rsaKey = RSA_new();

    /*  Create the public key.
     */
    unsigned char RSA_N[] = {
        0xcb, 0xe2, 0x98, 0xbc, 0x53, 0x84, 0xd3, 0x84 ^ 'R',
        0xc7, 0x4f, 0xb1, 0x3a, 0x54, 0x72, 0xd4, 0xf8 ^ 'E',
        0xd6, 0xa0, 0xab, 0x95, 0x35, 0xa4, 0xd8, 0xc8 ^ 'D',
        0x20, 0x62, 0x4a, 0xd0, 0xc9, 0x26, 0x74, 0x92 ^ ' ',
        0x4b, 0x04, 0x09, 0xf5, 0x7e, 0xf1, 0x3e, 0x99 ^ 'S',
        0x80, 0x52, 0xac, 0x1c, 0x19, 0xb1, 0x43, 0xa2 ^ 'N',
        0xf4, 0xd6, 0x62, 0x7b, 0xfd, 0x0a, 0x30, 0x5f ^ 'A',
        0xfc, 0x45, 0xda, 0xde, 0x6e, 0x6c, 0xca, 0x66 ^ 'P',
        0x6e, 0x59, 0xb8, 0x30, 0x04, 0xe8, 0xdd, 0x4c ^ 'P',
        0xed, 0x1e, 0x57, 0xa6, 0xb8, 0x25, 0xa2, 0x72 ^ 'E',
        0x4f, 0x4c, 0xb4, 0x1a, 0x05, 0xf6, 0x8a, 0x95 ^ 'R',
        0xbd, 0x51, 0x7b, 0xfa, 0xa9, 0x83, 0xde, 0xf5 ^ ' ',
        0x79, 0x1d, 0x7a, 0x30, 0xc4, 0xc7, 0xd0, 0x55 ^ '1',
        0x05, 0xd0, 0xef, 0x30, 0xca, 0xd5, 0xc0, 0xa2 ^ '.',
        0xc4, 0x08, 0x20, 0xec, 0x6b, 0xb5, 0xc7, 0x87 ^ '3',
        0xe5, 0x4d, 0x99, 0xe7, 0xf5, 0x5e, 0x7e, 0x1d ^ ' ',
    };
    char* salt = "RED SNAPPER 1.3 ";
    for (int i = 0, imax = strlen(salt); i < imax; i++) {
        RSA_N[((i + 1) << 3) - 1] ^= salt[i];
    }
    rsaKey->n = BN_bin2bn(RSA_N, sizeof(RSA_N), NULL);

    /*  Create the exponent.
     */
    unsigned char RSA_E[] = {
        0x03
    };
	rsaKey->e = BN_bin2bn(RSA_E, sizeof(RSA_E), NULL);

    /*  Load the license file, and check it for basic validity.
     */
    CFMutableDictionaryRef myDict = nil;
	CFDataRef data;
	SInt32 errorCode;
	NSString* licenseFile = [[NSBundle bundleForClass:[RedSnapper class]] pathForResource:@"license" ofType:@"plist"];
	if (!licenseFile || !CFURLCreateDataAndPropertiesFromResource(kCFAllocatorDefault, (CFURLRef)[NSURL fileURLWithPath:licenseFile], &data, NULL, NULL, &errorCode) || errorCode) {
        RSA_free(rsaKey);
        return NULL;
    } else {
        CFStringRef errorString = NULL;
        myDict = (CFMutableDictionaryRef)CFPropertyListCreateFromXMLData(kCFAllocatorDefault, data, kCFPropertyListMutableContainers, &errorString);
        CFRelease(data);
        data = NULL;
        if (errorString || CFDictionaryGetTypeID() != CFGetTypeID(myDict) || !CFPropertyListIsValid(myDict, kCFPropertyListXMLFormat_v1_0)) {
            CFRelease(myDict);
            RSA_free(rsaKey);
            return NULL;
        }
    }
    
    /*  Extract the signature.
     */
    unsigned char sigBytes[128];
    if (!CFDictionaryContainsKey(myDict, CFSTR("Signature"))) {
        CFRelease(myDict);
        RSA_free(rsaKey);
        return NULL;
    } else {
        CFDataRef sigData = CFDictionaryGetValue(myDict, CFSTR("Signature"));
        CFDataGetBytes(sigData, CFRangeMake(0, 128), sigBytes);
        CFDictionaryRemoveValue(myDict, CFSTR("Signature"));
    }
    
    /*  Decrypt the signature.
     */
    unsigned char checkDigest[128] = {0};
    if (RSA_public_decrypt(128, sigBytes, checkDigest, rsaKey, RSA_PKCS1_PADDING) != SHA_DIGEST_LENGTH) {
        CFRelease(myDict);
        RSA_free(rsaKey);
        return NULL;
    } else {
        RSA_free(rsaKey);
        rsaKey = NULL;
    }
    
    /*  Get the number of elements, Load the keys and build up the key array.
     */
    CFIndex count = CFDictionaryGetCount(myDict);
    CFMutableArrayRef keyArray = CFArrayCreateMutable(kCFAllocatorDefault, count, NULL);
    CFStringRef keys[count];
    CFDictionaryGetKeysAndValues(myDict, (const void**)&keys, NULL);
    for (int i = 0; i < count; i++) {
        CFArrayAppendValue(keyArray, keys[i]);
    }

    /*  Sort the array, so that we'll have consistent hashes.
     */
    int context = kCFCompareCaseInsensitive;
    CFArraySortValues(keyArray, CFRangeMake(0, count), (CFComparatorFunction)CFStringCompare, &context);
    
    /*  Hash the keys and values.
     */
    SHA_CTX ctx;
    SHA1_Init(&ctx);
    for (int i = 0; i < count; i++) {
        char *valueBytes;
        int valueLengthAsUTF8;
        CFStringRef key = CFArrayGetValueAtIndex(keyArray, i);
        CFStringRef value = CFDictionaryGetValue(myDict, key);

        // Account for the null terminator
        valueLengthAsUTF8 = CFStringGetMaximumSizeForEncoding(CFStringGetLength(value), kCFStringEncodingUTF8) + 1;
        valueBytes = (char *)malloc(valueLengthAsUTF8);
        CFStringGetCString(value, valueBytes, valueLengthAsUTF8, kCFStringEncodingUTF8);
        SHA1_Update(&ctx, valueBytes, strlen(valueBytes));
        free(valueBytes);
    }
    unsigned char digest[SHA_DIGEST_LENGTH];
    SHA1_Final(digest, &ctx);
    
    if (keyArray != nil) {
        CFRelease(keyArray);
    }
    
    /*  Check if the signature is a match.
     */
    for (int i = 0; i < SHA_DIGEST_LENGTH; i++) {
        if (checkDigest[i] ^ digest[i]) {
            CFRelease(myDict);
            return NULL;
        }
    }

    return (NSDictionary*)myDict;
}

@implementation BrowserWindowController (RedSnapper)

- (NSRect) RedSnapper_notPresent_window:(NSWindow*)window willPositionSheet:(NSWindow*)sheet usingRect:(NSRect)rect 
{
    return rect;
}

- (NSRect) RedSnapper_window:(NSWindow*)window willPositionSheet:(NSWindow*)sheet usingRect:(NSRect)r1 
{
    NSRect r2 = [self RedSnapper_window:window willPositionSheet:sheet usingRect:r1];
    if (NSEqualRects(r1, r2) && ([sheet isKindOfClass:[RSSavePanel class]] || [sheet class] == [NSPanel class])) {
        r2.origin.y -= 31;
    }
    return r2;
}

@end

@implementation ToolbarController (RedSnapper)

- (IBAction) RedSnapper_snapPage:(id)sender
{
    [[RedSnapper sharedInstance] snapPageFromToolbar:sender];
}

- (BrowserToolbarItem*) RedSnapper_toolbar:(BrowserToolbar*)toolbar itemForItemIdentifier:(NSString*)identifier willBeInsertedIntoToolbar:(BOOL)flag
{
    if ([@"RedSnapper" isEqualTo:identifier]) {
        NSButton* button = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 28, 25)];
        [button setTitle:@"Red Snapper"];
        [button setBordered:NO];
        [button setButtonType:NSMomentaryChangeButton];
        [button setImage:[[[NSImage alloc] initByReferencingFile:[[NSBundle bundleForClass:[RedSnapper class]] pathForResource:@"Toolbar" ofType:@"png"]] autorelease]];
        [button setAlternateImage:[[[NSImage alloc] initByReferencingFile:[[NSBundle bundleForClass:[RedSnapper class]] pathForResource:@"ToolbarPressed" ofType:@"png"]] autorelease]];
        [button setAction:@selector(RedSnapper_snapPage:)];
        [button setTarget:self];
        return [[BrowserToolbarItem alloc] initWithItemIdentifier:@"RedSnapper" target:self button:button];
    } else {
        BrowserToolbarItem* item = [self RedSnapper_toolbar:toolbar itemForItemIdentifier:identifier willBeInsertedIntoToolbar:flag];
        return item;
    }
}

- (NSArray*) RedSnapper_toolbarAllowedItemIdentifiers:(BrowserToolbar*)toolbar
{
    NSMutableArray* items = [NSMutableArray arrayWithArray:[self RedSnapper_toolbarAllowedItemIdentifiers:toolbar]];
    [items addObject:@"RedSnapper"];
    return items;
}

@end

@implementation RedSnapper

+ (RedSnapper*) sharedInstance
{
    static RedSnapper* sharedInstance = nil;
    if (!sharedInstance) {
        sharedInstance = [[RedSnapper alloc] init];
    }
    return sharedInstance;
}

+ (void) install
{
    /*  Add in default implementations, if they don't already exist.
     */
    supplyInstanceImplementationIfNotPresent(
        [BrowserWindowController class],
        @selector(window:willPositionSheet:usingRect:),
        @selector(RedSnapper_notPresent_window:willPositionSheet:usingRect:)
    );

    /*  Hijack the implementations of a few key methods. 
     */
    swapInstanceImplementations(
        [BrowserWindowController class],
        @selector(window:willPositionSheet:usingRect:),
        @selector(RedSnapper_window:willPositionSheet:usingRect:)
    );
    swapInstanceImplementations(
        [ToolbarController class], 
        @selector(toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:),
        @selector(RedSnapper_toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:)
    );
    swapInstanceImplementations(
        [ToolbarController class], 
        @selector(toolbarAllowedItemIdentifiers:), 
        @selector(RedSnapper_toolbarAllowedItemIdentifiers:)
    );

    /*  De-Obfuscate our init routine.
     */
    swapInstanceImplementations(
        [RedSnapper class],
        @selector(init),
        @selector(initWithParameters:)
    );

    [[RedSnapper sharedInstance] performSelectorOnMainThread:@selector(completeInstallation) withObject:nil waitUntilDone:NO];
}

- (void) completeInstallation
{
    /*  For anyone watching (that cares)...
    */
    NSLog(@"RedSnapper Installed.");

    /*  Hijack a spot on Safari's application menu.
    */
    NSMenu* mainMenu = [[NSApplication sharedApplication] mainMenu];
    if (mainMenu) {
        NSMenu* fileMenu = [[mainMenu itemAtIndex:1] submenu];
        if (fileMenu) {
            NSMenuItem* menuItem = [[[NSMenuItem alloc] init] autorelease];
            [menuItem setTitle:RSLocalizedString(@"Export with Red Snapper", @"")];
            [menuItem setTarget:self];
            [menuItem setAction:@selector(snapPageFromMenu:)];
            [menuItem setKeyEquivalent:@"R"];
            [menuItem setKeyEquivalentModifierMask:NSCommandKeyMask];
            [fileMenu insertItem:menuItem atIndex:13];
        }
    }
}

//  -------------------------------------------------------------------------


- (id) initWithParameters:(NSMutableDictionary*)_parameters
{
    if (self = [super init]) {
        parameters = loadParameters();
#ifdef DEBUG
        NSLog(@"parameters = %@", parameters);
#endif
    }
    return self;
}

- (id) init
{
    if (self = [super init]) {
    }
    return self;
}

- (void) dealloc
{
    [parameters release];
    [super dealloc];
}

- (NSDictionary*) parameters
{
    return [[parameters retain] autorelease];
}

- (void) alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if (NSAlertDefaultReturn == returnCode) {
        [[
            [NSAppleScript alloc] initWithSource:
                [NSString stringWithFormat:
                    @"tell application \"Safari\"\n"\
                    "  make new document at end of documents\n"\
                    "  set url of document 1 to \"http://www.tastyapps.com/\"\n"\
                    "end tell\n"
                ]
            ]
            executeAndReturnError:nil
        ];
    }
}

static inline BOOL registered()
{
    NSDictionary* parameters = [[RedSnapper sharedInstance] parameters];
    if (parameters) {
        NSString* transactionId = [parameters objectForKey:@"TransactionID"];
        if (transactionId && ([transactionId length] == 17 || [@"Courtesy Copy" isEqualTo:transactionId])) {
            return TRUE;
        }
    }
    return FALSE;
}

#define FOOTER  50

static inline void renderFooter(int width)
{
    NSImage* bg = [[[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[RedSnapper class]] pathForResource:@"wood_bg" ofType:@"jpg"]] autorelease];
    NSRect bgRect = NSMakeRect(0, 0, [bg size].width, [bg size].height);
    for (NSPoint p = NSMakePoint(0, 0); p.x < width; p.x += bgRect.size.width) {
        [bg drawAtPoint:p fromRect:bgRect operation:NSCompositeSourceOver fraction:1.0];
    }

    NSImage* eightDollars = [[[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[RedSnapper class]] pathForResource:@"8dollars" ofType:@"png"]] autorelease];
    [eightDollars setScalesWhenResized:YES];
    [eightDollars setSize:NSMakeSize(40, 40)];
    [eightDollars drawAtPoint:NSMakePoint(5, 5) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];

    [[NSBezierPath bezierPathWithRect:NSMakeRect(0, (registered()?0:FOOTER-1), width, 0)] stroke];

    NSPoint p = NSMakePoint(50, 25);
    NSAttributedString* producedBy = [[[NSAttributedString alloc] 
        initWithString:@"This page captured with Red Snapper (Demo)"
        attributes:[NSDictionary dictionaryWithObjectsAndKeys:
            [NSColor blackColor],
            NSForegroundColorAttributeName,
            [NSFont messageFontOfSize:14.0],
            NSFontAttributeName,
            nil
        ]
    ] autorelease];
    [producedBy drawAtPoint:p];
    p.y -= [producedBy size].height;

    NSAttributedString* info = [[[NSAttributedString alloc] 
        initWithString:@"Available now at http://www.tastyapps.com"
        attributes:[NSDictionary dictionaryWithObjectsAndKeys:
            [NSColor blackColor],
            NSForegroundColorAttributeName,
            [NSFont messageFontOfSize:14.0],
            NSFontAttributeName,
            nil
        ]
    ] autorelease];
    [info drawAtPoint:p];
}

static CGImageRef CGImageFromWebView(WebView* webView)
{
    NSView* view = [[[webView mainFrame] frameView] documentView];
    NSRect frame = [view frame];
    CGImageRef image = NULL;
    NSView* oldSuperview = [webView superview];
    NSRect oldFrame = [webView frame];
    NSWindow* temp = [[[NSWindow alloc] initWithContentRect:[view frame] styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO] autorelease];
    [webView retain];
    [webView removeFromSuperviewWithoutNeedingDisplay];
    [[temp contentView] addSubview:webView];
    [webView setFrame:frame];
    [webView display];
    [view lockFocus];
    NSBitmapImageRep* imageRep = [[[NSBitmapImageRep alloc] initWithFocusedViewRect:frame] autorelease];
    [view unlockFocus];
    [webView removeFromSuperviewWithoutNeedingDisplay];
    [webView setFrame:oldFrame];
    [oldSuperview addSubview:webView];
    [webView release];

    void* buffer = malloc(frame.size.width * ((registered()?0:FOOTER) + frame.size.height) * 4);
    if (buffer) {
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef context = CGBitmapContextCreate(buffer, frame.size.width, (registered()?0:FOOTER) + frame.size.height, 8, frame.size.width * 4, colorSpace, kCGBitmapByteOrder32Host | kCGImageAlphaPremultipliedLast);
        CGColorSpaceRelease(colorSpace);
        NSGraphicsContext* graphicsContext = [NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:NO];
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:graphicsContext];
        [imageRep drawAtPoint:NSMakePoint(0, (registered()?0:FOOTER))];
        if (!registered()) {
            renderFooter(frame.size.width);
        }
        [graphicsContext flushGraphics];
        [NSGraphicsContext restoreGraphicsState];
        image = CGBitmapContextCreateImage(context);
        CGContextRelease(context);
        free(buffer);
    }
    return image;
}

- (NSData*) imageDataForWebView:(WebView*)webView ofType:(NSString*)type ofQuality:(float)quality
{
    NSData* data = nil;
    CGImageRef image = CGImageFromWebView(webView);
    if (image) {
        data = [NSMutableData data];
        NSString* uti = (NSString*)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)type, kUTTypeImage);            
        NSDictionary* imageProps = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:quality] forKey:(id)kCGImageDestinationLossyCompressionQuality];
		CGImageDestinationRef imageDest = CGImageDestinationCreateWithData((void*)data, (CFStringRef)uti, 1, NULL);
        CGImageDestinationAddImage(imageDest, image, (CFDictionaryRef)imageProps);
        CGImageDestinationFinalize(imageDest);
        CFRelease(imageDest);
        CGImageRelease(image);
    }
    return data;
}

- (NSData*) pdfDataForWebView:(WebView*)webView
{
    CGImageRef image = CGImageFromWebView(webView);
    NSData* data = nil;
    if (image) {
        data = [[[NSMutableData alloc] init] autorelease];
        NSView* view = [[[webView mainFrame] frameView] documentView];
        NSRect frame = [view frame];
        frame.size.height += (registered()?0:FOOTER);
        CGDataConsumerRef datacon = CGDataConsumerCreateWithCFData((CFMutableDataRef)data);
        CGContextRef context = CGPDFContextCreate(datacon, (CGRect*)&frame, NULL);
        CGContextBeginPage(context, (CGRect*)&frame);

        /*  Have the view render itself into the PDF context.
         */
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSGraphicsContext* gc = [NSGraphicsContext graphicsContextWithGraphicsPort:(void*)context flipped:NO];
        if (!registered()) {
            frame.size.height -= FOOTER;
            [NSGraphicsContext saveGraphicsState];
            [NSGraphicsContext setCurrentContext:gc];
            renderFooter(frame.size.width);
            CGPDFContextSetURLForRect(context, (CFURLRef)[NSURL URLWithString:@"http://www.tastyapps.com"], CGRectMake(0, 0, frame.size.width, FOOTER)); 
            [NSGraphicsContext restoreGraphicsState];
            CGContextTranslateCTM(context, 0, FOOTER);
        }
        [view displayRectIgnoringOpacity:[view frame] inContext:gc];
        [gc flushGraphics];
        [pool release];

        /*  Render any subviews (plugins) into the PDF context.
         */
        NSArray* subviews = [view subviews];
        for (int i = 0, imax = [subviews count]; i < imax; i++) {
            id subview = [subviews objectAtIndex:i];
            NSRect subviewFrame = [subview frame];
            CGImageRef subviewImage = CGImageCreateWithImageInRect(image, *(CGRect*)&subviewFrame);
            subviewFrame.origin.y = frame.size.height - subviewFrame.origin.y - subviewFrame.size.height;
            if (subviewImage) {
                CGContextDrawImage(context, *(CGRect*)&subviewFrame, subviewImage);
                CGImageRelease(subviewImage);
            }
        }

        /*  Execute JavaScript to pull the links out of the page.
         */
        DOMDocument* document = [[webView mainFrame] DOMDocument];
        if (document) {
            if ([document respondsToSelector:@selector(getElementsByTagNameNS:localName:)]) {
                /* 10.5 */
                DOMNodeList* nodeList = [document getElementsByTagNameNS:@"*" localName:@"a"];
                for (int i = 0, iMax = [nodeList length]; i < iMax; i++) {
                    DOMElement* element = (DOMElement*)[nodeList item:i];
                    NSRect r = [element boundingBox];
                    CGRect cr = CGRectMake(r.origin.x, frame.size.height - r.origin.y - r.size.height + (registered()?0:FOOTER), r.size.width, r.size.height);
                    CGPDFContextSetURLForRect(context, (CFURLRef)[element absoluteLinkURL], cr); 
                }
            } else {
                /* 10.4 */
                
                /*  Grab the margins from the computed CSS values.
                 */
                float xMargin = 0;
                float yMargin = 0;
                if ([document isKindOfClass:[DOMHTMLDocument class]]) {
                    DOMCSSStyleDeclaration *style = [webView computedStyleForElement:[(DOMHTMLDocument*)document body] pseudoElement:nil];
                    if (style) {
                        xMargin = [(DOMCSSPrimitiveValue*)[style getPropertyCSSValue:@"margin-left"] getFloatValue:DOM_CSS_PX];
                        yMargin = [(DOMCSSPrimitiveValue*)[style getPropertyCSSValue:@"margin-top"] getFloatValue:DOM_CSS_PX];
                    }
                }
                
                /*  Use a little bit of JavaScript to extract the links, 
                 *  and their absolute positions on the screen.
                 */
                NSString* result = [webView stringByEvaluatingJavaScriptFromString:
                  @"function __linkExtractor__() {\n"
                   "  var tags = document.getElementsByTagName('a');\n"
                   "  var r = '';\n"
                   "  for (var i = 0; i < tags.length; i++) {\n"
                   "    var tag = tags[i];\n"
                   "    var x = 0;\n"
                   "    var y = 0;\n" 
                   "    var w = tag.clientWidth;\n"
                   "    var h = tag.clientHeight;\n"
                   "    if (w && h) {\n"
                   "      var link = tag.href;\n"
                   "      while (tag) {\n"
                   "        x += tag.offsetLeft;\n"
                   "        y += tag.offsetTop;\n"
                   "        tag = tag.offsetParent;\n"
                   "      }\n"
                   "      r += x +'|'+ y +'|'+ w +'|'+ h +'|'+ link +' ';\n"
                   "    }\n"
                   "  }\n"
                   "  return r.replace(/\\s*$/g,'');\n" 
                   "}\n"
                   "__linkExtractor__();\n"
                ];
                
                /*  Parse the results of the JavaScript snippet, and create
                 *  corresponding PDF links.
                 */
                NSArray* links = [result componentsSeparatedByString:@" "];
                for (int i = 0, iMax = [links count]; i < iMax; i++) {
                    NSArray* link = [[links objectAtIndex:i] componentsSeparatedByString:@"|"]; 
                    CFURLRef url;
                    if ((5 == [link count]) && (url = CFURLCreateWithString(NULL, (CFStringRef)[link objectAtIndex:4], NULL))) {
                        float x = [[link objectAtIndex:0] floatValue];
                        float y = [[link objectAtIndex:1] floatValue];
                        float w = [[link objectAtIndex:2] floatValue];
                        float h = [[link objectAtIndex:3] floatValue];
                        CGRect cr = CGRectMake(xMargin + x, frame.size.height - y - h - yMargin + (registered()?0:FOOTER), w, h);
                        CGPDFContextSetURLForRect(context, url, cr); 
                        CFRelease(url);
                    }
                }
            }
        }
        
        CGContextEndPage(context);
        CGContextRelease(context);
        CGDataConsumerRelease(datacon);
        CGImageRelease(image);
    }
    return data;
}

- (void) savePanelDidEnd:(NSSavePanel*)sheet returnCode:(int)returnCode contextInfo:(WebView*)webView
{
    if (returnCode == NSOKButton) {
        NSString* filename = [sheet filename];
        NSString* type = [[filename pathExtension] lowercaseString];
		float quality = [[sheet delegate] quality]; 
        NSData* data;
        if ([@"pdf" isEqualTo:type]) {
            data = [self pdfDataForWebView:webView];
        } else {
            data = [self imageDataForWebView:webView ofType:type ofQuality:quality];
        }
        [data writeToFile:filename atomically:YES];
    }
}

- (void) alertForCorruption:(NSWindow*)window
{
    NSAlert* alert = [NSAlert alertWithMessageText:RSLocalizedString(@"This Red Snapper is starting to smell funny (and really shouldn't be eaten.)", @"") defaultButton:nil alternateButton:RSLocalizedString(@"No Thanks", "") otherButton:nil informativeTextWithFormat:RSLocalizedString(@"For a much fresher snapper, or instuctions for removing the Red Snapper from Safari, please visit our website at http://tastyapps.com", @"")];
    [alert setIcon:[[[NSImage alloc] initByReferencingFile:[[NSBundle bundleForClass:[RedSnapper class]] pathForResource:@"RedSnapper" ofType:@"icns"]] autorelease]];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void) alertForExpiration:(NSWindow*)window
{
    NSAlert* alert = [NSAlert alertWithMessageText:RSLocalizedString(@"This Red Snapper is past it's expiration date (and really shouldn't be eaten.)", @"") defaultButton:nil alternateButton:RSLocalizedString(@"No Thanks", "") otherButton:nil informativeTextWithFormat:RSLocalizedString(@"For a much fresher snapper, or instuctions for removing the Red Snapper from Safari, please visit our website at http://tastyapps.com", @"")];
    [alert setIcon:[[[NSImage alloc] initByReferencingFile:[[NSBundle bundleForClass:[RedSnapper class]] pathForResource:@"RedSnapper" ofType:@"icns"]] autorelease]];
    [alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void) snapWebViewToClipboardImage:(WebView*)webView
{
    [[[[NSSound alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[RedSnapper class]] pathForResource:@"click" ofType:@"aiff"] byReference:YES] autorelease] play];
    NSPasteboard* pb = [NSPasteboard generalPasteboard];
    [pb declareTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:nil];
    [pb setData:[self imageDataForWebView:webView ofType:@"tiff" ofQuality: 1.0] forType:NSTIFFPboardType];
}

- (void) snapWebViewToClipboardPDF:(WebView*)webView
{
    [[[[NSSound alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[RedSnapper class]] pathForResource:@"click" ofType:@"aiff"] byReference:YES] autorelease] play];
    NSPasteboard* pb = [NSPasteboard generalPasteboard];
    [pb declareTypes:[NSArray arrayWithObject:NSPDFPboardType] owner:nil];
    [pb setData:[self pdfDataForWebView:webView] forType:NSPDFPboardType];
}

- (void) snapWebViewToFile:(WebView*)webView expiresOn:(NSDate*)expiresOn
{
    RSSavePanelController* spc = [[[RSSavePanelController alloc] init] autorelease];
    if (expiresOn) {
        int daysRemaining = [expiresOn timeIntervalSinceNow] / (24 * 60 * 60);
        if (0 == daysRemaining) {
            [spc setFooterText:RSLocalizedString(@"Expires Today!", @"")];
        } else {
            [spc setFooterText:[NSString stringWithFormat:RSLocalizedString(@"Expires in %d days", @""), daysRemaining]];
        }
    } else {
        [spc setFooterText:[NSString stringWithFormat:RSLocalizedString(@"Property of %@", @""), [parameters objectForKey:@"Name"]]];
    }
    
    /*  Normalize the filename by removing bits from the start and end.
     */
    NSString* filename = [[webView window] title];
    NSRange range = [filename rangeOfString:@"://"];
    if (range.location != NSNotFound) {
        filename = [filename substringFromIndex:range.location+3];
    }
    int length = [filename length];
    if (length && [filename characterAtIndex:length - 1] == '/') {
        filename = [filename substringToIndex:length - 1];
    } 

    [[[[NSSound alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[RedSnapper class]] pathForResource:@"click" ofType:@"aiff"] byReference:YES] autorelease] play];
    [[spc savePanel] beginSheetForDirectory:nil file:filename modalForWindow:[webView window] modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:webView];
}

- (void) snapPageFromToolbar:(id)sender
{
    NSWindow* window = [[NSApplication sharedApplication] keyWindow];
    if ([window isKindOfClass:[BrowserWindow class]]) {
        BrowserWindowController* browserWindowController = [window windowController];
        WebView* webView = [browserWindowController currentWebView];
        if (webView) {
            NSDate* expiresOn = nil;
            /*if (!parameters) {
                [self alertForCorruption:window];
            } else if ([parameters objectForKey:@"Expires"] && (!(expiresOn = [NSDate dateWithString:[parameters objectForKey:@"Expires"]]) || (expiresOn == [[NSDate date] earlierDate:expiresOn]))) {
                [self alertForExpiration:window];
            } else*/ if (GetCurrentKeyModifiers() & (1 << optionKeyBit)) {
                [self snapWebViewToClipboardImage:webView];
            } else if (GetCurrentKeyModifiers() & (1 << shiftKeyBit)) {
                [self snapWebViewToClipboardPDF:webView];
            } else {
                [self snapWebViewToFile:webView expiresOn:expiresOn];
            }
        }
    }
}

- (void) snapPageFromMenu:(id)sender
{
    NSWindow* window = [[NSApplication sharedApplication] keyWindow];
    if ([window isKindOfClass:[BrowserWindow class]]) {
        BrowserWindowController* browserWindowController = [window windowController];
        WebView* webView = [browserWindowController currentWebView];
        if (webView) {
            NSDate* expiresOn = nil;
            if (!parameters) {
                [self alertForCorruption:window];
            } else if ([parameters objectForKey:@"Expires"] && (!(expiresOn = [NSDate dateWithString:[parameters objectForKey:@"Expires"]]) || (expiresOn == [[NSDate date] earlierDate:expiresOn]))) {
                [self alertForExpiration:window];
            } else {
                [self snapWebViewToFile:webView expiresOn:expiresOn];
            }
        }
    }
}

@end
