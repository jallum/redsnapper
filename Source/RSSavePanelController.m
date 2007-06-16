#import "RSSavePanelController.h"
#import "RSSavePanel.h"

@implementation RSSavePanelController

static NSString* FILE_TYPE_KEY = @"com.tastyapps.RedSnapper.fileType";
static NSString* DIRECTORY_KEY = @"com.tastyapps.RedSnapper.directory";

+ (void) initialize
{
    if (self == [RSSavePanelController class]) {
        [self setKeys:[NSArray arrayWithObjects:@"selectedFileType", nil] triggerChangeNotificationsForDependentKey:@"qualityEnabled"];
    }
}

- (id) init
{
    if (self = [super init]) {
        [NSBundle loadNibNamed:@"Save" owner:self];

        /*  Build a list of image types supported by the system.
         */
        NSArray* typeIdentifiers = (NSArray*)CGImageDestinationCopyTypeIdentifiers();
        allowedFileTypes = [NSMutableArray arrayWithCapacity:[typeIdentifiers count]];
        for (int i = 0, iMax = [typeIdentifiers count]; i < iMax; i++) {
            CFStringRef typeIdentifier = (CFStringRef)[typeIdentifiers objectAtIndex:i];
            NSString* fileType = (NSString*)UTTypeCopyPreferredTagWithClass(typeIdentifier, kUTTagClassFilenameExtension);
            if (fileType) {
                [allowedFileTypes addObject:fileType];
            }
        }
		
		/* Build a list of compressible file types
		*/
		compressibleFileTypes = [NSMutableArray arrayWithCapacity:2];
		[compressibleFileTypes addObject:@"jpeg"];
		[compressibleFileTypes addObject:@"jp2"];
		compressibleFileTypes = [compressibleFileTypes retain];
        
        /*  Sort and retain the allowed file types.
         */
        allowedFileTypes = [[allowedFileTypes sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] retain];
        
        /*  Use the allowed file types to generate the popup selections.
         */
        [formatPopup removeAllItems];
        for (int i = 0, iMax = [allowedFileTypes count]; i < iMax; i++) {
            [formatPopup addItemWithTitle:[[allowedFileTypes objectAtIndex:i] uppercaseString]];
        }

        savePanel = [RSSavePanel savePanel];
        [savePanel setCanSelectHiddenExtension:YES];
        [savePanel setCanCreateDirectories:YES];
        [savePanel setAllowedFileTypes:allowedFileTypes];
        [savePanel setAccessoryView:accessoryView];
        [savePanel setDelegate:self];

        NSString* defaultDirectory = [[[NSUserDefaultsController sharedUserDefaultsController] defaults] objectForKey:DIRECTORY_KEY];
        if (defaultDirectory) {
            [savePanel setDirectory:[defaultDirectory stringByStandardizingPath]];
        } else {
            [savePanel setDirectory:[@"~/Documents" stringByStandardizingPath]];
        }
        [savePanel setDelegate:self];


        id defaultFileType = [[[NSUserDefaultsController sharedUserDefaultsController] defaults] objectForKey:FILE_TYPE_KEY];
        if (defaultFileType && [defaultFileType respondsToSelector:@selector(intValue)]) {
            [self setSelectedFileType:[defaultFileType intValue]];
        } else {
            [self setSelectedFileType:4];
        }
        
        [self setQuality:1.0];
    }
    return self;
}

- (void) dealloc
{
    [allowedFileTypes release];
	[compressibleFileTypes release];
    [super dealloc];
}

- (RSSavePanel*) savePanel
{
    return savePanel;
}

- (void) setSelectedFileType:(int)_selectedFileType
{
    if (selectedFileType != _selectedFileType) {
        selectedFileType = _selectedFileType;
        NSString* filename = [savePanel filename];
        [savePanel setRequiredFileType:[allowedFileTypes objectAtIndex:selectedFileType]];
        if (![savePanel isExtensionHidden] && filename) {
            filename = [[[filename lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:[allowedFileTypes objectAtIndex:selectedFileType]];
            [savePanel setFilename:filename];
        }
        [[[NSUserDefaultsController sharedUserDefaultsController] defaults] setObject:[NSNumber numberWithInt:selectedFileType] forKey:FILE_TYPE_KEY];
    }
}

- (int) selectedFileType
{
    return selectedFileType;
}

- (float) quality
{
    return _quality;
}

- (void) setQuality:(float)quality
{
    NSLog(@"setQuality:%g", quality);
    _quality = quality;
}

- (void) panel:(id)sender directoryDidChange:(NSString*)directory
{
    [[[NSUserDefaultsController sharedUserDefaultsController] defaults] setObject:directory forKey:DIRECTORY_KEY];
}

- (void) setFooterText:(NSString*)text
{
    [footer setStringValue:text];
}

- (BOOL) isQualityEnabled
{
	return [compressibleFileTypes containsObject:[allowedFileTypes objectAtIndex:selectedFileType]];
}

@end
