//
//  YLContextualMenuManager.m
//  Nally
//
//  Created by Yung-Luen Lan on 11/28/07.
//  Copyright 2007 yllan.org. All rights reserved.
//

#import "YLContextualMenuManager.h"

static YLContextualMenuManager *gSharedInstance;

@interface YLContextualMenuManager (Private)
- (NSString *) _extractShortURLFromString: (NSString *)s;
- (NSString *) _extractLongURLFromString: (NSString *)s;
@end

@implementation YLContextualMenuManager (Private)
- (NSString *) _extractShortURLFromString: (NSString *)s 
{
    NSMutableString *result = [NSMutableString string];
    int i;
    for (i = 0; i < [s length]; i++) {
        unichar c = [s characterAtIndex: i];
        if (('0' <= c && c <= '9') || ('a' <= c && c <= 'z') || ('A' <= c && c <= 'Z'))
            [result appendString: [NSString stringWithCharacters: &c length: 1]];
    }
    return result;
}

- (NSString *) _extractLongURLFromString: (NSString *)s 
{
    // If the line is potentially a URL that is too long (contains "\\\r"),
    // try to fix it by removing "\\\r"
    return [[s componentsSeparatedByString: @"\\\r"] componentsJoinedByString: @""];
}
@end

@interface NSString (UJStringUrlCategory)
@end

@implementation NSString (UJStringUrlCategory)
- (BOOL) isUrlLike
{
    NSArray *comps = [self componentsSeparatedByString:@"."];
    int count = 0;
    for (NSString *comp in comps)
    {
        if ([comp length])
            count++;
    }
    return (count > 1);
}
@end


@implementation YLContextualMenuManager

+ (YLContextualMenuManager *) sharedInstance 
{
    return gSharedInstance ?: [[[YLContextualMenuManager alloc] init] autorelease];
}

- (id) init 
{
    if (gSharedInstance) {
        [self release];
    } else if ((gSharedInstance = [[super init] retain])) {
        // ...
    }
    return gSharedInstance;
}

- (NSArray *) availableMenuItemForSelectionString: (NSString *)selectedString
{
    NSMutableArray *items = [NSMutableArray array];
    NSMenuItem *item;
    NSString *shortURL = [self _extractShortURLFromString: selectedString];
    NSString *longURL = [self _extractLongURLFromString: selectedString];
    
    if ([longURL isUrlLike])
    {
        // Split the selected text into blocks seperated by one of the characters in seps
        NSCharacterSet *seps = [NSCharacterSet characterSetWithCharactersInString:@" \r\n"];
        NSArray *blocks = [longURL componentsSeparatedByCharactersInSet:seps];

        // Use out only lines that really are URLs
        NSMutableArray *urls = [NSMutableArray array];
        for (NSString *block in blocks)
        {
            if ([block isUrlLike])
            {
                if (![block hasPrefix:@"http://"])
                    block = [@"http://" stringByAppendingString:block];
                [urls addObject:block];
            }
        }

        // Create menu items
        // If there is only one line, then use the text as title
        // Otherwise use the localized string of "Open mutiple URLs"
        NSString *title;
        if ([urls count] > 1)
            title = NSLocalizedString(@"Open mutiple URLs", @"Open mutiple URLs");
        else if ([urls count] == 1)
            title = [urls objectAtIndex:0];

        if ([urls count])
        {
            if (_urlsToOpen)
                [_urlsToOpen release];
            _urlsToOpen = [urls copy];
            item = [[[NSMenuItem alloc] initWithTitle:title
                                               action:@selector(openURL:)
                                        keyEquivalent:@""] autorelease];
            [item setTarget: self];
            [items addObject: item];
        }
    }
    
    if ([shortURL length] > 0 && [shortURL length] < 8) {
        item = [[[NSMenuItem alloc] initWithTitle: [@"0rz.tw/" stringByAppendingString: shortURL] action: @selector(openURL:) keyEquivalent: @""] autorelease];
        [item setTarget: self];
        [items addObject: item];
    
        item = [[[NSMenuItem alloc] initWithTitle: [@"tinyurl.com/" stringByAppendingString: shortURL] action: @selector(openURL:) keyEquivalent: @""] autorelease];
        [item setTarget: self];
        [items addObject: item];
    }
    
    if ([selectedString length] > 0) {
        item = [[[NSMenuItem alloc] initWithTitle: @"Google" action: @selector(google:) keyEquivalent: @""] autorelease];
        [item setTarget: self];
        [item setRepresentedObject: selectedString];
        [items addObject: item];
        
        item = [[[NSMenuItem alloc] initWithTitle: NSLocalizedString(@"Lookup in Dictionary", @"Menu") action: @selector(lookupDictionary:) keyEquivalent: @""] autorelease];
        [item setTarget: self];
        [item setRepresentedObject: selectedString];
        [items addObject: item];

        item = [[[NSMenuItem alloc] initWithTitle: NSLocalizedString(@"Copy", @"Menu") action: @selector(copy:) keyEquivalent: @""] autorelease];
        [item setTarget: [[NSApp keyWindow] firstResponder]];
        [item setRepresentedObject: selectedString];
        [items addObject: item];
    }
    return items;
}

#pragma mark -
#pragma mark Action

- (IBAction) openURL: (id)sender
{
    NSMutableArray *urls = [NSMutableArray array];
    for (NSString *u in _urlsToOpen)
    {
        if (![u hasPrefix:@"http://"])
            u = [@"http://" stringByAppendingString:u];
        [urls addObject:[NSURL URLWithString:[u stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    }

    [[NSWorkspace sharedWorkspace] openURLs:urls
                    withAppBundleIdentifier:nil
                                    options:NSWorkspaceLaunchDefault
             additionalEventParamDescriptor:nil
                          launchIdentifiers:nil];
    [_urlsToOpen release];
    _urlsToOpen = nil;
}

- (IBAction) google: (id)sender
{
    NSString *u = [sender representedObject];
    u = [@"http://www.google.com/search?q=" stringByAppendingString: [u stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding]];
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: u]];
}

- (IBAction) lookupDictionary: (id)sender
{
    NSString *u = [sender representedObject];
    NSPasteboard *spb = [NSPasteboard pasteboardWithUniqueName];
    [spb declareTypes: [NSArray arrayWithObject: NSStringPboardType] owner: self];
    [spb setString: u forType: NSStringPboardType];
    NSPerformService(@"Look Up in Dictionary", spb);
    
}

@end
