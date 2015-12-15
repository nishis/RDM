#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <IOKit/graphics/IOGraphicsLib.h>

#import "SRApplicationDelegate.h"
#import "utils.h"
#import "ResMenuItem.h"
#import "cocoa_monitor.h"

@implementation SRApplicationDelegate

- (void) showAbout
{
	NSString* credits_str = @"This program is provided for free and without any warranty or support.  By using this software, you agree to not hold us liable for any loss or damage.";
	NSAttributedString* credits = [[[NSAttributedString alloc] initWithString: credits_str] autorelease];
	NSImage* icon = [NSImage imageNamed: @"Icon_512x512.png"];
	NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
			credits, @"Credits",
			@"Retina DisplayMenu", @"ApplicationName",
			@"Beta", @"Version",
			icon, @"ApplicationIcon",
			@"Retina DisplayMenu v0.2", @"ApplicationVersion",
			@"Copyright 2012, Paul Griffin.\nwww.phoenix-dev.com", @"Copyright",
			nil];

	[NSApp orderFrontStandardAboutPanelWithOptions: options];
}

- (void) quit
{
	[NSApp terminate: self];
}

- (NSString*) screenNameForDisplay:(CGDirectDisplayID) displayID
{
    NSString *screenName = nil;
    io_service_t service = IOServicePortFromCGDisplayID(displayID);
    if (service) {
        NSDictionary *deviceInfo = (NSDictionary *)IODisplayCreateInfoDictionary(service, kIODisplayOnlyPreferredName);
        NSDictionary *localizedNames = [deviceInfo objectForKey:[NSString stringWithUTF8String:kDisplayProductName]];
        if ([localizedNames count] > 0) {
            screenName = [[localizedNames objectForKey:[[localizedNames allKeys] objectAtIndex:0]] retain];
        }
        [deviceInfo release];
    }
    return [screenName autorelease];
}

- (void) refreshStatusMenu
{
	if (statusMenu) {
		[statusMenu release];
	}

	statusMenu = [[NSMenu alloc] initWithTitle: @""];
	uint32_t nDisplays;
	CGDirectDisplayID displays[0x10];
	CGGetOnlineDisplayList(0x10, displays, &nDisplays);

	for (int i = 0; i < nDisplays; i++) {
		CGDirectDisplayID display = displays[i];
		{
			NSMenuItem* item;
			NSString* displayName = [self screenNameForDisplay:display];
			NSString* title = i ? [NSString stringWithFormat: @"%@ (Display %d)", displayName, i+1] : [NSString stringWithFormat: @"%@ (Main Display)", displayName];
			item = [[NSMenuItem alloc] initWithTitle: title action: nil keyEquivalent: @""];
			[item setEnabled: NO];
			[statusMenu addItem: item];
		}

		int mainModeNum;
		CGSGetCurrentDisplayMode(display, &mainModeNum);
		//modes_D4 mainMode;
		//CGSGetDisplayModeDescriptionOfLength(display, mainModeNum, &mainMode, 0xD4);
		ResMenuItem* mainItem = nil;

		int nModes;
		modes_D4* modes;
		CopyAllDisplayModes(display, &modes, &nModes);
		{
			NSMutableArray* displayMenuItems = [NSMutableArray new];
			//ResMenuItem* mainItem = nil;

			for (int j = 0; j < nModes; j++) {
				ResMenuItem* item = [[ResMenuItem alloc] initWithDisplay: display andMode: &modes[j]];
				//[item autorelease];
				if (mainModeNum == j) {
					mainItem = item;
					[item setState: NSOnState];
				}
				[displayMenuItems addObject: item];
				[item release];
			}
			int idealColorDepth = 32;
			double idealRefreshRate = 0.0f;
			if (mainItem) {
				idealColorDepth = [mainItem colorDepth];
				idealRefreshRate = [mainItem refreshRate];
			}
			[displayMenuItems sortUsingSelector: @selector(compareResMenuItem:)];

			NSMenu* submenu = [[NSMenu alloc] initWithTitle: @""];
			ResMenuItem* lastAddedItem = nil;
			for (int j = 0; j < [displayMenuItems count]; j++) {
				ResMenuItem* item = [displayMenuItems objectAtIndex: j];
				if ([item colorDepth] == idealColorDepth) {
					if ([item refreshRate] == idealRefreshRate) {
						[item setTextFormat: 1];
					}

					if (lastAddedItem && [lastAddedItem width] == [item width] &&
							[lastAddedItem height] == [item height] &&
							[lastAddedItem scale] == [item scale]) {
						double lastRefreshRate = lastAddedItem ? [lastAddedItem refreshRate] : 0;
						double refreshRate = [item refreshRate];
						if (!lastAddedItem ||
								(lastRefreshRate != idealRefreshRate &&
									(refreshRate == idealRefreshRate ||
										refreshRate > lastRefreshRate))) {
							if (lastAddedItem) {
								[submenu removeItem: lastAddedItem];
								lastAddedItem = nil;
							}
							[submenu addItem: item];
							lastAddedItem = item;
						}
					} else {
						[submenu addItem: item];
						lastAddedItem = item;
					}
				}
			}

			NSString* title;
			{
				if ([mainItem scale] == 2.0f) {
					title = [NSString stringWithFormat: @"%d × %d ⚡️️", [mainItem width], [mainItem height]];
				} else {
					title = [NSString stringWithFormat: @"%d × %d", [mainItem width], [mainItem height]];
				}
			}

			NSMenuItem* resolution = [[NSMenuItem alloc] initWithTitle: title action: nil keyEquivalent: @""];
			[resolution setSubmenu: submenu];
			[submenu release];
			[statusMenu addItem: resolution];
			[resolution release];

			[displayMenuItems release];
		}

		{
			NSMutableArray* displayMenuItems = [NSMutableArray new];
			ResMenuItem* mainItem = nil;
			for (int j = 0; j < nModes; j++) {
				ResMenuItem* item = [[ResMenuItem alloc] initWithDisplay: display andMode: &modes[j]];
				[item setTextFormat: 2];
				//[item autorelease];
				if (mainModeNum == j) {
					mainItem = item;
					[item setState: NSOnState];
				}
				[displayMenuItems addObject: item];
				[item release];
			}
			int idealColorDepth = 32;
			double idealRefreshRate = 0.0f;
			if (mainItem) {
				idealColorDepth = [mainItem colorDepth];
				idealRefreshRate = [mainItem refreshRate];
			}
			[displayMenuItems sortUsingSelector: @selector(compareResMenuItem:)];

			NSMenu* submenu = [[NSMenu alloc] initWithTitle: @""];
			for(int j = 0; j < [displayMenuItems count]; j++) {
				ResMenuItem* item = [displayMenuItems objectAtIndex: j];
				if ([item colorDepth] == idealColorDepth) {
					if ([mainItem width] == [item width] &&
								[mainItem height] == [item height] &&
								[mainItem scale]==[item scale]) {
						[submenu addItem: item];
					}
				}
			}
			if (idealRefreshRate) {
				NSMenuItem* freq = [[NSMenuItem alloc] initWithTitle: [NSString stringWithFormat: @"%.0f Hz", [mainItem refreshRate]] action: nil keyEquivalent: @""];
				if ([submenu numberOfItems] > 1) {
					[freq setSubmenu: submenu];
				} else {
					[freq setEnabled: NO];
				}
				[statusMenu addItem: freq];
				[freq release];
			}
			[submenu release];
			[displayMenuItems release];
		}
		free(modes);
		[statusMenu addItem: [NSMenuItem separatorItem]];
	}

	[statusMenu addItemWithTitle: @"About RDM" action: @selector(showAbout) keyEquivalent: @""];
	[statusMenu addItemWithTitle: @"Open Displays Preferences..." action: @selector(openDisplayPreferences) keyEquivalent: @""];
	[statusMenu addItem: [NSMenuItem separatorItem]];

	[statusMenu addItemWithTitle: @"Quit" action: @selector(quit) keyEquivalent: @""];
	[statusMenu setDelegate: self];
	[statusItem setMenu: statusMenu];
}

- (void)openDisplayPreferences
{
    [[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/Displays.prefPane"];
}


- (void) setMode: (ResMenuItem*) item
{
	CGDirectDisplayID display = [item display];
	int modeNum = [item modeNum];

	SetDisplayModeNum(display, modeNum);
	/*

	CGDisplayConfigRef config;
    if (CGBeginDisplayConfiguration(&config) == kCGErrorSuccess) {
        CGConfigureDisplayWithDisplayMode(config, display, mode, NULL);
        CGCompleteDisplayConfiguration(config, kCGConfigureForSession);
    }*/
	[self refreshStatusMenu];
}

- (void) applicationDidFinishLaunching: (NSNotification*) notification
{
//	NSLog(@"Finished launching");
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength: NSSquareStatusItemLength] retain];

	NSImage* statusImage = [NSImage imageNamed: @"StatusIcon.png"];
	[statusItem setImage: statusImage];

	NSImage* statusImage_selected = [NSImage imageNamed: @"StatusIcon_sel.png"];
	[statusItem setAlternateImage: statusImage_selected];

	[statusItem setHighlightMode: YES];

	[self refreshStatusMenu];

}

@end
