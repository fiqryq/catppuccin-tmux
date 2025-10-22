#!/usr/bin/env bash
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

get_tmux_option() {
  local option value default
  option="$1"
  default="$2"
  value=$(tmux show-option -gqv "$option")

  if [ -n "$value" ]; then
    if [ "$value" = "null" ]; then
      echo ""
    else
      echo "$value"
    fi
  else
    echo "$default"
  fi
}

set() {
  local option=$1
  local value=$2
  tmux_commands+=(set-option -gq "$option" "$value" ";")
}

setw() {
  local option=$1
  local value=$2
  tmux_commands+=(set-window-option -gq "$option" "$value" ";")
}

build_window_icon() {
  local window_status_icon_enable
  window_status_icon_enable=$(get_tmux_option "@catppuccin_window_status_icon_enable" "yes")

  local custom_icon_window_last
  local custom_icon_window_current
  local custom_icon_window_zoom
  local custom_icon_window_mark
  local custom_icon_window_silent
  local custom_icon_window_activity
  local custom_icon_window_bell

  custom_icon_window_last=$(get_tmux_option "@catppuccin_icon_window_last" "󰖰")
  custom_icon_window_current=$(get_tmux_option "@catppuccin_icon_window_current" "󰖯")
  custom_icon_window_zoom=$(get_tmux_option "@catppuccin_icon_window_zoom" "󰁌")
  custom_icon_window_mark=$(get_tmux_option "@catppuccin_icon_window_mark" "󰃀")
  custom_icon_window_silent=$(get_tmux_option "@catppuccin_icon_window_silent" "󰂛")
  custom_icon_window_activity=$(get_tmux_option "@catppuccin_icon_window_activity" "󰖲")
  custom_icon_window_bell=$(get_tmux_option "@catppuccin_icon_window_bell" "󰂞")

  local show_window_status
  if [ "$window_status_icon_enable" = "yes" ]; then
    # #!~[*-]MZ
    show_window_status="#{?window_activity_flag,${custom_icon_window_activity},}#{?window_bell_flag,${custom_icon_window_bell},}#{?window_silence_flag,${custom_icon_window_silent},}#{?window_active,${custom_icon_window_current},}#{?window_last_flag,${custom_icon_window_last},}#{?window_marked_flag,${custom_icon_window_mark},}#{?window_zoomed_flag,${custom_icon_window_zoom},}"
  else
    show_window_status="#F"
  fi

  echo "$show_window_status"
}

build_window_format() {
  local number=$1
  local color=$2
  local background=$3
  local text=$4
  local fill=$5

  if [ "$window_status_enable" = "yes" ]; then
    local icon
    icon="$(build_window_icon)"
    text="$text $icon"
  fi

  if [ "$fill" = "none" ]; then
    local show_left_separator="#[fg=$thm_gray,bg=$thm_bg,nobold,nounderscore,noitalics]$window_left_separator"
    local show_number="#[fg=$thm_fg,bg=$thm_gray]$number"
    local show_middle_separator="#[fg=$thm_fg,bg=$thm_gray,nobold,nounderscore,noitalics]$window_middle_separator"
    local show_text="#[fg=$thm_fg,bg=$thm_gray]$text"
    local show_right_separator="#[fg=$thm_gray,bg=$thm_bg]$window_right_separator"
  fi

  if [ "$fill" = "all" ]; then
    local show_left_separator="#[fg=$color,bg=$thm_bg,nobold,nounderscore,noitalics]$window_left_separator"
    local show_number="#[fg=$background,bg=$color]$number"
    local show_middle_separator="#[fg=$background,bg=$color,nobold,nounderscore,noitalics]$window_middle_separator"
    local show_text="#[fg=$background,bg=$color]$text"
    local show_right_separator="#[fg=$color,bg=$thm_bg]$window_right_separator"
  fi

  if [ "$fill" = "number" ]; then
    local show_number="#[fg=$background,bg=$color]$number"
    local show_middle_separator="#[fg=$color,bg=$background,nobold,nounderscore,noitalics]$window_middle_separator"
    local show_text="#[fg=$thm_fg,bg=$background]$text"

    local show_left_separator
    local show_right_separator

    if [ "$window_number_position" = "right" ]; then
      show_left_separator="#[fg=$background,bg=$thm_bg,nobold,nounderscore,noitalics]$window_left_separator"
      show_right_separator="#[fg=$color,bg=$thm_bg]$window_right_separator"
    else
      show_right_separator="#[fg=$background,bg=$thm_bg,nobold,nounderscore,noitalics]$window_right_separator"
      show_left_separator="#[fg=$color,bg=$thm_bg]$window_left_separator"
    fi
  fi

  local final_window_format
  if [ "$window_number_position" = "right" ]; then
    final_window_format="$show_left_separator$show_text$show_middle_separator$show_number$show_right_separator"
  else
    final_window_format="$show_left_separator$show_number$show_middle_separator$show_text$show_right_separator"
  fi

  echo "$final_window_format"
}

build_status_module() {
  local index=$1
  local icon=$2
  local color=$3
  local text=$4

  # NOTE: keep the statusline transparent: use bg=$thm_bg (== "default")
  if [ "$status_fill" = "icon" ]; then
    # Colored separators on transparent bg
    local show_left_separator="#[fg=$color,bg=$thm_bg,nobold,nounderscore,noitalics]$status_left_separator"

    # Icon: colored glyph, no solid bg
    # (You can drop bg entirely or keep bg=$thm_bg; both are transparent.)
    local show_icon="#[fg=$color,bg=$thm_bg,nobold,nounderscore,noitalics]$icon "

    # Text on transparent bg
    local show_text="#[fg=$thm_fg,bg=$thm_bg] $text"

    # Right separator colored on transparent bg
    local show_right_separator="#[fg=$color,bg=$thm_bg,nobold,nounderscore,noitalics]$status_right_separator"

    if [ "$status_connect_separator" = "yes" ]; then
      # keep connectors transparent as well
      show_left_separator="#[fg=$color,bg=$thm_bg,nobold,nounderscore,noitalics]$status_left_separator"
      show_right_separator="#[fg=$color,bg=$thm_bg,nobold,nounderscore,noitalics]$status_right_separator"
    fi
  fi

  if [ "$status_fill" = "all" ]; then
    # This mode intentionally fills backgrounds with the accent color.
    # Leave as-is to preserve that behavior.
    local show_left_separator="#[fg=$color,bg=$thm_bg,nobold,nounderscore,noitalics]$status_left_separator"
    local show_icon="#[fg=$thm_bg,bg=$color,nobold,nounderscore,noitalics]$icon "
    local show_text="#[fg=$thm_bg,bg=$color]$text"
    local show_right_separator="#[fg=$color,bg=$thm_bg,nobold,nounderscore,noitalics]$status_right_separator"

    if [ "$status_connect_separator" = "yes" ]; then
      show_left_separator="#[fg=$color,nobold,nounderscore,noitalics]$status_left_separator"
      show_right_separator="#[fg=$color,bg=$color,nobold,nounderscore,noitalics]$status_right_separator"
    fi
  fi

  if [ "$status_right_separator_inverse" = "yes" ]; then
    if [ "$status_connect_separator" = "yes" ]; then
      show_right_separator="#[fg=$thm_bg,bg=$color,nobold,nounderscore,noitalics]$status_right_separator"
    else
      show_right_separator="#[fg=$thm_bg,bg=$color,nobold,nounderscore,noitalics]$status_right_separator"
    fi
  fi

  if [ $(($index)) -eq 0 ]; then
    # First module’s left separator (keep transparent bg)
    show_left_separator="#[fg=$color,bg=$thm_bg,nobold,nounderscore,noitalics]$status_left_separator"
  fi

  echo "$show_left_separator$show_icon$show_text$show_right_separator"
}

load_modules() {
  local modules_list=$1

  local modules_custom_path=$PLUGIN_DIR/custom
  local modules_status_path=$PLUGIN_DIR/status
  local modules_window_path=$PLUGIN_DIR/window

  local module_index=0
  local module_name
  local loaded_modules
  local IN=$modules_list
  local iter=""

  # Split by spaces
  while [ "$IN" != "$iter" ]; do
    iter=${IN%% *}
    IN="${IN#$iter }"

    module_name=$iter

    local module_path=$modules_custom_path/$module_name.sh
    source "$module_path" 2>/dev/null
    if [ 0 -eq $? ]; then
      loaded_modules="$loaded_modules$(show_$module_name $module_index)"
      module_index=$module_index+1
      continue
    fi

    module_path=$modules_status_path/$module_name.sh
    source "$module_path" 2>/dev/null
    if [ 0 -eq $? ]; then
      loaded_modules="$loaded_modules$(show_$module_name $module_index)"
      module_index=$module_index+1
      continue
    fi

    module_path=$modules_window_path/$module_name.sh
    source "$module_path" 2>/dev/null
    if [ 0 -eq $? ]; then
      loaded_modules="$loaded_modules$(show_$module_name $module_index)"
      module_index=$module_index+1
      continue
    fi
  done

  echo "$loaded_modules"
}

main() {
  local theme
  theme="$(get_tmux_option "@catppuccin_flavour" "mocha")"

  # Aggregate all commands in one array
  tmux_commands=()

  # Load tmuxtheme key=val into locals
  while IFS='=' read -r key val; do
    [ "${key##\#*}" ] || continue
    eval "local $key"="$val"
  done <"${PLUGIN_DIR}/catppuccin-${theme}.tmuxtheme"

  # ---------- Status ----------
  set status "on"
  # IMPORTANT: keep status transparent (thm_bg should be "default")
  set status-style "bg=${thm_bg},fg=${thm_fg}"
  set status-justify "left"
  set status-left-length "100"
  set status-right-length "100"

  # ---------- Messages ----------
  # (Message boxes may keep a bg so they’re readable; leave as-is)
  set message-style "fg=${thm_cyan},bg=${thm_gray},align=centre"
  set message-command-style "fg=${thm_cyan},bg=${thm_gray},align=centre"

  # ---------- Panes ----------
  set pane-border-style "fg=${thm_gray}"
  set pane-active-border-style "fg=${thm_blue}"

  # ---------- Windows ----------
  setw window-status-activity-style "fg=${thm_fg},bg=${thm_bg},none"
  setw window-status-separator ""
  setw window-status-style "fg=${thm_fg},bg=${thm_bg},none"

  # ---------- Statusline content ----------
  local window_left_separator
  local window_right_separator
  local window_middle_separator
  local window_number_position
  local window_status_enable

  window_left_separator=$(get_tmux_option "@catppuccin_window_left_separator" "█")
  window_right_separator=$(get_tmux_option "@catppuccin_window_right_separator" "█")
  window_middle_separator=$(get_tmux_option "@catppuccin_window_middle_separator" "█ ")
  window_number_position=$(get_tmux_option "@catppuccin_window_number_position" "left")
  window_status_enable=$(get_tmux_option "@catppuccin_window_status_enable" "no")

  local window_format
  local window_current_format
  window_format=$(load_modules "window_default_format")
  window_current_format=$(load_modules "window_current_format")

  setw window-status-format "$window_format"
  setw window-status-current-format "$window_current_format"

  local status_left_separator
  local status_right_separator
  local status_right_separator_inverse
  local status_connect_separator
  local status_fill
  local status_modules_right
  local status_modules_left
  local loaded_modules_right
  local loaded_modules_left

  status_left_separator=$(get_tmux_option "@catppuccin_status_left_separator" "")
  status_right_separator=$(get_tmux_option "@catppuccin_status_right_separator" " ")
  status_right_separator_inverse=$(get_tmux_option "@catppuccin_status_right_separator_inverse" "no")
  status_connect_separator=$(get_tmux_option "@catppuccin_status_connect_separator" "yes")
  status_fill=$(get_tmux_option "@catppuccin_status_fill" "icon")

  status_modules_right=$(get_tmux_option "@catppuccin_status_modules_right" "application session")
  loaded_modules_right=$(load_modules "$status_modules_right")

  status_modules_left=$(get_tmux_option "@catppuccin_status_modules_left" "")
  loaded_modules_left=$(load_modules "$status_modules_left")

  set status-left "$loaded_modules_left"
  set status-right "$loaded_modules_right"

  # ---------- Modes ----------
  setw clock-mode-colour "${thm_blue}"
  setw mode-style "fg=${thm_pink} bg=${thm_black4} bold"

  tmux "${tmux_commands[@]}"
}

main "$@"
