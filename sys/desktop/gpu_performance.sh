#!/usr/bin/env bash
card=/sys/class/drm/card1
echo performance > "$card/device/power_dpm_state"
echo high > "$card/device/power_dpm_force_performance_level"
echo 1 > "$card/device/pp_power_profile_mode"
