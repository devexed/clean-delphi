# Clean up a Delphi project's .dproj file
The .dproj file is an XML file with project config options.
Currently (last observed in Delphi XE10) Delphi reorders the xml tags seemingly randomly every time a .dproj file is saved.
This program makes sure the xml tags are in a predictable order so that it can more easily be used in version control systems (specifically file diffs).
