set project_file [file normalize [file join [file dirname [info script]] .. .. td_project workpiece_inspection.al]]
open_project $project_file
launch_runs phy_1 -jobs 6
exit
