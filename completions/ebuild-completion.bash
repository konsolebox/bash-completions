# ebuild-completion.bash
#
# Copyright (c) 2023 konsolebox
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the “Software”), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

if [[ BASH_VERSINFO -ge 5 ]]; then
	_EBUILD_COMP_ALL_OPTS="--color --debug --force -h --help --ignore-default-opts --noauto --skip-manifest --version"
	_EBUILD_COMP_OPTS_WITH_ARG_EXPR="--color"
	_EBUILD_COMP_SUBCOMMANDS=(
		clean compile config configure digest fetch help install instprep manifest merge package
		postinst postrm preinst prepare prerm qmerge rpm setup test unmerge unpack
	)
	_EBUILD_COMP_SUBCOMMAND_PATTERN='+([[:lower:]])'

	if false; then
		function _ebuild_comp_log_debug {
			logger -t ebuild-completion -p debug -- "${FUNCNAME[1]-}${FUNCNAME[1]+: }$1"
		}
	fi

	function _ebuild_comp_filter_filenames {
		local f filenames
		readarray -t filenames

		for f in "${filenames[@]}"; do
			[[ -d $f || -f $f && $f == *.ebuild ]] && printf '%s\n' "$f"
		done
	}

	function _ebuild_comp_get_dirname {
		dirname=${1%%+([^/])*(/)} dirname=${dirname%%+(/)}

		if [[ -z ${dirname} ]]; then
			[[ $1 == /* ]] && dirname=/ || dirname=.
		fi
	}

	function _ebuild_comp_generate_filename_replies {
		local dirname ebuilds=() i temp
		readarray -t COMPREPLY < <(compgen -f -- "$1" | _ebuild_comp_filter_filenames)

		while [[ ${#COMPREPLY[@]} -eq 1 && -d ${COMPREPLY} && -x ${COMPREPLY} ]]; do
			readarray -t temp < <(cd "${COMPREPLY}" &>/dev/null && compgen -f | \
					_ebuild_comp_filter_filenames)
			[[ ${#temp[@]} -eq 0 ]] && break
			COMPREPLY=("${temp[@]/#/"${COMPREPLY%/}/"}")
		done

		for i in "${!COMPREPLY[@]}"; do
			if [[ -d ${COMPREPLY[i]} ]]; then
				COMPREPLY[i]=${COMPREPLY[i]%%+(/)}/
			elif [[ -f ${COMPREPLY[i]} && ${COMPREPLY} == *.ebuild ]]; then
				ebuilds+=("${COMPREPLY[i]}")
			fi
		done

		if [[ ${#ebuilds[@]} -gt 0 ]]; then
			_ebuild_comp_get_dirname "${ebuilds}"
			[[ -e ${dirname}/../../profiles/repo_name ]] && COMPREPLY=("${ebuilds[@]}")
		fi

		[[ ${#COMPREPLY[@]} -eq 1 && -f ${COMPREPLY} && ${COMPREPLY} == *.ebuild ]]
	}

	function _ebuild_comp_try_get_opt_with_arg {
		local -n __opt=$1 __arg=$2 __prefix=$3
		local __i

		for (( __i = 1; __i <= COMP_CWORD; ++__i )); do
			set -- "${COMP_WORDS[@]:__i:2}"

			if [[ __i -eq COMP_CWORD && $1 == --* &&
					$1 == @(${_EBUILD_COMP_OPTS_WITH_ARG_EXPR})=* ]]; then
				__arg=${1#*=} __prefix=${1:0:(${#1} - ${#__arg})} __opt=${__prefix%=}
				return 0
			elif [[ __i -eq COMP_CWORD && ${#1} -gt 2 && $1 == -[!-]* &&
					$1 == @(${_EBUILD_COMP_OPTS_WITH_ARG_EXPR})* ]]; then
				__arg=${1#*=} __prefix=${1:0:(${#1} - ${#__arg})} __opt=$__prefix
				return 0
			elif [[ $1 == @(${_EBUILD_COMP_OPTS_WITH_ARG_EXPR}) ]]; then
				if (( __i == COMP_CWORD - 1 )); then
					__opt=$1 __arg=$2 __prefix=
					return 0
				fi

				(( ++__i ))
			fi
		done

		return 1
	}

	function _ebuild_comp_get_specified_subcommands {
		local i
		specified_subcommands=

		for (( i = 2; i < ${#COMP_WORDS[@]}; ++i )); do
			if [[ ${COMP_WORDS[i]} == @(${_EBUILD_COMP_OPTS_WITH_ARG_EXPR}) ]]; then
				(( ++i ))
			elif [[ ${COMP_WORDS[i]} == ${_EBUILD_COMP_SUBCOMMAND_PATTERN} &&
					i -ne COMP_CWORD ]]; then
				specified_subcommands+=" ${COMP_WORDS[i]}"
			fi
		done

		specified_subcommands=${specified_subcommands# }
	}

	function _ebuild_comp_generate_unspecified_subcommand_replies {
		local prefix=$1 specified_subcommands unspecified_subcommands= __
		_ebuild_comp_get_specified_subcommands

		for __ in "${_EBUILD_COMP_SUBCOMMANDS[@]}"; do
			[[ " ${specified_subcommands} " != *" $__ "* ]] && unspecified_subcommands+=" $__"
		done

		readarray -t COMPREPLY < <(compgen -W "${unspecified_subcommands# }" -- "${prefix}")
		[[ ${#COMPREPLY[@]} -gt 0 ]]
	}

	function _ebuild_comp_current_word_open_quoted {
		local i

		for (( i = COMP_POINT - 1; i > 0; --i )); do
			[[ ${COMP_LINE:i:1} == [\"\'] ]] && return 0
			[[ ${COMP_LINE:i:1} == [${COMP_WORDBREAKS}] ]] && break
		done

		return 1
	}

	function _ebuild_comp {
		local arg dont_add_space=false i IFS=$' \t\n' opt prefix
		COMPREPLY=()

		if [[ COMP_CWORD -le 1 ]]; then
			_ebuild_comp_generate_filename_replies "$2" || dont_add_space=true
		elif _ebuild_comp_try_get_opt_with_arg opt arg prefix; then
			case ${opt} in
			--color)
				readarray -t COMPREPLY < <(compgen -W "y n" "${arg}")
				[[ ${#COMPREPLY[@]} -eq 1 ]] || dont_add_space=true
				;;
			esac

			if [[ ${prefix} ]]; then
				for i in "${!COMPREPLY[@]}"; do
					COMPREPLY[i]=${prefix}${COMPREPLY[i]}
				done
			fi
		elif [[ $2 == -* ]]; then
			readarray -t COMPREPLY < <(compgen -W "${_EBUILD_COMP_ALL_OPTS}" -- "$2")
		else
			_ebuild_comp_generate_unspecified_subcommand_replies "$2" || return
		fi

		if ! _ebuild_comp_current_word_open_quoted; then
			for i in "${!COMPREPLY[@]}"; do
				printf -v "COMPREPLY[$i]" %q "${COMPREPLY[i]}"
			done
		fi

		[[ ${dont_add_space} == true ]] && compopt -o nospace
	}

	# Removing '=' is also necessary since the equal sign still becomes
	# stored as a separate argument in COMP_WORDS.  Besides that, the equal
	# sign can also be a part of the filename and even though COMP_WORDS can
	# be recomposed using `compgen -W`, telling bash how the token should be
	# completed itself would require an ugly workaround since the token is
	# already split.  Perhaps the replies can be trimmed out so they don't
	# include the partial strings which aren't originally part of the token
	# being completed, but they would look terrible when displayed.  So
	# generally the added hack isn't worth it.
	#
	COMP_WORDBREAKS=${COMP_WORDBREAKS//=}

	complete -F _ebuild_comp ebuild
fi
