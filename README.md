# CalendarExtract
Swift based CLI to extract Calendars on OSX

# Usage
Simply run from the command line, if no arguments are supplied it will return today's events in JSON format for all your calendars in "iCal/Calendar" in stdout

Define the output format with "-t" the options are "text", "json", "ics"

If you wish to filter the calendars, set the argument -c with the name of the calenders to be viewed

The data retrieved can be saved direct to a file using the format selected, using the option "-f"

# Example
## No Arguments, JSON outputted to console for all calendars
  
    user$ ./CalendarExtract 
  
    {"[0]": {"eventid": "D711CFD7-4966-4387-AA24-D16E60F8779E", "allDay": true, "startDate": "2016-03-28T00:00:00+10:30", "endDate": "2016-03-29T00:00:00+10:30", "title": "Oncall Phone"}, "[1]": {"eventid": "F0B054BC-0B2C-4327-A6FE-B2368C45CE94", "allDay": true, "startDate": "2016-03-28T00:00:00+10:30", "endDate": "2016-03-29T00:00:00+10:30", "title": "Easter Monday"}}
  
## Output ICS for "Australian Holidays" calendar to console
    user$ ./CalendarExtract -c "Australian Holidays" -t ics
    
    BEGIN:VCALENDAR
    VERSION:2.0
    BEGIN:VEVENT
    DTSTART;VALUE=DATE:20160328
    DTEND;VALUE=DATE:20160329
    DTSTAMP:20140826T200210Z
    LAST-MODIFIED:20150908T184553Z
    UID:F0B054BC-0B2C-4327-A6FE-B2368C45CE94
    SEQUENCE:0
    SUMMARY:Easter Monday
    END:VEVENT
    END:VCALENDAR
## Output to export.ics with iCal format
    user$ ./CalendarExtract -c "Australian Holidays" -t ics -f export.ics
    
    Writing File
