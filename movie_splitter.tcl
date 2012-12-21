package require Tk
package require Thread
package require platform

toplevel .videoInfo
wm withdraw .videoInfo
wm title .videoInfo "Info"
wm resizable .videoInfo 0 0

puts "Your platform is [platform::generic]"
if 	{[platform::generic] == "linux-x86_64"} {
	set MENCODER "mencoder"
	set VPLAYER "gnome-mplayer"
	set MPLAYER "mplayer"
	set FILE_BROWSER "nautilus"
	wm minsize .videoInfo 186 172
} else {
	set MENCODER_PATH "G:/MPlayer-p4-svn-34401"
	set VPLAYER_PATH "C:/Program\ Files\ (x86)/K-Lite\ Codec\ Pack/Media\ Player\ Classic"
	set MENCODER [file join $MENCODER_PATH "mencoder.exe"]
	set MPLAYER [file join $MENCODER_PATH "mplayer.exe"]
	set VPLAYER [file join $VPLAYER_PATH "mpc-hc.exe"]
	set FILE_BROWSER "explorer"
	wm minsize .videoInfo 240 223
}

set mplayer_t_status "Waiting"
set mplayer_t [thread::create {
	proc playFilm {ID command} {
		eval [subst {thread::send -async $ID {set mplayer_t_status "Playing"}}]
		eval $command
		eval [subst {thread::send -async $ID {set mplayer_t_status "Waiting"}}]
		puts "Thread Exit!"
	}
	thread::wait
}]

proc playFilm {FilmName} {
	set cmd "exec \"$::VPLAYER\" \"$FilmName\""
	eval [subst {thread::send -async $::mplayer_t {playFilm [list [thread::id] $cmd]}}]
}

set video_info_list ""
set video_info_done 0
set vinfo_t [thread::create {
	proc getVideoInfo {ID command} {
		set mplayerIO [open "| $command" r+]
		while {[gets $mplayerIO logMsg] >= 0} {
			flush $mplayerIO
			switch -regexp -matchvar vars $logMsg {
			ID_VIDEO_([A-Z]+)\=(.*) -
			ID_([A-Z]+)\=(.*) {
				#puts "[lindex $vars 1][lindex $vars 2]"
				eval [subst {thread::send -async $ID {lappend video_info_list [lindex $vars 1] [lindex $vars 2]}}]
			}
			}
		}
		puts "Thread Exit!"
		eval [subst {thread::send -async $ID {set video_info_done 1}}]
	}
	thread::wait
}]

proc getVideoInfo {FilmName} {
	set cmd "$::MPLAYER -identify $FilmName -nosound -vc dummy -vo null"
	eval [subst {thread::send -async $::vinfo_t {getVideoInfo [list [thread::id] $cmd]}}]
}

proc setWidth {obj width} {
	$obj configure -width $width
}

proc createLblFme {name parent text} {
	set ::lblfme($name) [::ttk::labelframe $parent.lblfme($name) -text $text]
}

proc createFme {name parent} {
	set ::fme($name) [::ttk::frame $parent.fme($name)]
}

proc createBtn {name parent text width} {
	set ::btn($name) [::ttk::button $parent.btn($name) -text $text]
	if {$width} {setWidth $::btn($name) $width}
}

proc createEnt {name parent width} {
	set ::ent($name) [::ttk::entry $parent.ent($name) -textvariable ::entVar($name)]
	if {$width} {setWidth $::ent($name) $width}
}

proc createLbl {name parent text width} {
	set ::lbl($name) [::ttk::label $parent.lbl($name) -text $text]
	if {$width} {setWidth $::lbl($name) $width}
}

proc createTv {name parent} {
	set ::tv($name) [::ttk::treeview $parent.tv($name) -show tree]
	set ::sv($name) [::ttk::scrollbar $parent.sv($name) \
				-orient vertical -command [list $::tv($name) yview]]
	set ::sh($name) [::ttk::scrollbar $parent.sh($name) \
				-orient horizontal -command [list $::tv($name) xview]]
	$::tv($name) configure -yscrollcommand [list $::sv($name) set]
	$::tv($name) configure -xscrollcommand [list $::sh($name) set]
}

proc createPrgBar {name parent maximum mode} {
	set ::prgBarVar($name) 0
	set ::prgBar($name) [::ttk::progressbar $parent.prgBar($name) \
						-maximum $maximum -mode $mode -variable ::prgBarVar($name)]
}

proc msgBox {title msg icon type} {
	return [tk_messageBox -title $title -message $msg -icon $icon -type $type]
}

proc insertNodeToTree { tree root text } {
	set end [$tree insert $root end -text $text]
	$tree see $end
	$tree selection set $end
	return $end
}

proc mdelay { msec } {
	after [expr {int($msec)}] set ::state run
	vwait ::state
}

wm title . "Splitting Video List Generator"
wm minsize . 480 400
wm protocol . WM_DELETE_WINDOW {
	exit
}
grid columnconfigure . 0 -weight 1
grid rowconfigure . 3 -weight 1

menu .mbar -type menubar
menu .mbar.menuSplitVideo -tearoff 0
.mbar add cascade -label "Tools" -menu .mbar.menuSplitVideo
. configure -menu .mbar

# Label frames initialize and places
set lblfmeText(video)		"Video File"
set lblfmeText(videoInfo)	"Video Information"
set lblfmeText(options)		"Options"
set lblfmeText(clipList)	"Clip List"
foreach s {video videoInfo options clipList} {
	createLblFme $s "" $lblfmeText($s)
	grid $lblfme($s) -sticky news -columnspan 1
}

createLblFme videoInfo .videoInfo $lblfmeText(videoInfo)
grid $lblfme(videoInfo) -sticky news -columnspan 1
wm protocol .videoInfo WM_DELETE_WINDOW {
	wm withdraw .videoInfo
	#puts [wm geometry .videoInfo]
}

#---------------Video File Label Frame Start----------------
createBtn "videoPath" $lblfme(video) "..." 1
createEnt "videoPath" $lblfme(video) 0
grid $ent(videoPath) $btn(videoPath) -sticky news -columnspan 1
grid columnconfigure $lblfme(video) 0 -weight 1

$btn(videoPath) configure -command {
	if {[info exists entVar(videoPath)] && $entVar(videoPath) != ""} {
		set init_dir [file dirname $entVar(videoPath)]
	} else {
		set init_dir ~
	}

	set types {
   		{{} {.avi .AVI}}
   		{{} {.wmv .WMV}}
   		{{} {.mp4 .MP4}}
   		{{} {.mov .MOV}}
   		{{All Files}        *}
	}
	set video_path [tk_getOpenFile -filetypes $types -initialdir $init_dir]
	if {$video_path == ""} {
		msgBox "Warning" "You did not select any files." "warning" "ok"
		return
	}
							
	set ret [videoNamePreprocessing $video_path]
	set entVar(videoPath) $ret
	set entVar(videoSize) "[expr [file size $entVar(videoPath)]/1000000] MB"
	set video_info_list ""
	set video_info_done 0
	getVideoInfo $entVar(videoPath)
	while {!$video_info_done} {
		mdelay 100
	}
	array set video_info_array $video_info_list
	foreach s {FORMAT BITRATE WIDTH HEIGHT LENGTH FPS ASPECT} {
		switch $s {
		BITRATE {set entVar($s) "[expr $video_info_array($s)/1000].[expr $video_info_array($s)%1000] Kbps"}
		LENGTH {set entVar($s) "$video_info_array($s) s"}
		default {set entVar($s) $video_info_array($s)}
		}
	}
	wm deiconify .videoInfo
	
	switch -nocase [file extension $entVar(videoPath)] {
	".mov" {set defaultArgsIdx 3}
	".wmv" {set defaultArgsIdx 2}
	".mp4" -
	".avi" -
	default {set defaultArgsIdx 0}
	}						
	set defaultArgs [lindex $argsList $defaultArgsIdx]
	playFilm $ret
}

proc videoNamePreprocessing {video_name} {
	regsub -all {\s*} $video_name "" tmp
	regsub -all {\[\w*\]} $tmp "" tmp
	puts $tmp

	if {[string compare $video_name $tmp]} {
		if {[string compare [file tail $tmp] [file tail $video_name]]} {
			file rename $video_name [file join [file dirname $video_name] [file tail $tmp]]
		}
		if {[string compare [file dirname $tmp] [file dirname $video_name]]} {
			file rename [file dirname $video_name] [file dirname $tmp]
		}
	}
	
	return $tmp
}
#---------------Video File Label Frame End  ----------------

#---------------Video Information Label Frame Start----------------
set lblText(FORMAT)		"Format"
set lblText(BITRATE)	"Bit Rate"
set lblText(WIDTH)		"Width"
set lblText(HEIGHT)		"HEIGHT"
set lblText(LENGTH)		"Length"
set lblText(FPS)		"FPS"
set lblText(ASPECT)		"Aspect"
set lblText(videoSize)	"Video Size"

set i 0
foreach s {FORMAT BITRATE WIDTH HEIGHT LENGTH FPS ASPECT videoSize} {
	createLbl $s $lblfme(videoInfo) $lblText($s) 10
	createEnt $s $lblfme(videoInfo) 15
	$ent($s) configure -state readonly
	set entVar($s) ""
	grid $lbl($s) $ent($s)
}
#---------------Video Information Label Frame End  ----------------

#---------------Options Label Frame Start----------------
set lblText(arguments)		"mencoder arguments"
set lblText(videoList)		"Video list output"
set lblText(newName)		"New video name"
set argsList [list \
				"-ofps 29.97 -vf harddup -ovc x264 -x264encopts bitrate=1000 -oac mp3lame -lameopts abr:br=128"\
				"-ovc copy -oac mp3lame -lameopts abr:br=128" \
				"-ofps 29.97 -vf harddup -ovc x264 -x264encopts bitrate=2500 -oac mp3lame -lameopts abr:br=128" \
				"-ofps 29.97 -vf harddup -ovc x264 -x264encopts bitrate=3000 -oac pcm"]
set defaultArgs [lindex $argsList 0]
foreach s {newName videoList} {
	createLbl $s $lblfme(options) $lblText($s) 0
	createEnt $s $lblfme(options) 0
	grid $lbl($s) $ent($s) -sticky news -columnspan 1
}
createLbl "arguments" $lblfme(options) $lblText(arguments) 0
set cmb(arguments) [::ttk::combobox $lblfme(options).cmb(arguments) \
						-values $argsList -textvariable defaultArgs]
set entVar(videoList) [clock format [clock seconds] -format "%Y%m%d"]
grid $lbl(arguments) $cmb(arguments) -sticky news -columnspan 1
grid columnconfigure $lblfme(options) 1 -weight 1
#---------------Options Label Frame End  ----------------

#---------------Clip List Label Frame Start----------------
createTv "clipList" $lblfme(clipList)
set tvRoot(clipList) [insertNodeToTree $tv(clipList) {} "No.\tStart\t\tEnd\t\tDur\t\tDiff"]
$tv(clipList) see $tvRoot(clipList)
$tv(clipList) selection set $tvRoot(clipList)
createFme "clipInfo" $lblfme(clipList)
grid $tv(clipList) $sv(clipList) $fme(clipInfo) -sticky news -columnspan 1
#grid $sh(clipList) -sticky news -columnspan 1
grid columnconfigure $lblfme(clipList) 0 -weight 1
grid rowconfigure $lblfme(clipList) 0 -weight 1

foreach s {Start End Duration} {
	createLblFme $s $fme(clipInfo) $s
	createEnt $s $lblfme($s) 10
	pack $lblfme($s) $ent($s)
}

foreach s {Add Clear Generate Reset} {
	createBtn $s $fme(clipInfo) $s 9
	pack $btn($s)
}

$btn(Add) configure -command {
	if {![filmLengthCalculator]} {return}
	generateClipInfo
}
$btn(Clear) configure -command {
	foreach s {Start End Duration} {
		if {[info exists entVar($s)]} {set entVar($s) ""}
	}
	focus $ent(Start)
}
$btn(Generate) configure -command {
	set ret [renameFilmFiles]
	if { $ret == "No film file is specified." ||
		 $ret == "The video file is playing. It cannot be renamed."} {
		msgBox "Error" $ret "error" "ok"
		return
	}

	set clipList [$::tv(clipList) children $::tvRoot(clipList)]
	if {![llength $clipList]} {
		msgBox "Warning" "No clipping information!" "warning" "ok"
		return
	}

	set clipFileName [file join [file dirname $::entVar(videoPath)] \
					 [file rootname $::entVar(videoPath)].clip]
	set fd [open $clipFileName w+]
	puts $fd [file tail $::entVar(videoPath)]
	puts $fd $::defaultArgs
	foreach c $clipList {
		set wrline [$tv(clipList) item $c -text]
		puts $fd "[lindex $wrline 1] [lindex $wrline 2] [lindex $wrline 3] [lindex $wrline 4]"
	}
	close $fd

	set fd [open [file join "~" $::entVar(videoList).list] a+]
	puts $fd $clipFileName
	close $fd

	msgBox "Information" "$clipFileName is generated." "info" "ok"
}
$btn(Reset) configure -command {
	$tv(clipList) delete [$tv(clipList) children $::tvRoot(clipList)]
	$tv(clipList) see $tvRoot(clipList)
	$tv(clipList) selection set $tvRoot(clipList)
	
	foreach s {newName Start End Duration} {
		if {[info exists entVar($s)]} {set entVar($s) ""}
	}
	focus $btn(videoPath)
}

set menu(clipList) [menu $tv(clipList).menu(clipList) -tearoff 0]
$menu(clipList) add command -label "Delete" -command {
	set deleteitems [$tv(clipList) selection]
	$tv(clipList) delete $deleteitems
}
bind $tv(clipList) <Button-3> {tk_popup $menu(clipList) %X %Y}
bind $ent(End) <Key> {
	if {"%K" == "Return"} {
		if {![filmLengthCalculator]} {return}
		generateClipInfo
	}
}

proc checkTimeFormat { str } {
	return [regexp {^(\d\d)([0-5]\d){2}} $str]
}

proc filmLengthCalculator {} {
	if { ![info exist ::entVar(End)] || \
		 ![info exist ::entVar(Start)] || \
		 $::entVar(End) == "" || \
		 $::entVar(Start) == ""} {
		msgBox "Incorrect Position" "No start position and end position specified!" "error" "ok"
		focus $::ent(Start)
		return 0
	}
							
	if { ![checkTimeFormat $::entVar(End)] || \
		 ![checkTimeFormat $::entVar(Start)] } {
		msgBox "Incorrect Position" "Position Format: \[hhmmss\].\nmm and ss should be between 00 and 59, and all characters should be digits." "error" "ok"
		if {![checkTimeFormat $::entVar(Start)]} {
			set ::entVar(Start) ""
			focus $::ent(Start)
		} else {
			set ::entVar(End) ""
			focus $::ent(End)
		}
		return 0
	}

	set base_time [clock scan 000000 -format "%H%M%S" -gmt true]
	set end_time [clock scan $::entVar(End) -format "%H%M%S" -gmt true]
	set start_time [clock scan $::entVar(Start) -format "%H%M%S" -gmt true]
	regexp {(\d*(\.\d+)?)?\ ?[s]?} $::entVar(LENGTH) all var1 var2
	puts $var1
	if {$var1 != "" && [expr $start_time - $base_time] > $var1} {
		msgBox "Illegal Position" "Start position is over the length of the movie." "error" "ok"
		set ::entVar(Start) ""
		focus $::ent(Start)
		return 0
	}
	if {$var1 != "" && [expr $end_time - $base_time] > $var1} {
		msgBox "Illegal Position" "End position is over the length of the movie." "error" "ok"
		set ::entVar(End) ""
		focus $::ent(End)
		return 0
	}
	if {$start_time > $end_time} {
		msgBox "Incorrect Position" "End position should be after start position!" "error" "ok"
		focus $::ent(Start)
		return 0
	}

	set ::entVar(Duration) [clock format [clock add $end_time -$start_time seconds] -format "%T" -gmt true]
	return 1
}

proc generateClipInfo {} {
	set end_time [clock scan $::entVar(End) -format "%H%M%S" -gmt true]
	set start_time [clock scan $::entVar(Start) -format "%H%M%S" -gmt true]
	set end [insertNodeToTree $::tv(clipList) $::tvRoot(clipList) ""]
	set clip [format "%d\t%s\t\t%s\t\t%s\t\t%d" \
						[$::tv(clipList) index $end] \
						[clock format $start_time -format "%T" -gmt true] \
						[clock format $end_time -format "%T" -gmt true] \
						$::entVar(Duration) \
						[clock add $end_time -$start_time seconds]]

	$::tv(clipList) item $end -text $clip
	$::tv(clipList) see $end
	$::tv(clipList) selection set $end
}

proc renameFilmFiles { } {
	if { ![info exist ::entVar(videoPath)] || $::entVar(videoPath) == ""} {
		return "No film file is specified."
	}

	if { ![info exist ::entVar(newName)] || $::entVar(newName) == ""} {
		return "Bypass rename procedure."
	}

	set oldFilmPath [file dirname $::entVar(videoPath)]
	set oldFilmName [file tail $::entVar(videoPath)]
	set newFilmPath [file join [file dirname $oldFilmPath] $::entVar(newName)]
	set newFilmName $::entVar(newName)[file extension $::entVar(videoPath)]

	#rename File
	if {$::mplayer_t_status == "Playing"} {
		return "The video file is playing. It cannot be renamed."
	} else {
		if {[string compare -nocase $oldFilmName $newFilmName]} {
			file rename $::entVar(videoPath) [file join $oldFilmPath $newFilmName]
		}

		#rename Path
		if {[string compare -nocase $oldFilmPath $newFilmPath]} {
			file rename $oldFilmPath $newFilmPath
		}
	}

	set ::entVar(videoPath) [file join $newFilmPath $newFilmName]
	return "The film file is renamed."
}

#---------------Clip List Label Frame End  ----------------

#---------------Split Video Window Start   ----------------
.mbar.menuSplitVideo add command -label "Video Splitter" -command {
	wm withdraw .
	set topVideoSplitter [toplevel .topVideoSplitter]
	wm title $topVideoSplitter "Video Splitter"
	wm geometry $topVideoSplitter 480x400+[expr [expr [winfo rootx .] + [winfo width .]]/4]+[expr [expr [winfo rooty .] + [winfo height .]]/4]
	wm protocol $topVideoSplitter WM_DELETE_WINDOW {
		puts [wm geometry $topVideoSplitter]
		destroy $topVideoSplitter
		wm deiconify .
	}
	grid columnconfigure $topVideoSplitter 0 -weight 1
	grid rowconfigure $topVideoSplitter 1 -weight 1

	#--------------Video List Label Frame Start--------------
	createLblFme "listPath" $topVideoSplitter "Video List"
	createEnt "listPath" $lblfme(listPath) 0
	createBtn "listPath" $lblfme(listPath) "..." 1
	grid $lblfme(listPath) -sticky news
	grid $ent(listPath) $btn(listPath) -sticky news
	grid columnconfigure $lblfme(listPath) 0 -weight 1

	$btn(listPath) configure -command {
		set video_list_types {
	   		{{} {.list}}
	   		{{All Files}        *}
		}
		set entVar(listPath) [tk_getOpenFile -filetypes $video_list_types -initialdir ~]
		if {$entVar(listPath) == ""} {
			msgBox "Warning" "You did not select a film list." "warning" "ok"
			return
		}
	}
	#--------------Video List Label Frame End--------------

	foreach s {splitInfo splitStatus} {
		createFme $s $topVideoSplitter
		grid $fme($s) -sticky news	
	}

	#--------------Split Info Frame Start    --------------
	createTv "splitInfo" $fme(splitInfo)
	grid $tv(splitInfo) $sv(splitInfo) -sticky news
	#grid $sh(splitInfo) -sticky news -columnspan 1
	grid columnconfigure $fme(splitInfo) 0 -weight 1
	grid rowconfigure $fme(splitInfo) 0 -weight 1

	set menu(splitInfo) [menu $tv(splitInfo).menu(splitInfo) -tearoff 0]
	$menu(splitInfo) add command -label "Play" -command {
		set item_text [$tv(splitInfo) item [$tv(splitInfo) selection] -text]
		set film_dir [file dirname [$tv(splitInfo) item [$tv(splitInfo) parent [$tv(splitInfo) selection]] -text]]
		if {[regexp {.*\.avi} $item_text filename] == 1} {
			puts $item_text
			playFilm [file join $film_dir $filename]
			puts [file join $film_dir $filename]
			update
		}
	}
	$menu(splitInfo) add command -label "Delete" -command {
		set deleteitems [$tv(splitInfo) selection]
		$tv(splitInfo) delete $deleteitems
	}
	bind $tv(splitInfo) <Button-3> {tk_popup $menu(splitInfo) %X %Y}
	bind $tv(splitInfo) <Double-Button-1> {
		set film_dir [file dirname [$tv(splitInfo) item [$tv(splitInfo) parent [$tv(splitInfo) selection]] -text]]
		catch {exec $FILE_BROWSER [file nativename $film_dir]} error
	}
	#--------------Split Info Frame End      --------------


	#--------------Split Status Frame Start  --------------
	createEnt "percent" $fme(splitStatus) 4
	createPrgBar "splitStatus" $fme(splitStatus) 100 "determinate"
	createBtn "splitStart" $fme(splitStatus) "Start" 8
	grid $ent(percent) $prgBar(splitStatus) $btn(splitStart) -sticky news
	grid columnconfigure $fme(splitStatus) 1 -weight 1

	$ent(percent) configure -state readonly
	$btn(splitStart) configure -command {
		if { ![info exist entVar(listPath)] || $entVar(listPath) == ""} {
			msgBox "Warning" "You did not select a film list." "warning" "ok"
			return
		}

		$btn(splitStart) configure -state disable -text "Splitting..."
		$::tv(splitInfo) delete [$::tv(splitInfo) children {}]
		set tvRoot(splitInfo) [insertNodeToTree $tv(splitInfo) {} $entVar(listPath)]
		$tv(splitInfo) see $tvRoot(splitInfo)
		$tv(splitInfo) selection set $tvRoot(splitInfo)
	
		set fd [open $entVar(listPath) r]
		while { ![eof $fd] } {
			set filepath [gets $fd]
			if { $filepath != "" } {insertNodeToTree $tv(splitInfo) $tvRoot(splitInfo) $filepath}
		}
		close $fd

		set video_list [$tv(splitInfo) children $tvRoot(splitInfo)]
		foreach f $video_list {
			cd [file dirname [$tv(splitInfo) item $f -text]]
			puts [pwd]
			set fd [open [$tv(splitInfo) item $f -text] r]

			set split_video [gets $fd]
			insertNodeToTree $tv(splitInfo) $f $split_video
			set mencoder_args [gets $fd]
			insertNodeToTree $tv(splitInfo) $f $mencoder_args
			while { ![eof $fd] } {
				set rdline [gets $fd]
				if { $rdline != "" } {processing $f $split_video $rdline $mencoder_args}
			}
			close $fd
		}
		$btn(splitStart) configure -state normal -text "Start"
	}

	proc processing {f film_name line mencoder_args} {
		regsub -all {[:]} [lindex $line 0] "" start_time
		regsub -all {[:]} [lindex $line 1] "" end_time
		set output_name	[format "%s_%s_%s" [file rootname $film_name] $start_time $end_time]
		set ret [insertNodeToTree $::tv(splitInfo) $f "$output_name.avi\tPreparing..."]

		switch -nocase [file extension $film_name] {
		".mov" -
		".wmv" -
		".mp4" -
		".avi" {
			$::tv(splitInfo) item $ret -text "$output_name.avi\tConverting\[mencoder\]..."
			convertByMEncoder $film_name $line $output_name $mencoder_args true
		}
		}

		$::tv(splitInfo) item $ret -text "$output_name.avi\tDone"
	}

	proc splitByFFmpeg {film_name line output_name} {
		set ::prgBarVar(splitStatus) 0
		set ::entVar(percent) "0%"

		set ffmpegCmd "ffmpeg [format "-sameq -ss %s -t %s -i %s %s"\
						[lindex $line 0] \
						[lindex $line 2] \
						$film_name \
						"$output_name[file extension $film_name]"]"
		puts $ffmpegCmd
		mdelay 200

		set ffmpegIO [open "| $ffmpegCmd" r+]
		update
		while {1} {
			gets $ffmpegIO logMsg
			flush $ffmpegIO
			set current_pos 0
			if { [string match {*[time=]*} $logMsg] == 1 } {
				puts test
				scan $logMsg "%s time=%f" useless current_pos
				set ::prgBarVar(splitStatus) [expr {int($current_pos/[lindex $line 3]*100)}]
				set ::entVar(percent) "$::prgBarVar(splitStatus)%"
			}
			puts $logMsg
			mdelay 1
		}
	}

	proc convertByMEncoder {film_name line output_name mencoder_args split_required} {
		set ::prgBarVar(splitStatus) 0
		set ::entVar(percent) "0%"

		if {$split_required == true} {
			append mencoder_args [format " -ss %s -endpos %s" \
									[lindex $line 0] \
									[lindex $line 2]]
		}
		set mencoderCmd "$::MENCODER [format "%s -o \"%s\" \"%s\"" \
										$mencoder_args \
										"$output_name.avi" \
										$film_name]"
		puts $mencoderCmd

		set mencoderIO [open "| $mencoderCmd" r+]
		while {[gets $mencoderIO logMsg] >= 0} {
			flush $mencoderIO
			set current_pos 0
			if { [string match {[Pos:]*} $logMsg] == 1 } {
				scan $logMsg "Pos: %fs" current_pos
				set ::prgBarVar(splitStatus) [expr {int($current_pos/[lindex $line 3]*100)}]
				set ::entVar(percent) "$::prgBarVar(splitStatus)%"
			}
			#puts $logMsg
			mdelay 1
		}
	}
	#--------------Split Status Frame End    --------------
}
