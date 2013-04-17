div() # args: x, y
# returns the integer before $1 / $2 ($(($1/$2)) is not OK for
# negative numbers
{
  REPLY=$(($1 / $2))
  [ "$(($REPLY * $2))" -gt "$1" ] && REPLY=$(($REPLY - 1))
}

days_since_epoch() # args: year, month, day
{
  # returns (in $REPLY) the number of days since 1970/1/1 GMT
  # valid for any date in the limit of your integer size.
  # Expects y/m/d in the Gregorian calendar from 1752/9/14 on,
  # and in the Julian calendar until 1752/9/2. Note that even
  # though there were no days 3 nor 4 nor... 13 in September
  # 1752, if you provide those you will get the date in the
  # Gregorian calendar. days_since_epoch(1752, 9, 13) ==
  # days_since_epoch(1752, 9, 2).

  # "set" is used to avoid clobbering the variable namespace
  # with a temporary variable
  set -- "$((12 * ($1 + ($1 < 0)) + $2 - 3))" "$3"
  div "$1" 12
  set -- "$1" "$REPLY" "$2"
  div "$((367 * $1 + 7))" 12
  set -- "$1" "$2" "$3" "$REPLY"
  div "$2" 4
  set -- "$1" "$2" "$3" "$(($4 - 2 * $2 + $REPLY + $3))"
  if [ "$1" -eq 21030 ] && [ "$3" -lt 3 ] || [ "$1" -lt 21030 ]; then
    REPLY=$(($4 - 719471))
  else
    div "$2" 100
    set -- "$2" "$(($4 - $REPLY))"
    div "$1" 400
    REPLY=$(($2 + $REPLY - 719469))
  fi
}

is_leap_year() # args: year
{
  [ "$(($1 % 4))" -eq 0 ] && {
    [ "$(($1 % 100))" -ne 0 ] || [ "$(($1 % 400))" -eq 0 ] \
      || [ "$1" -le 1752 ]
  }
}

timegm() # args: year, month, day, hour, minute, second
{
  days_since_epoch "$1" "$2" "$3"
  REPLY=$(($6 + 60 * ($5 + 60 * ($4 + 24 * $REPLY))))
}

wide_strftime() # args: format, seconds-since-epoch
{
  # a POSIX shell strftime implementation but with a wider range
  # (provided your shell numbers are 64 bit large). This one
  # assumes a GMT timezone and a POSIX LC_TIME. It should be
  # valid from 292,271,021,077 BCE (Julian Calendar, so, far
  # before the Big Bang) to 292,277,026,596 (Gregorian
  # Calendar).
  # The computed date is in the Gregorian Calendar from
  # 1752-9-14 on and in the Julian Calendar before (the day
  # before is 1752-9-2) just as the POSIX cal(1) utility. This
  # corresponds to the date when Great Britain adopted the
  # Gregorian calendar, that may be different in other
  # countries.
  # Appart from the directives defined by SUSv3, there is also
  # %J which gives the Julian day number (number of days since
  # 4713/1/1 12:00 BCE), useful for google "daterange"s, and GNU
  # strftime extensions %k, %l, %P, %s.
  # Dates before 0001/1/1 (there is no year 0) are noted -<n>.
  # -0001/1/1 is January the 1st 0001 BCE.
  # Note that %C is negative, %y, %g are positive for a negative
  # year. %Y is always %C%y but %C * 100 + %y only for positive
  # years. %G is not always %C%g (for instance on 2199/12/31)
  #
  # Note that one usage of wide_strftime can be:
  #   wide_strftime "" 123456789
  #   echo "Date is $T_c"
  
  T_s=$2
  div "$2" 86400
  T_d=$REPLY
  T_S=$(($2 - $T_d * 86400))
  T_d=$(($T_d + 719468))
  T_J=$(($T_d + 1721120)) # Julian day
  div "$(($T_d + 3))" 7
  T_w=$(($T_d + 3 - $REPLY * 7))
  REPLY="Sunday:0:Monday:1:Tuesday:2:Wednesday:3
         :Thursday:4:Friday:5:Saturday:6"
  T_A=${REPLY%%":$T_w"*}
  T_A=${T_A##*:}
  T_a=${T_A%"${T_A#???}"}
  T_j=60
  if [ "$T_d" -lt 640102 ]; then
    T_d=$(($T_d + 2))
  else
    [ "$T_d" -lt 640211 ] && T_j=$(($T_j - 11))
    div "$((4 * $T_d + 3))" 146097
    T_d=$(($T_d + $REPLY))
    div "$REPLY" 4
    T_d=$(($T_d - $REPLY))
  fi
  div "$((4 * $T_d + 3))" 1461
  T_Y=$REPLY
  div "$(($T_Y * 1461))" 4
  T_d=$(($T_d - $REPLY))
  T_j=$(($T_j + $T_d))
  T_m=$(((5 * $T_d + 2) / 153))
  T_d=$(($T_d - (153 * $T_m + 2) / 5 + 1))
  T_H=$(($T_S / 3600))
  if [ "$T_H" -lt 12 ]; then
    T_p=AM
    T_P=am
    T_J=$(($T_J - 1))
  else
    T_p=PM
    T_P=pm
  fi
  T_I=$((($T_H + 23) % 12 + 1))
  T_S=$(($T_S % 3600))
  T_M=$(($T_S / 60))
  T_S=$(($T_S % 60))
  T_m=$(($T_m + 3))
  if [ "$T_m" -gt 12 ]; then
    T_Y=$(($T_Y + 1))
    T_m=$(($T_m - 12))
    T_j=$(($T_j - 365))
  fi
  [ "$T_m" -gt 2 ] && is_leap_year "$T_Y" && T_j=$(($T_j + 1))
  T_G=$T_Y
  T_U=$((($T_j - 1) / 7))
  T_W=$T_U
  REPLY=$((($T_j - 1) % 7))
  [ "$REPLY" -ge "$T_w" ] && T_U=$(($T_U + 1))
  [ "$REPLY" -ge "$((($T_w + 6) % 7))" ] && T_W=$(($T_W + 1))
  T_V=$T_W
  REPLY=$((($T_j + 7 - $T_w) % 7)) # Jan 1st week day as 0=Mo .. 6=Tu
  [ "$REPLY" -gt 3 ] && T_V=$(($T_V + 1))
  if [ "$T_V" -eq 0 ]; then # REPLY is 1 (Su), 2 (Sa) or 3 (Fr)
    is_leap_year "$(($T_Y - 1))"
    T_V=$((52 + ($REPLY > 1 + $?)))
    T_G=$(($T_G - 1))
  elif [ "$T_m" -eq 12 ] && [ "$(($T_d - ($T_w + 6) % 7))" -gt 28 ]
  then
    T_V=1
    T_G=$(($T_G + 1))
  fi
  [ "$T_Y" -le 0 ] && T_Y=$(($T_Y - 1)) # there is no year 0
  [ "$T_G" -le 0 ] && T_G=$(($T_G - 1)) # there is no year 0
  REPLY="January:1:February:2:March:3:April:4:May:5:June:6:July:7:
         :August:8:September:9:October:10:November:11:December:12:"
  T_B=${REPLY%%":$T_m:"*}
  T_B=${T_B##*:}
  T_b=${T_B%"${T_B#???}"}
  T_h=$T_b
  T_C=${T_Y%??}
  eval "$(printf '
   T_Y=%.4d
   T_G=%.4d
   T_c="%.3s %.3s%3d %.2d:%.2d:%.2d %.4d"
   T_e="%2d"
   T_d=%.2d
   T_I=%.2d
   T_l="%2d"
   T_j=%.3d
   T_m=%.2d
   T_H=%.2d
   T_k="%2d"
   T_M=%.2d
   T_S=%.2d
   T_U=%.2d
   T_V=%.2d
   T_W=%.2d
   T_n="\n"
   T_t="\t"' "$T_Y" "$T_G" "$T_a" "$T_b" "$T_d" "$T_H" "$T_M" "$T_S" \
             "$T_Y" "$T_d" "$T_d" "$T_I" "$T_I" "$T_j" "$T_m" "$T_H" \
             "$T_H" "$T_M" "$T_S" "$T_U" "$T_V" "$T_W"
  )"
  T_C=${T_Y%??}
  T_y=${T_Y#"$T_C"}
  T_g=${T_G#"${T_G%??}"}
  T_D=$T_m/$T_d/$T_y
  T_F=$T_Y-$T_m-$T_d
  T_r="$T_I:$T_M:$T_S $T_p"
  T_R=$T_H:$T_M
  T_T=$T_H:$T_M:$T_S
  T_x=$T_D
  T_X=$T_T
  T_z=+0000
  T_Z=GMT

  if [ -n "$1" ]; then
    eval "
      REPLY=$(printf '%s\n' "$1" | sed '
	 s/["$\\`]/\\&/g;s/,/,c/g;s/%%/,p/g
	 s/%\([A-DF-JMPR-Za-hj-nprstw-z]\)/${T_\1}/g
	 s/,p/%/g;s/,c/,/g;1s/^/"/;$s/$/"/')"
  else
    # optimization if you only want to access the T_* vars
    REPLY=
  fi
}
