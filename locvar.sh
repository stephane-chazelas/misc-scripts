#
# Copyright 2008 Stephane Chazelas <stephane_chazelas@yahoo.fr>
#
# Feel free to use that code.
#
PS4='$_l_fstack> '
# functions that are meant to have a local scope (that use "locvar") should be
# declared as:
# sub funcname; _funcname() { ...
# When called as "funcname", it gets its own name space for variables,
# when called as "_funcname", it uses the one of its caller.
sub() { eval "$1() { call _$1 \"\$@\"; }"; } 2> /dev/null

# locvar, call, sub and locopt implement a local name space for variables
# and shell options. Variables whose name starts with _l_ are reserved
# for those.
locvar() {
  for _l_var do
    # push previous variable value onto a stack if not there already
    # if the variable is not set, store as an empty value in _l${_l}_$_l_var.
    # otherwise, prepend its value with "+"
    eval "[ -z \"\${_l${_l}_$_l_var++}\" ] &&
      _l$_l=\"\${_l$_l} \$_l_var\" &&
      _l${_l}_$_l_var=\${$_l_var++\$$_l_var}"
  done
} 2> /dev/null

set_last_exit_status() {
  return "$1"
} 2> /dev/null

call() {
  # implements a call stack and variable stack.
  # _l                is the numerical depth of the stack
  # _l_fname          is the current function name
  # _l_fstack         is the call stack
  # _l$_l             is the list of variables pushed onto stack $_l
  # _l${_l}_<varname> is variable varname pushed onto stack $l
  # _l_option_restore is the list of pushed options.
  #
  # sets up the current stack at the calling level for "locvar" and "locopt"
  # to use, calls the function passed as argument, and then restores the
  # stack before returning.

  {
    _l_ret=$?

    _l=$((${_l:-0} + 1))
    unset "_l$_l"

    locvar _l_fname _l_fstack _l_option_restore
    _l_fname="${1#_}"
    _l_fstack="$_l_fstack+$_l_fname"
    _l_option_restore=

    case $1 in
      (_*) eval "[ -n \"\${_lx$1}\" ] &&
	  locopt -x"
    esac
    set_last_exit_status "$_l_ret"
  } 2> /dev/null

  "$@"

  {
    _l_ret=$?

    # restore options
    [ -z "$_l_option_restore" ] ||
      eval "set $_l_option_restore"

    # restore stack
    locvar IFS
    IFS=" "
    eval "_l_var=\${_l$_l}"
    for _l_var in $_l_var; do
      eval "$_l_var=\${_l${_l}_$_l_var}"
      if eval "[ -z \"\${$_l_var}\" ]"; then
	unset "$_l_var"
      else
	eval "$_l_var=\${$_l_var#+}"
      fi
      unset "_l${_l}_$_l_var"
    done
    unset "_l$_l"
    _l=$(($_l - 1))
    return "$_l_ret"
  } 2> /dev/null
}

locopt() {
  for _l_opt do
    case $_l_option_restore in
      (*"${_l_opt#?}"*) ;;
      (*)
        case $- in
          (*"${_l_opt#?}"*)
            _l_option_restore="$_l_option_restore -${_l_opt#?}";;
          (*)
            _l_option_restore="$_l_option_restore +${_l_opt#?}";;
        esac;;
    esac
    set "$_l_opt"
  done
} 2> /dev/null

trace_fn() {
  eval "_lx_$1=1"
} 2> /dev/null

untrace_fn() {
  unset "_lx_$1"
} 2> /dev/null

# Example:

var=foo
sub f; _f() {
  locvar var
  var=$1
  echo "$var"
}

trace_fn f

f test
echo "$var"
