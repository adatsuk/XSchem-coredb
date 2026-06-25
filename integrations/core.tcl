# CORE in-process integration for Xschem (coretcl.so + CORE API).
# Xschem owns schematic/symbol views: cell.schematic.core, cell.symbol.core

set ::CORE_SCRIPT_DIR [file normalize [file dirname [info script]]]

if {![info exists ::XSCHEM_ROOT]} {
  set ::XSCHEM_ROOT [file normalize [file dirname $::CORE_SCRIPT_DIR]]
}

if {![info exists ::CORE_ROOT]} {
  if {[info exists ::env(COMMONDB_ROOT)] && $::env(COMMONDB_ROOT) ne ""} {
    set ::CORE_ROOT [file normalize $::env(COMMONDB_ROOT)]
  } elseif {[info exists ::env(CORE_ROOT)] && $::env(CORE_ROOT) ne ""} {
    set ::CORE_ROOT [file normalize $::env(CORE_ROOT)]
  } else {
    set ::CORE_ROOT [file normalize [file join $::XSCHEM_ROOT .. CommonDB]]
  }
}

set ::CORE_LIB [file join $::CORE_ROOT designs xschem test.schematic.core]
set ::CORE_PAYLOAD [file join $::CORE_ROOT designs xschem payload]

# sch/sym path -> backing .core file
array set ::core_binding {}

proc core_find_tcl_lib {} {
  set candidates [list \
    [file join $::CORE_SCRIPT_DIR coretcl.so] \
    [file join $::CORE_ROOT build-wsl integrations xschem_tcl coretcl.so] \
    [file join $::CORE_ROOT build integrations xschem_tcl coretcl.so]]
  foreach path $candidates {
    if {[file exists $path]} {
      return $path
    }
  }
  return ""
}

proc core_ensure_loaded {} {
  if {[namespace which -command coreapi_list_cells] ne ""} {
    return
  }
  set lib [core_find_tcl_lib]
  if {$lib eq ""} {
    set build_script [file join $::XSCHEM_ROOT build-core-tcl.sh]
    error "coretcl.so not found. Run: bash $build_script"
  }
  load $lib Core
}

proc core_view_for_sch {schpath} {
  set ext [string tolower [file extension $schpath]]
  if {$ext eq ".sym"} {
    return symbol
  }
  return schematic
}

proc core_ext_for_view {view} {
  if {$view eq "symbol"} {
    return .sym
  }
  return .sch
}

proc core_is_core_path {path} {
  foreach view {schematic symbol} {
    if {[string match -nocase *.$view.core $path]} {
      return 1
    }
  }
  return 0
}

proc core_cell_from_path {path} {
  core_ensure_loaded
  return [lindex [coreapi_parse_core_path $path] 0]
}

proc core_view_from_path {path} {
  core_ensure_loaded
  return [lindex [coreapi_parse_core_path $path] 1]
}

proc core_path_for_cell {cell view {dir ""}} {
  core_ensure_loaded
  set name [coreapi_core_file_name $cell $view]
  if {$dir ne ""} {
    return [file join $dir $name]
  }
  return $name
}

proc core_default_core_path {sch} {
  set cell [file rootname [file tail $sch]]
  set view [core_view_for_sch $sch]
  set dir [file dirname $sch]
  if {[string equal -nocase [file tail $dir] payload]} {
    set dir [file dirname $dir]
  }
  return [core_path_for_cell $cell $view $dir]
}

proc core_save_defaultextension {} {
  set sch [xschem get schname]
  if {$sch ne "" && [string match -nocase *.sym $sch]} {
    return .symbol.core
  }
  return .schematic.core
}

proc core_payload_dir {corepath} {
  return [file join [file dirname $corepath] payload]
}

proc core_list_cells {corepath} {
  core_ensure_loaded
  return [coreapi_list_cells $corepath]
}

proc core_pick_cell {cells {title "Select cell"}} {
  set top .core_pick_cell
  if {[winfo exists $top]} {
    destroy $top
  }
  set ::core_pick_cell_answer ""
  toplevel $top
  wm title $top $title
  wm transient $top [xschem get topwindow]
  label $top.lbl -text "CORE file contains multiple cells:"
  listbox $top.lb -listvariable ::core_pick_cell_list -height 10 -width 40 \
    -exportselection 0 -selectmode browse
  set ::core_pick_cell_list $cells
  $top.lb selection set 0
  frame $top.btns
  button $top.btns.ok -text OK -command {
    set sel [.core_pick_cell.lb curselection]
    if {$sel ne {}} {
      set ::core_pick_cell_answer [lindex $::core_pick_cell_list $sel]
    }
    destroy .core_pick_cell
  }
  button $top.btns.cancel -text Cancel -command {destroy .core_pick_cell}
  pack $top.lbl -padx 8 -pady 4
  pack $top.lb -padx 8 -pady 4 -fill both -expand 1
  pack $top.btns.ok $top.btns.cancel -side left -padx 8 -pady 8
  pack $top.btns
  bind $top.lb <Double-Button-1> "$top.btns.ok invoke"
  tkwait window $top
  return $::core_pick_cell_answer
}

proc core_open {corepath {cell ""}} {
  core_ensure_loaded
  if {![file exists $corepath]} {
    tk_messageBox -icon error -message "CORE file not found:\n$corepath"
    return
  }
  if {![core_is_core_path $corepath]} {
    tk_messageBox -icon error -message "Not an Xschem CORE file.\nExpected .schematic.core or .symbol.core:\n$corepath"
    return
  }
  if {$cell eq ""} {
    set cells [core_list_cells $corepath]
    if {[llength $cells] == 0} {
      tk_messageBox -icon error -message "No cells in:\n$corepath"
      return
    }
    if {[llength $cells] == 1} {
      set cell [lindex $cells 0]
    } else {
      set cell [core_pick_cell $cells "Open CORE: [file tail $corepath]"]
      if {$cell eq ""} {
        return
      }
    }
  }
  set view [core_view_from_path $corepath]
  set ext [core_ext_for_view $view]
  set outdir [core_payload_dir $corepath]
  file mkdir $outdir
  if {[string match *.* $cell]} {
    set sch [file join $outdir [file tail $cell]]
  } else {
    set sch [file join $outdir ${cell}${ext}]
  }
  if {[catch {coreapi_export_cell $corepath $cell $sch} err]} {
    tk_messageBox -icon error -message "Failed to open CORE:\n$err"
    return
  }
  set ::core_binding($sch) $corepath
  xschem load $sch
  core_refresh_window_title
}

# Show .schematic.core / .symbol.core in window and tab titles (not payload/*.sch).
proc core_refresh_window_title {{mod {}}} {
  set sch [xschem get schname]
  if {$sch eq "" || ![info exists ::core_binding($sch)]} {
    return
  }
  set corepath $::core_binding($sch)
  set label [file tail $corepath]
  if {[catch {set win [xschem get top_path]}] || $win eq {}} {
    set win .
  }
  wm title $win "xschem - $label$mod"
  wm iconname $win "xschem - $label$mod"
  if {[info exists ::tabbed_interface] && $::tabbed_interface} {
    set currwin [xschem get current_win_path]
    regsub {\.drw$} $currwin {} tabname
    if {$tabname eq {}} {
      set tabname .x0
    }
    if {[winfo exists .tabs$tabname]} {
      .tabs$tabname configure -text ${label}${mod}
      catch {balloon .tabs$tabname $corepath}
    }
  }
}

proc core_install_title_hooks {} {
  if {[info commands set_tab_names_orig] ne ""} {
    return
  }
  if {[info commands set_tab_names] eq ""} {
    after 200 core_install_title_hooks
    return
  }
  rename set_tab_names set_tab_names_orig
  proc set_tab_names {{mod {}}} {
    set_tab_names_orig $mod
    core_refresh_window_title $mod
  }
}

proc core_write {sch corepath} {
  core_ensure_loaded
  if {![core_is_core_path $corepath]} {
    error "CORE path must be .schematic.core or .symbol.core: $corepath"
  }
  if {[catch {coreapi_import $sch $corepath -lib xschem} err]} {
    error $err
  }
  set ::core_binding($sch) $corepath
}

proc core_file_open {} {
  set initdir $::CORE_ROOT/designs/xschem
  if {![file isdirectory $initdir]} {
    set initdir $::CORE_ROOT
  }
  set f [tk_getOpenFile -initialdir $initdir \
    -title "Open schematic, symbol, or CORE file" \
    -filetypes {
      {{CORE schematic} {.schematic.core}}
      {{CORE symbol} {.symbol.core}}
      {{Xschem schematic} {.sch}}
      {{Xschem symbol} {.sym}}
      {{All files} *}
    }]
  if {$f eq ""} {
    return
  }
  if {[core_is_core_path $f]} {
    core_open $f
  } else {
    xschem load $f
  }
}

proc core_file_save {} {
  set sch [xschem get schname]
  if {$sch eq ""} {
    return
  }
  xschem save
  set sch [xschem get schname]
  if {[info exists ::core_binding($sch)]} {
    if {[catch {core_write $sch $::core_binding($sch)} err]} {
      tk_messageBox -icon error -message "CORE save failed:\n$err"
    }
  }
}

proc core_file_saveas {} {
  set sch [xschem get schname]
  set initdir [file dirname $sch]
  if {$initdir eq "." || $initdir eq ""} {
    set initdir $::CORE_ROOT/designs/xschem
  }
  set f [tk_getSaveFile -initialdir $initdir \
    -title "Save schematic, symbol, or CORE file" \
    -defaultextension [core_save_defaultextension] \
    -filetypes {
      {{CORE schematic} {.schematic.core}}
      {{CORE symbol} {.symbol.core}}
      {{Xschem schematic} {.sch}}
      {{Xschem symbol} {.sym}}
    }]
  if {$f eq ""} {
    return
  }
  if {[core_is_core_path $f]} {
    set cell [core_cell_from_path $f]
    set view [core_view_from_path $f]
    set payload [core_payload_dir $f]
    file mkdir $payload
    set schout [file join $payload ${cell}[core_ext_for_view $view]]
    xschem saveas $schout
    if {[catch {core_write $schout $f} err]} {
      tk_messageBox -icon error -message "CORE save failed:\n$err"
      return
    }
  } else {
    xschem saveas $f
    set newsch [xschem get schname]
    if {$newsch ne "" && [info exists ::core_binding($newsch)]} {
      unset ::core_binding($newsch)
    }
  }
}

proc core_install_file_hooks {} {
  if {[catch {set topwin [xschem get top_path]}]} {
    after 500 core_install_file_hooks
    return
  }
  catch {
    $topwin.menubar.file entryconfigure "Open" -command core_file_open
    $topwin.menubar.file entryconfigure "Save" -command core_file_save
    $topwin.menubar.file entryconfigure "Save as" -command core_file_saveas
  }
  catch {
    bind $topwin <Control-o> {core_file_open ;# %}
    bind $topwin <Control-s> {core_file_save ;# %}
  }
}

proc core_save_current {} {
  core_file_save
  set sch [xschem get schname]
  if {$sch eq ""} {
    return
  }
  if {![info exists ::core_binding($sch)]} {
    set corepath [core_default_core_path $sch]
    file mkdir [file dirname $corepath]
    if {[catch {core_write $sch $corepath} err]} {
      tk_messageBox -icon error -message "CORE save failed:\n$err"
      return
    }
    set ::core_binding($sch) $corepath
  }
}

proc core_open_default {} {
  if {[file exists $::CORE_LIB]} {
    core_open $::CORE_LIB
  } else {
    core_file_open
  }
}

proc core_sync_payload {} {
  core_ensure_loaded
  set corepath $::CORE_LIB
  if {![file exists $corepath]} {
    tk_messageBox -icon error -message "Default CORE file not found:\n$corepath"
    return
  }
  set payload [core_payload_dir $corepath]
  file mkdir $payload
  if {[catch {coreapi_export_all $corepath $payload} err]} {
    tk_messageBox -icon error -message "CORE sync failed:\n$err"
    return
  }
  tk_messageBox -icon info -message "Exported all cells to:\n$payload"
}

proc core_add_menu {} {
  set topwin [xschem get top_path]
  set liblabel [file tail $::CORE_LIB]
  catch {
    $topwin.menubar.file insert 4 cascade -label Core -menu $topwin.menubar.core
    menu $topwin.menubar.core -tearoff 0
    $topwin.menubar.core add command -label "Open..." -command core_file_open
    $topwin.menubar.core add command -label "Save" -command core_file_save
    $topwin.menubar.core add command -label "Save as..." -command core_file_saveas
    $topwin.menubar.core add separator
    $topwin.menubar.core add command -label "Open $liblabel" -command core_open_default
    $topwin.menubar.core add command -label "Save to $liblabel" -command core_save_current
    $topwin.menubar.core add command -label "Sync payload folder" -command core_sync_payload
  }
}

proc core_ensure_window_geometry {} {
  if {[catch {set win [xschem get topwindow]}]} {
    return
  }
  if {$win eq "" || ![winfo exists $win]} {
    return
  }
  if {[catch {set geom [wm geometry $win]}]} {
    return
  }
  if {[regexp {^(\d+)x(\d+)} $geom -> w h]} {
    if {$w < 200 || $h < 200} {
      wm geometry $win 1300x950+80+40
    }
  }
  catch {wm deiconify $win}
  catch {wm state $win normal}
  catch {raise $win}
}

proc core_open_deferred {} {
  if {[info exists ::env(XSCHEM_OPEN_CORE)] && $::env(XSCHEM_OPEN_CORE) ne ""} {
    set path $::env(XSCHEM_OPEN_CORE)
    unset ::env(XSCHEM_OPEN_CORE)
    if {[catch {core_open $path} err]} {
      tk_messageBox -icon error -message "CORE open failed:\n$err"
    }
    return
  }

  if {[info exists ::env(XSCHEM_OPEN_FILE)] && $::env(XSCHEM_OPEN_FILE) ne ""} {
    set path $::env(XSCHEM_OPEN_FILE)
    unset ::env(XSCHEM_OPEN_FILE)
    if {[catch {xschem load $path} err]} {
      tk_messageBox -icon error -message "Failed to open:\n$path\n\n$err"
    }
  }
}

after idle {
  core_install_title_hooks
  core_install_file_hooks
  core_add_menu
  core_open_deferred
  after 150 core_ensure_window_geometry
}
