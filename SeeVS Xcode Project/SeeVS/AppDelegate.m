//
//  AppDelegate.m
//  SeeVS
//
//  Created by William Gustafson on 3/23/21.
//  shot icon <div>Icons made by <a href="https://icon54.com/" title="Pixel perfect">Pixel perfect</a> from <a href="https://www.flaticon.com/" title="Flaticon">www.flaticon.com</a></div>
//

#import "AppDelegate.h"

@interface AppDelegate ()
@end

@implementation AppDelegate

- (void) applicationDidFinishLaunching: (NSNotification *) aNotification
{
    // CREATE AND CONFIGURE THE STATUS ITEM + MENU
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength: NSVariableStatusItemLength];
    [self.statusItem.button sendActionOn: (NSEventMaskLeftMouseDown|NSEventMaskRightMouseDown)];
    self.statusItem.button.title = @"SeeVS";
    self.statusItem.button.imagePosition = NSImageLeft;
    self.statusItem.menu = self.si_menu;
        
    // CONFIGURE NOTIFCATIONS TO DELIVER WHEN SEEVS IS FRONTMOST
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate: self];
    self.preferencesWindow.level = NSFloatingWindowLevel;
    
    // LOAD COLOR PREFERENCE FOR STATUS
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kUseColorForStatus])
    {
        self.useColorForStatusButton.state = [[[NSUserDefaults standardUserDefaults] objectForKey:kUseColorForStatus] boolValue];
    }
    
    // SET INITIAL VALUES FOR MENU APPOINTMENTS ITEM
    self.appointmentsMenuItem.title = @"Select Cities/State in Preferences";
    self.appointmentsMenuItem.enabled = NO;
    self.lastAppointmentCheckMenuItem.enabled = NO;
    
    // UPDATE THE LIST OF AVAILABLE STATES FROM CVS SITE
    [self updateStateSelector];
    
    // ATTEMPT TO LOAD THE PREVIOUSLY SELECTED STATE INTO THE POPUP BUTTON
    NSString *selectedState = [[NSUserDefaults standardUserDefaults] objectForKey:kSelectedState];

    // IF A STATE HAS BEEN PREVIOUSLY SELECTED,
    // SELECT IT IN PREFS AND LOAD THE CITIES IN THAT STATE TO THE TABLE IN PREFS
    if ((selectedState) && (![selectedState isEqualToString:@""]))
    {
        [self.stateSelector selectItemWithTitle:selectedState];
        [self updateCityTable];
    }
    else
    {
        [self.stateSelector selectItemAtIndex:0];
    }
    
    // ATTEMPT TO GET THE PREVIOUSLY SELECTED/ENBALED CITIES
    NSMutableArray *selectedCitiesArray = [[[NSUserDefaults standardUserDefaults] objectForKey:kSelectedCities] mutableCopy];
    
    // IF CITIES WHERE PREVIOUSLY SELECTED, RE-SELECT/ENABLE THEM
    if (selectedCitiesArray.count)
    {
        for (NSString *city in selectedCitiesArray)
        {
            for (NSMutableDictionary *cityDict in self.citiesArrayController.arrangedObjects)
            {
                if ([[cityDict valueForKey:@"city"] isEqualToString:city])
                {
                    [cityDict setObject:[NSNumber numberWithBool:YES] forKey:@"enabled"];
                }
            }
        }
    }
    
    // SET THE INITIAL VALUE OF THE LAST APPOINTMENT CHECK TO 30 SECONDS AGO
    // THIS WAY THE CHECK CAN FIRE IMMEDIATELY UPON LAUNCH RATHER THAN WAITING UNTIL
    // THE FIRST X MINTUES PASS
    self.lastAvailabilityCheckDate = [[NSDate date] dateByAddingTimeInterval:-30];
    
    // START THE TIMER TO CHECK FOR AVAILABLE APPOINTMENTS
    self.availabilityTimer = [NSTimer scheduledTimerWithTimeInterval: 1.0 target: self selector: @selector(evaluateNeedForAppointmentAvailabilityCheck) userInfo: nil repeats: YES];
    [[NSRunLoop currentRunLoop] addTimer: self.availabilityTimer forMode: NSRunLoopCommonModes];
    [self.availabilityTimer fire];
    
    [self checkNowForAvailableAppointments:self];
}


#pragma mark - CHECK FOR AVAILABLE APPOINTMENTS

// EVALUATE WHETHER IT HAS BEEN LONG ENOUGH TO CHECK FOR AVAILABLE APPOINTMENTS
- (void) evaluateNeedForAppointmentAvailabilityCheck
{
    // IF USER HASE SELECTED SOME CITIES
    if ([self.citiesArrayController.arrangedObjects count])
    {
        // GET THE DESIRED POLL INTERVAL FROM PREFERENCES FIELD
        long pollInterval = self.pollIntervalField.stringValue.integerValue;
        
        // ADJUST THE POLLING INTERVAL IF IT IS TOO LOW
        if (pollInterval < 15) pollInterval = 15;
        
        // MULTIPLY THE POLLING INTERVAL BY 60 TO CONVERT SECONDS INTO MINUTES
        pollInterval = pollInterval * 60;

        // IF THE CURRENT DATE MINUES THE POLLING INTERVAL IS LATER THAN THE LAST CHECK FOR AVAILABLE APPOINTMENTS
        if ([[[NSDate date] dateByAddingTimeInterval:-pollInterval] compare:self.lastAvailabilityCheckDate] == NSOrderedDescending)
        {
            // UPDATE lastAvailabilityCheckDate TO PREVENT IMMEDIATE ADDITIONAL CHECKS
            // RUN THE CHECK FOR AVAILABLE APPOINTMENTS
            self.lastAvailabilityCheckDate = [NSDate date];
                    
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"dd MMM yyyy HH:mm"];
            self.lastAppointmentCheckMenuItem.title = [NSString stringWithFormat:@"Last Appointment Check: %@", [formatter stringFromDate:self.lastAvailabilityCheckDate]];

            [self checkForAppointmentAvailableAppointments];
        }
    }
    else // NO CITIES SELECTED
    {
        self.lastAvailabilityCheckDate = [[NSDate date] dateByAddingTimeInterval:-999999999999];
    }
}

// CHECK FOR AVAILABLE APPOINTMENTS IN THE SELECTED STATE AND CITIES
- (void) checkForAppointmentAvailableAppointments
{
    // GET THE STATE'S CITIES FROM CVS
    NSString *response = NULL;
    
    NSData *pageContents = [NSData dataWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.cvs.com/immunizations/covid-19-vaccine//immunizations/covid-19-vaccine.vaccine-status.%@.json?vaccineinfo", [[[NSUserDefaults standardUserDefaults] objectForKey:kSelectedStateAbbreviation] lowercaseString]]]];

    response = [NSString stringWithUTF8String:[pageContents bytes]];
    
    // REMOVE ALL MENU ITEMS FROM THE APPOINTMENTS SUBMENU
    [self.appointmentsSubmenu removeAllItems];
    
    bool availableAppointments = NO;
    NSMutableArray *availableAppointmentCities = [[NSMutableArray alloc] init];
    
    // FOR EACH CITY THE USER HAS ENABLED/SELECTED,
    // CHECK FOR AVAILABLE APPOINTMENTS IN THAT CITY
    for (NSMutableDictionary *cityDict in self.citiesArrayController.arrangedObjects)
    {
        if ([[cityDict objectForKey:@"enabled"] boolValue] == YES)
        {
            NSString *cityName = [cityDict objectForKey:@"city"];
            NSString *stateAbbr = [[NSUserDefaults standardUserDefaults] objectForKey:kSelectedStateAbbreviation];
            
            if ((cityName) && (stateAbbr) && (![cityName isEqualToString:@""]) && (![stateAbbr isEqualToString:@""]))
            {
                NSString *status = [[[[response componentsSeparatedByString:[NSString stringWithFormat:@"{\"city\":\"%@\",\"state\":\"%@\",\"status\":\"", [cityName uppercaseString], [stateAbbr uppercaseString]]] objectAtIndex:1] componentsSeparatedByString:@"\"}"] objectAtIndex:0];
                
                if (![status isEqualToString:@"Fully Booked"])
                {
                    availableAppointments = YES;
                    [availableAppointmentCities addObject:[cityName capitalizedString]];
                }
            }
        }
    }
    
    // IF AVAILABLE APPOINTMENTS WERE FOUND
    if (availableAppointments)
    {
        // UPDATE THE STATUS ITEM ICON TO REFLECT APPOINTMENT AVAILABLITY IN SELECTED CITIES
        if (self.useColorForStatusButton.state)
        {
            self.statusItem.button.image = [self scaleImageWithHeight: [NSImage imageNamed:@"NSStatusAvailable"] newHeight: 16];
        }
        else
        {
            self.statusItem.button.image = [self scaleImageWithHeight: [NSImage imageNamed:@"NSMenuOnStateTemplate"] newHeight: 12];
        }
        
        // UPDATE APPOINTMENTS MENU ITEM
        self.appointmentsMenuItem.title = @"Available Appointments";
        self.appointmentsMenuItem.enabled = YES;
        
        // ADD EACH CITY WHERE APPOINTMENTS ARE AVAILABLE TO THE APPOINTMENTS SUBMENU
        for (NSString *city in availableAppointmentCities)
        {
            [self.appointmentsSubmenu insertItemWithTitle:city action:@selector(openCVSAppointmentBookingSite) keyEquivalent:@"" atIndex:self.appointmentsSubmenu.itemArray.count];
        }
        
        // NOTIFY USER
        [self sendNotification: @"Appointments Available!" : @"Open SeeVS's menu to book"];
    }
    else // NO APPOINTMENTS AVAILABLE IN SELECTED CITIES
    {
        // UPDATE THE STATUS ITEM ICON TO REFLECT NO APPOINTMENT AVAILABLITY IN SELECTED CITIES
        if (self.useColorForStatusButton.state)
        {
            self.statusItem.button.image = [self scaleImageWithHeight: [NSImage imageNamed:@"NSStatusUnavailable"] newHeight: 16];
        }
        else
        {
            self.statusItem.button.image = [self scaleImageWithHeight: [NSImage imageNamed:@"NSStopProgressTemplate"] newHeight: 12];
        }
        
        // UPDATE APPOINTMENTS MENU ITEM
        self.appointmentsMenuItem.title = @"All Appointments Are Fully Booked";
        self.appointmentsMenuItem.enabled = NO;
    }

    // IF COLOR IS NOT USED FOR THE STATUS IMAGE, SET THE IMAGE TEMPLATE PROPERTY TO YES
    if (!self.useColorForStatusButton.state)
    {
        self.statusItem.button.image.template = YES;
    }
}

// MANUAL CHECK RUN OUSIDE OF INTERVAL SET IN PREFERENCES
// CALLED BY CHECK FOR APPOINTMENTS MENU ITEM
- (IBAction) checkNowForAvailableAppointments: (id) sender
{
    // IF USER HAS SELECTED SOME CITIES
    if ([self.citiesArrayController.arrangedObjects count])
    {
        // SET THE LAST CHECK DATE TO A DATE IN THE PAST SO THE NEXT
        // RUN OF THE TIMER WILL ALLOW CHECKING FOR AVAILABLE APPOINTMENTS
        self.lastAvailabilityCheckDate = [[NSDate date] dateByAddingTimeInterval:-999999999999];
    }
    else // NO CITIES SELECTED
    {
        [self sendNotification: @"Could not check for appointments" : @"No cities or state selected in Preferences"];
    }
}


#pragma mark - UPDATE CITY AND STATE SELECTION UI ELEMENTS IN PREFERENCES

- (void) updateStateSelector
{
    // REMOVE ALL STATES FROM THE BUTTON
    [self.stateSelector removeAllItems];
    
    // GET THE AVAILABLE STATES FROM THE CVS SITE
    for (NSString *state in [self getAvailableStatesFromCVS])
    {
        if ([state rangeOfString:@"data-analytics-name"].location != NSNotFound)
        {
            NSArray *stateNameData = [state componentsSeparatedByString:@"data-analytics-name=\""];
            NSString *stateName = [[[stateNameData objectAtIndex:1] componentsSeparatedByString:@"\""] objectAtIndex:0];
        
            if ((![stateName isEqualToString:@"Home"])  &&
                (([stateName rangeOfString:@"Access"].location == NSNotFound)))
            {
                // ADD THE STATE TO THE BUTTON IN PREFS
                [self.stateSelector insertItemWithTitle:stateName atIndex:self.stateSelector.itemArray.count];
            }
        }
    }
    
    // ADD AN ITEM TO LET THE USER KNOW THEY NEED TO MAKE A SELECTION
    [self.stateSelector insertItemWithTitle:@"Select a state..." atIndex:0];
}

// CALLED BY STATE SELECTOR POPUP BUTTON
- (IBAction) stateSelected: (id) sender
{
    [self.citiesProgressSpinner startAnimation:self];
    self.citiesProgressSpinner.hidden = NO;
    
    self.citiesArrayController.content = nil;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSelectedCities];
    [self performSelector:@selector(updateStateAndCities:) withObject:sender afterDelay:0.5];
}

- (void) updateStateAndCities: (id) sender
{
    // ALABAMA IS SPECIAL BECAUSE IT IS FIRST ALPHABETACALLY
    // THIS IS EASIER THAN WRITING NEW CODE TO PARSE
    if ([[sender title] isEqualToString:@"Alabama"])
    {
        NSLog(@"Saving \"AL\" for state abbreviation");
        [[NSUserDefaults standardUserDefaults] setValue:@"AL" forKey:kSelectedStateAbbreviation];
        [[NSUserDefaults standardUserDefaults] setValue:self.stateSelector.titleOfSelectedItem forKey:kSelectedState];
    }
    else if (![[sender title] isEqualToString:@"Select a state..."])
    {
        //NSLog(@"Saving \"%@\" for state abbreviation", [self getAbbreviationForState:[sender title]]);
        [[NSUserDefaults standardUserDefaults] setValue:[self getAbbreviationForState:[sender title]] forKey:kSelectedStateAbbreviation];
        [[NSUserDefaults standardUserDefaults] setValue:self.stateSelector.titleOfSelectedItem forKey:kSelectedState];
    }
    else // USER SELECTED A STATE OTHER THAN ALABAMA
    {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSelectedStateAbbreviation];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSelectedState];
    }
    
    if (![[sender title] isEqualToString:@"Select a state..."])
    {
        [self updateCityTable];
    }
    
    [self.citiesProgressSpinner stopAnimation:self];
    self.citiesProgressSpinner.hidden = YES;
}

- (IBAction) citySelected: (id) sender
{
    // GET PREVIOUSLY SELECTED CITIES
    NSMutableArray *selectedCitiesArray = [[[NSUserDefaults standardUserDefaults] objectForKey:kSelectedCities] mutableCopy];
  
    // GET THE CITY THAT USER JUST NOW SELECTED
    NSInteger selectedRow = [self.citiesTable rowForView:sender];
    NSMutableDictionary *cityDict = [self.citiesArrayController.arrangedObjects objectAtIndex: selectedRow];
    
    // IF THER USER HAS ALREADY SELECTED SOME CITIES
    if (selectedCitiesArray.count)
    {
        // ENABLE OR DISABLE THE CITY THE USER JUST SELECTED
        if ([[cityDict objectForKey:@"enabled"] boolValue] == YES)
        {
            [selectedCitiesArray addObject:[cityDict objectForKey:@"city"]];
        }
        else
        {
            [selectedCitiesArray removeObject:[cityDict objectForKey:@"city"]];
        }
    }
    else // ENABLE THIS CITY
    {
        if ([[cityDict objectForKey:@"enabled"] boolValue] == YES)
        {
            selectedCitiesArray = [[NSMutableArray alloc] init];
            [selectedCitiesArray addObject:[cityDict objectForKey:@"city"]];
        }
    }
    
    // SAVE CITY SELECTIONS TO USER DEFAULTS
    [[NSUserDefaults standardUserDefaults] setObject:selectedCitiesArray forKey:kSelectedCities];
}


#pragma mark - WEB CALLS TO GET DATA FROM CVS AND OTHER SITES

- (void) updateCityTable
{
    // CLEAR THE ARRAY CONTROLLER
    self.citiesArrayController.content = nil;
    
    // GET THE STATE'S CITIES FROM CVS
    NSString *response = NULL;
    NSData *pageContents = [NSData dataWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://www.cvs.com/immunizations/covid-19-vaccine//immunizations/covid-19-vaccine.vaccine-status.%@.json?vaccineinfo", [[[NSUserDefaults standardUserDefaults] objectForKey:kSelectedStateAbbreviation] lowercaseString]]]];
    
    response = [NSString stringWithUTF8String:[pageContents bytes]];
        
    // FOR EVERY CITY THAT CVS OFFERS APPOINTMENTS IN
    for (NSString *city in [response componentsSeparatedByString:@"city\":\""])
    {
        NSString *cityName = [[city componentsSeparatedByString:@"\","] objectAtIndex:0];
        
        if ([cityName rangeOfString:@"responsePayloadData"].location == NSNotFound)
        {
            
            NSMutableDictionary *cityDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                             [cityName capitalizedString], @"city",
                                             [NSNumber numberWithBool:NO], @"enabled",
                                             nil];
            
            [self.citiesArrayController addObject:cityDict];
        }
    }
}

// CALL TO CVS SITE TO GET STATES WHERE APPOINTMENTS ARE AVAILABLE
- (NSArray *) getAvailableStatesFromCVS
{
    NSString *response = NULL;
    NSData *pageContents = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"https://www.cvs.com/immunizations/covid-19-vaccine"]];
    response = [NSString stringWithUTF8String:[pageContents bytes]];
    
    return [response componentsSeparatedByString:@"vaccineinfo-"];
}

// GET THE ABBREVIATION FOR A STATE THAT CVS OFFERS APPOINTMENTS IN
- (NSString *) getAbbreviationForState: (NSString *) state
{
    NSString *stateAbbreviation = @"";
    
    @try
    {
        NSString *responseAbbr = NULL;
        NSData *pageContentsAbbr = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"https://www.ssa.gov/international/coc-docs/states.html"]];
        responseAbbr = [NSString stringWithUTF8String:[pageContentsAbbr bytes]];

        stateAbbreviation = [[[[[[responseAbbr componentsSeparatedByString:[NSString stringWithFormat:@"<td class=\"grayruled-td\"  > %@</td>", [state uppercaseString]]] objectAtIndex:1] componentsSeparatedByString:@"</td>"] objectAtIndex:0] componentsSeparatedByString:@"<td class=\"grayruled-td\"  > "] objectAtIndex:1];
    }
    @catch (NSException *exception)
    {
    }
    @finally
    {
    }

    return stateAbbreviation;
}


#pragma mark - IMAGE RESIZING

- (NSImage *) scaleImageWithHeight: (NSImage*) anImage newHeight: (float) newHeight
{
    float aspectRatio = anImage.size.width/anImage.size.height;
    float newWidth = newHeight * aspectRatio;
    
    return [self imageResize: anImage newSize: NSMakeSize(newWidth, newHeight)];
}

- (NSImage *) imageResize: (NSImage*) anImage newSize: (NSSize) newSize
{
    NSImage *sourceImage = anImage;
    
    // Report an error if the source isn't a valid image
    if (![sourceImage isValid])
    {
        NSLog(@"Invalid Image");
    }
    else
    {
        NSImage *smallImage = [[NSImage alloc] initWithSize:  newSize];
        [smallImage lockFocus];
        [sourceImage setSize:  newSize];
        [[NSGraphicsContext currentContext] setImageInterpolation: NSImageInterpolationHigh];
        [sourceImage drawAtPoint: NSZeroPoint fromRect: CGRectMake(0, 0, newSize.width, newSize.height) operation: NSCompositeCopy fraction: 1.0];
        [smallImage unlockFocus];
        
        return smallImage;
    }
    
    return nil;
}


#pragma mark - NOTIFICATIONS

- (void) sendNotification: (NSString *) title : (NSString *) message
{
    NSUserNotification *aNotification = [[NSUserNotification alloc] init];
    
    // DELIVER THE NOTIFICATION
    aNotification.title = title;
    aNotification.informativeText = message;
    aNotification.soundName = NSUserNotificationDefaultSoundName;
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification: aNotification];
}


#pragma mark - PREFERENCES

- (IBAction) openPreferencesWindow: (id) sender
{
    [self.preferencesWindow center];
    [self.preferencesWindow makeKeyAndOrderFront:self];
}

- (IBAction) savePreferences: (id) sender
{
    [[NSUserDefaults standardUserDefaults] setBool:self.useColorForStatusButton.state forKey:kUseColorForStatus];
    
    if (sender == self.useColorForStatusButton)
    {
        [self checkNowForAvailableAppointments:self];
    }
}


#pragma mark - OPEN URLS

- (IBAction) openDeveloperTwitterLink: (id) sender
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: @"https://twitter.com/x74353"]];
}

- (void) openCVSAppointmentBookingSite
{
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: @"https://www.cvs.com/immunizations/covid-19-vaccine"]];
}


#pragma mark - DELEGATE METHODS

- (BOOL) userNotificationCenter: (NSUserNotificationCenter *) center shouldPresentNotification: (NSUserNotification *) notification
{
    return YES;
}

- (void) controlTextDidChange: (NSNotification *) aNotification
{
    // set up char set to check for illegal chars in text fields
    NSCharacterSet *numberSet = [NSCharacterSet characterSetWithCharactersInString: kNumberSet];
    numberSet = [numberSet invertedSet]; // INVERT THE CHARS SET TO INCLUDE ALL UNACCEPTABLE CHARS
    
    // user has entered illegal chars
    NSRange currentTextFieldRange = [[[aNotification object] stringValue] rangeOfCharacterFromSet: numberSet];
    
    if ((currentTextFieldRange.location != NSNotFound) && (![[[aNotification object] stringValue] isEqualToString: kEmptyString]))
    {
        NSBeep();
        [[aNotification object] setStringValue: kEmptyString];
    }
}

- (void) tableViewSelectionDidChange: (NSNotification *) notification
{
    [self.citiesTable deselectAll:self];
}

- (void) applicationWillTerminate: (NSNotification *) aNotification
{
    // GOODBYE, FRIEND
}

@end
