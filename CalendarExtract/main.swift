//
//  main.swift
//  CalendarExtract
//
//  Created by Andrew James on 27/03/2016.
//  Copyright © 2016 Andrew James. All rights reserved.
//

import Foundation
import EventKit

let cli = CommandLine()

let filePath = StringOption(shortFlag: "f", longFlag: "file",
                            helpMessage: "Path to the output file.")
let fileTypeOption = StringOption(shortFlag: "t", longFlag: "type", required: false,
                          helpMessage: "Set file type to either 'ics' or 'text'")
let calendersToSearchOption = StringOption(shortFlag: "c", longFlag: "calendars", required: false,
                            helpMessage: "Which calendars to search for events, seperate with commas (eg. Work,Family)")
let help = BoolOption(shortFlag: "h", longFlag: "help",
                      helpMessage: "Prints a help message.")
let verbosity = CounterOption(shortFlag: "v", longFlag: "verbose",
                              helpMessage: "Print verbose messages. Specify multiple times to increase verbosity.")

cli.addOptions(filePath, fileTypeOption, calendersToSearchOption, help, verbosity)

do {
    try cli.parse()
} catch {
    cli.printUsage(error)
    exit(EX_USAGE)
}

var eventStore : EKEventStore = EKEventStore()
var calendars: [EKCalendar]?
var startDates : [NSDate] = []
var endDates : [NSDate] = []
var calendarsToSearch = ["All"]
var fileType = ""

if (fileTypeOption.wasSet) {
    switch fileTypeOption.value! {
        case "ics":
            fileType = "ics"
        case "text":
            fileType = "text"
        case "json":
            fileType = "json"
        default:
            fileType = "json"
    }
}
if (calendersToSearchOption.wasSet && calendersToSearchOption.value! != "") {
    calendarsToSearch = calendersToSearchOption.value!.componentsSeparatedByString(",")
}


class EventObject {
    var eventid: String = ""
    var allDay: Bool = false
    var startDate: String?
    var endDate: String?
    var title: String?
}

extension NSDate {
    
    func beginningOfDay() -> NSDate {
        let calendar = NSCalendar.currentCalendar()
        let components = calendar.components([.Year, .Month, .Day], fromDate: self)
        return calendar.dateFromComponents(components)!
    }
    
    func endOfDay() -> NSDate {
        let components = NSDateComponents()
        components.day = 1
        var date = NSCalendar.currentCalendar().dateByAddingComponents(components, toDate: self.beginningOfDay(), options: [])!
        date = date.dateByAddingTimeInterval(-1)
        return date
    }
}

func checkCalendarAuthorizationStatus() {
    let status = EKEventStore.authorizationStatusForEntityType(EKEntityType.Event)
    
    switch (status) {
    case EKAuthorizationStatus.NotDetermined:
        print("Requesting authorization to calendars")
        requestAccessToCalendar()
    case EKAuthorizationStatus.Authorized:
        loadCalendars()
    case EKAuthorizationStatus.Restricted, EKAuthorizationStatus.Denied:
        print("Access has been restricted, please authorize this application to continue")
        exit(1);
    }
}

func requestAccessToCalendar() {
    eventStore.requestAccessToEntityType(EKEntityType.Event, completion: {
        (accessGranted: Bool, error: NSError?) in
        
        if accessGranted == true {
            dispatch_async(dispatch_get_main_queue(), {
                loadCalendars()
            })
        } else {
            print("Access has been denied, please authorise this application to continue")
            exit(1);
        }
    })
}

func loadCalendars() {
    calendars = eventStore.calendarsForEntityType(EKEntityType.Event)
    let startOfToday = NSDate().beginningOfDay()
    let endOfToday = NSDate().endOfDay()
    var arrayOfEvents: [EKEvent] = [];
    
    if (calendarsToSearch[0] != "All") {
        for c in calendars! as [EKCalendar] {
            if calendarsToSearch.contains(c.title) {
                let predicate = eventStore.predicateForEventsWithStartDate(startOfToday, endDate: endOfToday, calendars: [c])
                let eV = eventStore.eventsMatchingPredicate(predicate)
                for i in eV {
                    arrayOfEvents.append(i)
                }
            }
        }
    } else {
        let predicate = eventStore.predicateForEventsWithStartDate(startOfToday, endDate: endOfToday, calendars: nil)
        let eV = eventStore.eventsMatchingPredicate(predicate)
        for i in eV {
            arrayOfEvents.append(i)
        }
    }
    
    var outputString = ""
    
    switch fileType {
    case "ics":
        outputString = exportToICSFormat(arrayOfEvents)
    case "text":
        outputString = exportToTextFormat(arrayOfEvents)
    case "json":
        outputString = exportToJSONFormat(arrayOfEvents)
    default:
        outputString = exportToJSONFormat(arrayOfEvents)
    }
    
    if (filePath.value != nil) {
        print("Writing File")
        do {
            try outputString.writeToFile(filePath.value!, atomically: true, encoding: NSUTF8StringEncoding)
        } catch {
            print(error)
        }
        
    } else {
        print(outputString)
    }
}

func exportToJSONFormat(eventsToExport: NSArray) -> String {
    var jsonEvents: [EventObject] = []
    let dateFormatter = NSDateFormatter()
    dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
    dateFormatter.timeZone = NSTimeZone.localTimeZone()
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    for e in eventsToExport {
        let event = EventObject()
        event.eventid = e.eventIdentifier
        event.allDay = e.allDay
        event.startDate = dateFormatter.stringFromDate(e.startDate)
        event.endDate = dateFormatter.stringFromDate(e.endDate)
        event.title = e.title.stringByReplacingOccurrencesOfString("'", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
        jsonEvents.append(event)
    }
    
    let jsonString = JSONSerializer.toJson(jsonEvents)
    return jsonString
}

func exportToTextFormat(eventsToExport: NSArray) -> String {
    var textString = ""
    textString = textString + "-------------"
    for event in eventsToExport as! [EKEvent] {
        textString = textString + "Title  \(event.title)"
        textString = textString + "Start: \(event.startDate)"
        textString = textString + "End: \(event.endDate)"
        textString = textString + "All Day: \(event.allDay)"
        textString = textString + "Calender: \(event.calendar.title)"
        textString = textString + "-------------"
    }
    return textString
}


func exportToICSFormat(eventsToExport: NSArray) -> String {
    var iCalString = ""
    
    //The first line must be "BEGIN:VCALENDAR"
    iCalString = iCalString + "BEGIN:VCALENDAR"
    iCalString = iCalString + "\r\nVERSION:2.0"
    
    
    for event in eventsToExport as! [EKEvent] {
        //Event Start Date
        iCalString = iCalString + "\r\nBEGIN:VEVENT"
        //allDay
        if (event.allDay) {
            let format1 = NSDateFormatter()
            format1.dateFormat = "yyyyMMdd"
            let allDayDate = format1.stringFromDate(event.startDate)
            
            iCalString = iCalString + "\r\nDTSTART;VALUE=DATE:\(allDayDate)"
            
            //get startdate and add 1 day for the end date.
            let addDay = NSDate(timeIntervalSinceNow: +86400)
            let allDayEnd = format1.stringFromDate(addDay)
            
            iCalString = iCalString + "\r\nDTEND;VALUE=DATE:\(allDayEnd)"
            
            
        }
            
        else {
            
            iCalString = iCalString + "\r\nDTSTART;TZID=Australia/Adelaide:"
            
            let format2 = NSDateFormatter()
            format2.dateFormat = "yyyyMMdd'T'HHmmss"
            
            let dateAsString = format2.stringFromDate(event.startDate)
            iCalString = iCalString + dateAsString
            //end date
            
            iCalString = iCalString + "\r\nDTEND;TZID=Australia/Adelaide:"
            
            let dateAsString1 = format2.stringFromDate(event.endDate)
            
            iCalString = iCalString + dateAsString1
        }
        
        iCalString = iCalString + "\r\nDTSTAMP:"    //date the event was created
        
        let format3 = NSDateFormatter()
        format3.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        
        let dateAsString2 = format3.stringFromDate(event.creationDate!)
        iCalString = iCalString + dateAsString2
        
        //lastModifiedDate
        if ((event.lastModifiedDate) != nil) {
            
            iCalString = iCalString + "\r\nLAST-MODIFIED:"
            
            let dateAsString2 = format3.stringFromDate(event.lastModifiedDate!)
            iCalString = iCalString + dateAsString2
            
        }

        iCalString = iCalString + "\r\nUID:\(event.eventIdentifier)"
        
        
        //location
        if ((event.location) != nil) {
            iCalString = iCalString + "\r\nLOCATION:\(event.location)"
        }
        
        //When a calendar component is created, its sequence number is zero
        iCalString = iCalString + "\r\nSEQUENCE:0"
        
        
        //status
        /*if (event.status == 1) {
            iCalString = iCalString + "\r\nSTATUS:CONFIRMED"
        }
        if (event.status == 2) {
            iCalString = iCalString + "\r\nSTATUS:TENTATIVE"
        }
        if (event.status == 3) {
            iCalString = iCalString + "\r\nSTATUS:CANCELLED"
        }*/
        
        
        //Event Title
        iCalString = iCalString + "\r\nSUMMARY:\(event.title)"
        
        //Notes
        if (event.notes != nil) {
            iCalString = iCalString + "\r\nDESCRIPTION:\(event.notes)"
        }
        
        
        
        iCalString = iCalString + "\r\nEND:VEVENT"
        
    }
    
    //The last line must be "END:VCALENDAR"
    iCalString = iCalString + "\r\nEND:VCALENDAR"
    return iCalString
}




checkCalendarAuthorizationStatus();