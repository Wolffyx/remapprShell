"""The session daemon, one module per job.

Why there is a daemon at all is written at the top of the script that starts
it, bin/windowsd.py.in. This is the rest of it:

  brand          the names an install gives it; the one module rendered
  gio            Gio and GLib, at the version it is written against
  windowlist     the window list: what KWin pushes in, what the shell reads
  icons          the icon a window carries itself, written out as a file
  processes      what Plasma reads about the process behind a window
  desktop_files  the desktop files a window or its process names
  keys           a key as the file spells it, as kglobalaccel's integer
  shortcuts      the global keys, registered and run
  edges          a screen edge, run as one of the same actions
  pointer        where the pointer is, passed on to the shell
  main           the objects on the bus, and the loop
"""
