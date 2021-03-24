//
//  AppDelegate.h
//  SeeVS
//
//  Created by William Gustafson on 3/23/21.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate, NSTextFieldDelegate, NSUserNotificationCenterDelegate>


#define kSelectedState @"SelectedState"
#define kSelectedStateAbbreviation @"SelectedStateAbbreviation"
#define kSelectedCities @"SelectedCities"
#define kNumberSet @"0123456789"
#define kEmptyString @""
#define kUseColorForStatus @"UseColorForStatus"

// STATUS ITEM
@property (strong) NSStatusItem *statusItem;
@property (strong) IBOutlet NSMenu *si_menu;


@property (strong) IBOutlet NSArrayController *citiesArrayController;
@property (strong) IBOutlet NSTableView *citiesTable;
@property (strong) IBOutlet NSPopUpButton *stateSelector;
@property (strong) IBOutlet NSProgressIndicator *citiesProgressSpinner;
@property (strong) IBOutlet NSTextField *pollIntervalField;

@property (strong) NSTimer *availabilityTimer;
@property (strong) NSDate *lastAvailabilityCheckDate;
@property (strong) IBOutlet NSWindow *preferencesWindow;

@property (strong) IBOutlet NSMenuItem *appointmentsMenuItem;
@property (strong) IBOutlet NSMenu *appointmentsSubmenu;
@property (strong) IBOutlet NSMenuItem *lastAppointmentCheckMenuItem;
@property (strong) IBOutlet NSButton *useColorForStatusButton;

@end

