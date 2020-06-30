#!/usr/bin/env bash
########################################## ##########################################################
# forked from : https://github.com/jc00ke/move-to-next-monitor
#
# prerequisites :
#	apt install xdotool wmctrl
#
# Define custom hotkeys in XFCE :
#	XFCE Start Menu | Settings | Keyboard | Application Shortcuts
########################################## ##########################################################
#
# Move the current window to the next monitor.
#
# Also works only on one X screen (which is the most common case).
#
# Props to
# http://icyrock.com/blog/2012/05/xubuntu-moving-windows-between-monitors/
#
# Unfortunately, both "xdotool getwindowgeometry --shell $windowId" and
# checking "-geometry" of "xwininfo -id $windowId" are not sufficient, as
# the first command does not respect panel/decoration offsets and the second
# will sometimes give a "-0-0" geometry. This is why we resort to "xwininfo".

screenWidth=$(xdpyinfo | awk '/dimensions:/ { print $2; exit }' | cut -d'x' -f1)
screenHeight=$(xdpyinfo | awk '/dimensions:/ { print $2; exit }' | cut -d'x' -f2)
displayWidth=$(xdotool getdisplaygeometry | cut -d' ' -f1)
displayHeight=$(xdotool getdisplaygeometry | cut -d' ' -f2)
windowId=$(xdotool getactivewindow)

# Remember if window was maximized.
windowIsMaximized_horizontally=$(xprop -id "$windowId" _NET_WM_STATE | grep '_NET_WM_STATE_MAXIMIZED_HORZ')
windowIsMaximized_vertically=$(xprop -id "$windowId" _NET_WM_STATE | grep '_NET_WM_STATE_MAXIMIZED_VERT')
# For a maximized window :
#	windowIsMaximized_horizontally = '_NET_WM_STATE(ATOM) = _NET_WM_STATE_MAXIMIZED_HORZ, _NET_WM_STATE_MAXIMIZED_VERT, _NET_WM_STATE_FOCUSED'
#	windowIsMaximized_vertically   = '_NET_WM_STATE(ATOM) = _NET_WM_STATE_MAXIMIZED_HORZ, _NET_WM_STATE_MAXIMIZED_VERT, _NET_WM_STATE_FOCUSED'
# Both are empty otherwise

# Un-maximize current window so that we can move it
wmctrl -ir "$windowId" -b remove,maximized_vert,maximized_horz

# Read window position
windowPosition_current_x=$(xwininfo -id "$windowId" | awk '/Absolute upper-left X:/ { print $4 }')
windowPosition_current_y=$(xwininfo -id "$windowId" | awk '/Absolute upper-left Y:/ { print $4 }')

# Subtract any offsets caused by panels or window decorations
offset_x=$(xwininfo -id "$windowId" | awk '/Relative upper-left X:/ { print $4 }')
offset_y=$(xwininfo -id "$windowId" | awk '/Relative upper-left Y:/ { print $4 }')
windowPosition_current_x=$(( windowPosition_current_x - offset_x))
windowPosition_current_y=$(( windowPosition_current_y - offset_y))

# Compute new window position
windowPosition_new_x=$((windowPosition_current_x + displayWidth))
windowPosition_new_y=$((windowPosition_current_y + displayHeight))

# If we would move off the right-most monitor, we set it to the left one.
# We also respect the window's width here: moving a window off more than half its width won't happen.
width=$(xdotool getwindowgeometry "$windowId" | awk '/Geometry:/ { print $2 }' | cut -d'x' -f1)
if [ "$(( windowPosition_new_x + width / 2))" -gt "$screenWidth" ]; then
	windowPosition_new_x=$((windowPosition_new_x - screenWidth))
fi

height=$(xdotool getwindowgeometry "$windowId" | awk '/Geometry:/ { print $2 }' | cut -d'x' -f2)
if [ "$((windowPosition_new_y + height / 2))" -gt "$screenHeight" ]; then
	windowPosition_new_y=$((windowPosition_new_y - screenHeight))
fi

# Don't move off the left side.
[ "$windowPosition_new_x" -lt 0 ] && windowPosition_new_x=0

# Don't move off the bottom
[ "$windowPosition_new_y" -lt 0 ] && windowPosition_new_y=0

# Move the window
xdotool windowmove "$windowId" "$windowPosition_new_x" "$windowPosition_new_y"

# Maximize window again, if it was before
if [ -n "${windowIsMaximized_horizontally}" ] && [ -n "${windowIsMaximized_vertically}" ]; then
	wmctrl -ir "$windowId" -b add,maximized_vert,maximized_horz
elif [ -n "${windowIsMaximized_horizontally}" ]; then
	wmctrl -ir "$windowId" -b add,maximized_horz
elif [ -n "${windowIsMaximized_vertically}" ]; then
	wmctrl -ir "$windowId" -b add,maximized_vert
fi
